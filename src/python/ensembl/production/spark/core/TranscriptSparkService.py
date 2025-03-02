# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import os
import shutil
from pyspark.sql import SparkSession
from pyspark.sql.functions import regexp_replace, expr, concat, concat_ws, collect_list
from pyspark.sql.types import *
from Bio.Seq import Seq
from pyspark.sql.functions import udf, lit
from ensembl.production.spark.core.FileSystemSparkService import FileSystemSparkService
from ensembl.production.spark.core.ExonSparkService import ExonSparkService
from ensembl.production.spark.core.TranslationSparkService import TranslationSparkService
from functools import reduce
from pyspark.sql.types import IntegerType

__all__ = ['TranscriptSparkService']

class TranscriptSparkService:

    __type = 'transcript_spark_service'

    def __init__(self,
                 session: SparkSession = None,
                 ) -> None:
        if not session:
            raise ValueError(
                'Connection details and session is required')
        self._spark = session
        self._spark.sparkContext.setLogLevel("ERROR")
    """
    Returns seq_edits DF, loaded directly from database
    Database URL example: jdbc:mysql://localhost:3306/ensembl_core_human_110
    """
    def load_seq_edits(self, db: str, user: str, password: str, edit_codes,
                       translation=False):
        edits_str = "(\'" + str(reduce(lambda x,y: x + "\', \'" + y, edit_codes)) + "\')"
        feature = "transcript"
        if (translation):
            feature = "translation"
        seq_edits = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "(select "+ feature + "_attrib.* from " + feature + "_attrib join\
                    attrib_type on attrib_type.attrib_type_id =\
                    " + feature + "_attrib.attrib_type_id where attrib_type.code in " +
                    edits_str + ")tmp")\
            .option("user", user)\
            .option("password", password)\
            .load()

        return seq_edits

    """
    Load seq_edits with fs dump, performance boost
    """
    def load_seq_edits_fs(self, db: str, user: str, password: str, edit_codes,
                         translation=False,  tmp_folder=None):
        seq_edits = self.load_seq_edits(db, user, password, edit_codes\
                                       , translation)
        file_service = FileSystemSparkService(self._spark)
        return file_service.write_df_to_orc(seq_edits, "seq_edits", tmp_folder)


    """
    Returns transcripts DF, loaded directly from database
    Database URL example: jdbc:mysql://localhost:3306/ensembl_core_human_110
    """
    def load_transcripts(self, db: str, user: str, password: str):
        transcripts = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "transcript")\
            .option("user", user)\
            .option("password", password)\
            .load()

        return transcripts

    """
    Load transcripts with fs dump, performance boost
    """
    def load_transcripts_fs(self, db: str, user: str, password: str, tmp_folder: str):
        transcripts = self.load_transcripts(db, user, password)
        file_service = FileSystemSparkService(self._spark)
        return file_service.write_df_to_orc(transcripts, "transcripts", tmp_folder)


    """
    Apply edits to the list of transcripts or translations
    sequnce row must be in data frame
    """
    def apply_edits(self, sequence_df, edits_df, feature="transcript"):
        @udf(returnType=StringType())
        def sequence_edits(sequence, edits_list):
            if(edits_list == None):
                return sequence
            for edit in edits_list:
                edit = edit.split(" ")
                sequence = sequence[:int(edit[0])-1] + edit[2] +\
                sequence[int(edit[1]):]
            return sequence
        edits_df =\
        edits_df.groupby(feature +"_id").agg(concat(collect_list("value")).alias("c_value"))
        sequence_df = sequence_df.join(edits_df, on=[feature + "_id"], how="leftouter")
        sequence_df = sequence_df.withColumn("sequence",\
                                             sequence_edits("sequence","c_value")).drop("c_value")
        return sequence_df
    """
    Returns transcripts with spliced sequnce
    """
    def spliced_seq(self, db: str, user: str, password: str,
                    exons_df=None):
        @udf(returnType=StringType())
        def spliced_sequence(sequence, translation_region_start,
                             translation_region_end):
            translation_region_end = int(translation_region_end)
            translation_region_start = int(translation_region_start)
            if (translation_region_end < translation_region_start):
                sequence =\
                sequence[:translation_region_end-1].lower() + \
                    sequence[(translation_region_end-1):\
                                      (translation_region_start+1)] +\
                    sequence[(translation_region_start+1):].lower()

            else:
                sequence = sequence[:(translation_region_start-1)].lower() + \
                    sequence[(translation_region_start-1):\
                                      (translation_region_end+1)] +\
                    sequence[(translation_region_end+1):].lower()
            return sequence

        transcripts_with_seq = self.transcripts_translation_sequence(db, user,
                                                                     password,
                                                                    exons_df)
        transcripts_with_seq =\
                transcripts_with_seq.withColumn("sequence",
                                                spliced_sequence("sequence",\
                                                                 "translation_region_start",\
                                                                 "translation_region_end"))
        return transcripts_with_seq;

    """
    Returns transcripts with translatable sequence
    """
    def translatable_seq(self, db: str, user: str, password: str,
                         exons_df=None, keep_seq=False):
         transcripts_with_seq = self.transcripts_translation_sequence(db, user,
                                                                     password,
                                                                    exons_df)

         @udf(returnType=StringType())
         def translatable_sequence(sequence, translation_region_start,\
                                            translation_region_end,\
                                   phase, end_phase, translation_id):
            
            if (len(translation_region_start) < 1 or len(translation_region_end) < 1):
                return ""
            translation_region_end = int(translation_region_end)
            translation_region_start = int(translation_region_start)
           # if((phase > 0) or (end_phase > 0)):
           #     print("WARNING: phase is not null: " +
           #           translation_id)
            if (translation_region_end < translation_region_start):
                sequence = "N"*end_phase + sequence[(translation_region_end - 1):\
                                      (translation_region_start + 1)]
            else:
                sequence = "N"*phase + sequence[(translation_region_start - 1):\
                                      (translation_region_end + 1)]
            return sequence
                                   #Consider reverse strand
         
         if (keep_seq):
             transcripts_with_seq = transcripts_with_seq.withColumn("transcript_seq", transcripts_with_seq.sequence)
         transcripts_with_seq =\
                transcripts_with_seq.withColumn("sequence",
                                                translatable_sequence("sequence",
                                                                   "translation_region_start",
                                                                   "translation_region_end",
                                                                     "phase",
                                                                     "end_phase",
                                                                     "translation_stable_id"))

         return transcripts_with_seq

    def translated_seq(self, db: str, user: str, password: str, exons_df=None, keep_seq=False):
         translated_seq = self.translatable_seq(db, user, password, exons_df, keep_seq)
         
         @udf(returnType=StringType())
         def translate_sequence(sequence, codon_table, cds_start_nf, id):
             if ((sequence is None) or (len(sequence) == 0)):
                 return
             seq = Seq(sequence)
             sequence = seq.translate(table = int(codon_table))
             sequence = str(sequence)
             if sequence[-1:] == "*":
                 sequence = sequence[:-1]
             if sequence[:1] != 'M' and not cds_start_nf:
                # if(str(seq)[:1] == "N"):
                #     print("WARNING appending M to non-zero phase: " + id)
                 sequence = "M" + sequence[1:]
             return sequence
         cds_start_nf_df = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "(select ta.* from transcript_attrib ta left join attrib_type at \
            on at.attrib_type_id = ta.attrib_type_id where at.code=\"cds_start_NF\")tmp")\
            .option("user", user)\
            .option("password", password)\
            .load().dropDuplicates()
         translated_sequence = \
         translated_seq.join(cds_start_nf_df, "transcript_id", how="leftouter").withColumn("sequence",
                                     translate_sequence("sequence", "codon_table", "value", "translation_stable_id"))
         #Apply translation edits
         edit_codes = ['initial_met', '_selenocysteine', 'amino_acid_sub',
                      '_stop_codon_rt']
         seq_edits = self.load_seq_edits_fs(db, user, password, edit_codes,
                                            True)
         translated_sequence = self.apply_edits(translated_sequence,
                                                seq_edits, "translation")

         return translated_sequence


    """
    Returns transcript with translation and  whole sequence
    """
    def transcripts_translation_sequence(self, db: str, user: str, password: str,
                         exons_df=None, tmp_folder=None):
        transcripts = self.load_transcripts_fs(db, user,
                                                password, tmp_folder)
        translation_service = TranslationSparkService(self._spark)
        if (exons_df == None):
            exon_service = ExonSparkService(self._spark)
            exons_df = exon_service.exons_with_seq(db,  user,\
                                                   password).repartition(10);
            if (exons_df == None):
                return
        #For each exon calculate length, concat with id for further translation
        #start calc
        @udf(returnType=StringType())
        def calc_length(start, end, id):
            return  str(abs(int(end) - int(start) + 1)) + ":" + str(id)

        @udf(returnType=StringType())
        def get_translation_start(length, start, start_id):
            result = 0
            for exon in length.split(" "):
                exon = exon.split(":")
                if(int(start_id) == int(exon[1])):
                    result = result + start
                    return result
                result = result + int(exon[0])
            return result

        @udf(returnType=StringType())
        def get_translation_end(length, end, end_id):
            result = 0
            for exon in length.split(" "):
                exon = exon.split(":")
                if(int(end_id) == int(exon[1])):
                    result = result + end - 1
                    return result
                result = result + int(exon[0])
            return result

        translation_df = translation_service.load_translations_fs(db, user, password)
        result = None
        regions = self._spark.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", db)\
            .option("dbtable", "(select distinct t.seq_region_id, sr.name, sra.value from transcript t left join seq_region sr on t.seq_region_id= sr.seq_region_id left join seq_region_attrib sra on sra.seq_region_id = t.seq_region_id \
                    and sra.attrib_type_id = 11)tmp")\
            .option("user", user)\
            .option("password", password)\
            .load().dropDuplicates()
        regions_plain = regions.collect()
        for region in regions_plain:
            codon_table = 1
            if region.value:
                codon_table = int(region.value)
            region = str(region.seq_region_id)
            exons_df_tmp = exons_df.filter("seq_region_id=" + region)
            count = exons_df_tmp.count()
            if(count == 0):
                continue
            exons_df_tmp = exons_df_tmp.sort("transcript_id", "rank", ascending=[True, True])
            exons_df_tmp = exons_df_tmp.withColumn("length",\
                                       calc_length("seq_region_start",\
                                                   "seq_region_end", "exon_id"))\

            #print(region + " " + str(count))
            #Mark translation start and end

            transcripts_with_seq =\
            exons_df_tmp.groupBy("transcript_id")\
            .agg(concat_ws(" ",expr("""transform(sort_array(collect_list(struct(rank,sequence)),True), x -> x.sequence)"""))\
                    .alias("sequence"), \
                    concat_ws(" ", expr("""transform(sort_array(collect_list(struct(rank,length)),True), x -> x.length)"""))\
                    .alias("length"))\
                    .drop("version", "created_date", "modified_date", "stable_id")\
                    .join(translation_df.withColumn("translation_stable_id", translation_df.stable_id), on=["transcript_id"])\
                    .drop("version", "seq_region_strand", "created_date", "modified_date", "stable_id")\
                    .join(transcripts.withColumnRenamed("biotype", "transcript_biotype")\
                        .withColumnRenamed("desription", "transcript_desription")\
                        .withColumnRenamed("stable_id", "transcript_stable_id"), on=["transcript_id"])\
                    .join(regions.select("seq_region_id", "name").withColumnRenamed("name", "seq_region_name"), on=["seq_region_id"])
                    
            transcripts_with_seq =\
            transcripts_with_seq.withColumn("sequence", regexp_replace("sequence", " ", ""))\
                .withColumn("codon_table", lit(codon_table))

            transcripts_with_seq =\
            transcripts_with_seq.join(exons_df_tmp.select("exon_id", "phase"),
                                      on=[transcripts_with_seq.start_exon_id==exons_df.exon_id]).dropDuplicates()
            transcripts_with_seq =\
            transcripts_with_seq.drop("exon_id").join(exons_df_tmp.select("exon_id", "end_phase"),
                                      on=[transcripts_with_seq.end_exon_id==exons_df.exon_id]).dropDuplicates()

            if (result == None):
                result = transcripts_with_seq
            else:
                result = result.union(transcripts_with_seq)
        transcripts_with_seq =\
        result.withColumn("translation_region_start",
                                        get_translation_start("length",
                                                              "seq_start",
                                                              "start_exon_id"))\
                            .withColumn("translation_region_end",
                                        get_translation_end("length",
                                                            "seq_end",
                                                            "end_exon_id"))
        #Apply transcript edits

        edit_codes = ['_rna_edit']
        seq_edits = self.load_seq_edits_fs(db, user, password, edit_codes, tmp_folder)
        transcripts_with_seq = self.apply_edits(transcripts_with_seq, seq_edits)
        file_service = FileSystemSparkService(self._spark)
        return file_service.write_df_to_orc(transcripts_with_seq,
                                            "transcripts_with_seq", tmp_folder)
        
        
    """
    Returns all translatable exons of the database
    """
    def translatable_exons(self, db: str, user: str, password: str,
                         exons_df=None, tmp_folder=None):

        @udf(returnType=IntegerType())
        def translatable(start, end, tl_start, tl_end):
            result = 0
            if (tl_start < tl_end):
                if(start >= tl_start and start <= tl_end or end >= tl_start and end <= tl_end):
                    result = 1
            if (tl_start > tl_end):
                if(start <= tl_start and start >= tl_end or end <= tl_start and end >= tl_end):
                    result = 1
                    
            return  result

        @udf(returnType=IntegerType())
        def tl_start(start, end, tl_start, tl_end,  strand):
            if (strand > 0):
                return start + tl_start - 1
            else:
                return end - tl_start + 1
        
        @udf(returnType=IntegerType())
        def tl_end(start, end, tl_start, tl_end, strand):
            if (strand > 0):
                return start + tl_end - 1
            else: 
                return end - tl_end + 1

        
        @udf(returnType=IntegerType())
        def crop_tl_start(exon_start, tl_start, tl_end, exon_id, tl_start_exon_id, tl_end_exon_id):
            if (exon_id == tl_end_exon_id):
                if(tl_start > tl_end):
                    return tl_end
            if (exon_id == tl_start_exon_id):
                if(tl_start < tl_end):
                    return tl_start
            return exon_start
        
        @udf(returnType=IntegerType())
        def crop_tl_end(exon_end, tl_start, tl_end, exon_id, tl_start_exon_id, tl_end_exon_id):
            if (exon_id == tl_end_exon_id):
                if(tl_start < tl_end):
                    return tl_end
            if (exon_id == tl_start_exon_id):
                if(tl_start > tl_end):
                    return tl_start
            return exon_end

        
            
        translation_service = TranslationSparkService(self._spark)
        if (exons_df == None):
            exon_service = ExonSparkService(self._spark)
            exons_df = exon_service.load_exons_fs(db, user, password, tmp_folder);
            if (exons_df == None):
                return
        transcripts_df = self.load_transcripts_fs(db, user, password, tmp_folder) 
        exons_df=exons_df.withColumnRenamed("stable_id", "exon_stable_id") 
        #Find all canonical translations    
        translations_df = translation_service.load_translations_fs(db, user, password, tmp_folder)
        transcripts_df= transcripts_df.select("transcript_id", "canonical_translation_id", "stable_id")\
            .withColumnRenamed("canonical_translation_id", "translation_id")\
            .withColumnRenamed("stable_id", "transcript_stable_id")\
                
        transcripts_df = transcripts_df.join(translations_df.drop("transcript_id", "version", "created_date", "modified_date"), on=["translation_id"], how="right")
        
        #Find translation seq start and end

        transcripts_df = transcripts_df.join(exons_df.select("seq_region_start", "seq_region_end", "exon_id", "seq_region_strand"), on=[transcripts_df.start_exon_id==exons_df.exon_id], how = "left").dropDuplicates()
        transcripts_df = transcripts_df.withColumn("tl_start", tl_start("seq_region_start", "seq_region_end", "seq_start", "seq_end", "seq_region_strand")).drop("seq_region_start", "seq_region_end", "exon_id", "seq_region_strand")
        
        transcripts_df = transcripts_df.join(exons_df.select("seq_region_start", "seq_region_end", "exon_id", "seq_region_strand"), on=[transcripts_df.end_exon_id==exons_df.exon_id], how = "left").dropDuplicates()
        transcripts_df = transcripts_df.withColumn("tl_end", tl_end("seq_region_start", "seq_region_end",  "seq_start", "seq_end", "seq_region_strand")).drop("seq_region_start", "seq_region_end", "exon_id", "seq_end", "seq_start", "seq_region_strand")
        
        transcripts_df.filter("stable_id=\"ENSABMP00000001148\"").show()
        result = exons_df.join(transcripts_df, on=["transcript_id"])
        result = result.withColumn("translatable", translatable("seq_region_start", "seq_region_end", "tl_start", "tl_end"))
        result=result.filter("translatable > 0")
        result = result.withColumn("seq_region_start", crop_tl_start("seq_region_start", "tl_start", "tl_end", "exon_id", "start_exon_id", "end_exon_id")).drop("translatable")
        result = result.withColumn("seq_region_end", crop_tl_end("seq_region_end", "tl_start", "tl_end", "exon_id", "start_exon_id", "end_exon_id"))
        return result
        
        
