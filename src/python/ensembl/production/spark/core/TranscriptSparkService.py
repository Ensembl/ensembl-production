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

#Class performs functionality on the transcript level such as: 
# 
# - sequence build 
# - translatable exons of the transcript 
# - seq edits
# Most functions takes database details as input and produces dataframe on the output
# All function is performed withing a spark session passed to the class construtor (init)
# To boost the performance after data is read from database it is droped to the disk with 
# file system functions and after it dataframe is loaded from disk that allows to use
# parralel calculations and split to chuncks and in case of big data also use disk space
class TranscriptSparkService:

    __type = 'transcript_spark_service'

    def __init__(self,
                 session: SparkSession = None,
                 ) -> None:
        if not session:
            raise ValueError(
                'Session is required')
        self._spark = session
        self._spark.sparkContext.setLogLevel("ERROR")
    """
    Returns: seq_edits DF, loaded directly from database
    Input: is database details and edit_codes that is a codes in attrib_type table - what attributes we consider as edits
    Database URL example: jdbc:mysql://localhost:3306/ensembl_core_human_110
    For the optimization not used directly but wrapped in _load_seq_edits_fs - dumped to disk
    """
    def _load_seq_edits(self, db: str, user: str, password: str, edit_codes,
                       translation=False):
        edits_str = "(\'" + str(reduce(lambda x,y: x + "\', \'" + y, edit_codes)) + "\')"
        #Hardcoded name of the fature is inside seq_edit function and not transfered as a string, to isolate db specific hardcode 
        # withing function that work with database
        feature = "transcript"
        if (translation):
            feature = "translation"
        
        #Query to fetch transcript or translation attributes that has codes considered as edits
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
    def _load_seq_edits_fs(self, db: str, user: str, password: str, edit_codes,
                         translation="False",  tmp_folder=None):
        seq_edits = self._load_seq_edits(db, user, password, edit_codes\
                                       , translation)
        file_service = FileSystemSparkService(self._spark)
        return file_service.write_df_to_orc(seq_edits, "seq_edits", tmp_folder)


    """
    Returns: transcripts DF, loaded directly from database
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
    sequence must be  in dataFrame
    Returns: dataFrame with edits applied to the sequence
    Input: dataFrame, edits dataframe and feature type
    """
    def apply_edits(self, sequence_df, edits_df, translation=False):
        #Database specific hardcode isolated withing function
        feature = "transcript"
        if (translation):
            feature = "translation"

        #Function applies single sequence edit list to the sequence
        @udf(returnType=StringType())
        def sequence_edits(sequence, edits_list):
            if(edits_list == None):
                return sequence
            for edit in edits_list:
                edit = edit.split(" ")
                start = int(edit[0])-1
                end = int(edit[1])
                if (sequence[0:1] == "!"):
                    start = start + 1
                    end = end + 1              
                sequence = sequence[:start] + edit[2] +\
                sequence[end:]
            return sequence
        
        edits_df =\
        edits_df.groupby(feature +"_id").agg(concat(collect_list("value")).alias("c_value"))
        
        sequence_df = sequence_df.join(edits_df, on=[feature + "_id"], how="leftouter")
        
        sequence_df = sequence_df.withColumn("sequence",\
                                             sequence_edits("sequence","c_value")).drop("c_value")
        return sequence_df
    
    """
    Returns transcripts with spliced sequnce
    Splice sequence is transcript sequence which translatable part (CDS) is CAPITAL letters and 
    UTR (Untranslated regions) is regular font. It was historically used in perl API
    """
    def spliced_seq(self, db: str, user: str, password: str,
                    exons_df=None):
        #Every sequnce is capitalized from translation start to end
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
        return transcripts_with_seq

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
                                   phase, end_phase):
            
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
                                                                     "end_phase"))

         return transcripts_with_seq

    def translated_seq(self, db: str, user: str, password: str, exons_df=None, keep_seq=False):
         translated_seq = self.translatable_seq(db, user, password, exons_df, keep_seq)
         @udf(returnType=StringType())
         def translate_sequence(raw_sequence, codon_table, phase):
             
             if ((raw_sequence is None) or (len(raw_sequence) == 0)):
                 return
             seq = Seq(raw_sequence)
             try:
                sequence = seq.translate(table = int(codon_table), cds = True)
                sequence = "!" + sequence + "*"
             except Exception as e:     
                sequence = seq.translate(table = int(codon_table))
                error = str(e)
                if(error.find("start codon") == -1):
                    sequence = "!" + sequence
                if((len(raw_sequence)%3 != 0) and (error.find("start codon") != -1) and (len(raw_sequence)%3 == phase)):
                    stop_codon = Seq(raw_sequence[-3:])
                    stop_codon = stop_codon.translate()
                    if(stop_codon == "*"):
                        sequence = str(sequence)
                        sequence = sequence[:-1] + "*"
                        return sequence
             sequence = str(sequence)

             return sequence

         #We need to have in DF genomic coordinates of the translation
         translatable_exons = self.translatable_exons(db, user, password,
                         exons_df, None, False, True)

         translated_sequence = \
         translated_seq.withColumn("sequence",
                                     translate_sequence("sequence", "codon_table", "phase")).drop("seq_region_end", "seq_region_start")
         #Join by exon_id
         translated_sequence = translated_sequence.join(translatable_exons.select("transcript_stable_id", "tl_start", "tl_end", "tl_version").dropDuplicates(), on = ["transcript_stable_id"])
                      
         #Apply translation edits - selenocyst is translation
         edit_codes = ['initial_met', '_selenocysteine', 'amino_acid_sub',
                      '_stop_codon_rt']
         seq_edits = self._load_seq_edits_fs(db, user, password, edit_codes,
                                            True)
         translated_sequence = self.apply_edits(translated_sequence,
                                                seq_edits, True)
         
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
                                                   password).repartition(10)
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

        translation_df = translation_service.load_translations_fs(db, user, password, tmp_folder)
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
                                                   "seq_region_end", "exon_id"))

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
        #Translation start and end relative to seq start
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
        seq_edits = self._load_seq_edits_fs(db, user, password, edit_codes, tmp_folder)
        transcripts_with_seq = self.apply_edits(transcripts_with_seq, seq_edits)
        file_service = FileSystemSparkService(self._spark)
        return file_service.write_df_to_orc(transcripts_with_seq,
                                            "transcripts_with_seq", tmp_folder)
        
        
    """
    Returns all translatable exons of the database
    """
    def translatable_exons(self, db: str, user: str, password: str,
                         exons_df=None, tmp_folder=None, utr=True, edge_only = False):

        @udf(returnType=IntegerType())
        def translatable(start, end, tl_start, tl_end):
            if (tl_start < tl_end):
                if(start >= tl_start and start <= tl_end or end >= tl_start and end <= tl_end or tl_start > start and tl_end < end):
                    return 0
                if(end < tl_start):
                    return(-1)
            if (tl_start > tl_end):
                if(start <= tl_start and start >= tl_end or end <= tl_start and end >= tl_end or tl_start > start and tl_end < end):
                    return 0
                if(start > tl_start):
                    return -1
            return 1

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
        
        @udf(returnType=StringType())
        def utr_type(strand, end):
            if (strand > 0 and end == "end" or strand < 0 and end == "start"):
                return "three_prime_UTR"
            return "five_prime_UTR"

        #Phase of the exon shotuld be . of it is -1
        @udf(returnType=StringType())
        def map_phase(phase):
            if(phase > 2):
                return "0"
            return str(phase)
            
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
        transcripts_df= transcripts_df.select("transcript_id", "canonical_translation_id", "stable_id", "source")\
            .withColumnRenamed("canonical_translation_id", "translation_id")\
            .withColumnRenamed("stable_id", "transcript_stable_id")\
                
        transcripts_df = transcripts_df.join(translations_df.drop("transcript_id", "created_date", "modified_date").withColumnRenamed("version", "tl_version"), on=["translation_id"], how="right")
        
        #Find translation seq start and end
        transcripts_df = transcripts_df.join(exons_df.select("seq_region_start", "seq_region_end", "exon_id", "seq_region_strand"), on=[transcripts_df.start_exon_id==exons_df.exon_id], how = "left").dropDuplicates()
        transcripts_df = transcripts_df.withColumn("tl_start", tl_start("seq_region_start", "seq_region_end", "seq_start", "seq_end", "seq_region_strand")).drop("seq_region_start", "seq_region_end", "exon_id", "seq_region_strand")
        
        transcripts_df = transcripts_df.join(exons_df.select("seq_region_start", "seq_region_end", "exon_id", "seq_region_strand"), on=[transcripts_df.end_exon_id==exons_df.exon_id], how = "left").dropDuplicates()
        transcripts_df = transcripts_df.withColumn("tl_end", tl_end("seq_region_start", "seq_region_end",  "seq_start", "seq_end", "seq_region_strand")).drop("seq_region_start", "seq_region_end", "exon_id", "seq_end", "seq_start", "seq_region_strand")
        
        #Determine translatabe exons
        exons_df = exons_df.join(transcripts_df, on=["transcript_id"])
        translatables = exons_df.withColumn("translatable", translatable("seq_region_start", "seq_region_end", "tl_start", "tl_end"))

        result=translatables.filter("translatable = 0")

        #Crop exons to CDS
        result = result.withColumn("seq_region_start", crop_tl_start("seq_region_start", "tl_start", "tl_end", "exon_id", "start_exon_id", "end_exon_id")).drop("translatable")
        result = result.withColumn("seq_region_end", crop_tl_end("seq_region_end", "tl_start", "tl_end", "exon_id", "start_exon_id", "end_exon_id"))

        #For some tasks we need only start and end exons        
        if (edge_only):
            return result.filter("(exon_id == start_exon_id) or (exon_id == end_exon_id)")
        
        result = result.withColumn("phase", map_phase(3 - result.phase))
        
        result = result.withColumn("type", lit("CDS")).select("exon_id", "type",
                                       "seq_region_start", "seq_region_end",
                                          "seq_region_strand", "phase","seq_region_id", "exon_stable_id", "transcript_stable_id", "version",  "stable_id", "tl_version", "rank", "source")
        #If case we need croped part of transcript
        if (utr):
            exons_df = exons_df.withColumnRenamed("seq_region_start", "orig_start").withColumnRenamed("seq_region_end", "orig_end").withColumnRenamed("exon_id", "orig_exon_id")
            exons_df = exons_df.select("orig_exon_id", "orig_start", "orig_end")
            
            result_prime_utr = result.join(exons_df, on=[result.exon_id == exons_df.orig_exon_id], how = "left")
            result_three_prime_utr = result_prime_utr.filter("seq_region_start != orig_start")\
                    .drop("seq_region_end").withColumnRenamed("seq_region_start", "seq_region_end").drop("seq_region_start").withColumnRenamed("orig_start", "seq_region_start")\
                    .withColumn("type", utr_type("seq_region_strand", lit("start")))
            result_five_prime_utr = result_prime_utr.filter("seq_region_end != orig_end")\
                    .drop("seq_region_start").withColumnRenamed("seq_region_end", "seq_region_start").withColumnRenamed("orig_end", "seq_region_end")\
                    .withColumn("type", utr_type("seq_region_strand", lit("end")))

            result_five_prime_utr = result_five_prime_utr.select\
                ("exon_id", "type", "seq_region_start", "seq_region_end",
                                         "seq_region_strand", "phase", "seq_region_id", "exon_stable_id", "transcript_stable_id", "version", "stable_id", "tl_version", "rank", "source")
            result_three_prime_utr = result_three_prime_utr.select\
                ("exon_id", "type", "seq_region_start", "seq_region_end",
                                         "seq_region_strand", "phase", "seq_region_id", "exon_stable_id", "transcript_stable_id", "version", "stable_id", "tl_version", "rank", "source")
            result_three_prime_utr = result_three_prime_utr.withColumn("seq_region_end", result_three_prime_utr.seq_region_end - 1)
            result_five_prime_utr = result_five_prime_utr.withColumn("seq_region_start", result_five_prime_utr.seq_region_start + 1)
            
            five_prime_utr=translatables.filter("translatable<0").withColumn("type", lit("five_prime_UTR")).select\
                ("exon_id", "type", "seq_region_start", "seq_region_end",
                                         "seq_region_strand", "phase", "seq_region_id", "exon_stable_id", "transcript_stable_id", "version", "stable_id", "tl_version", "rank", "source")   
            three_prime_utr=translatables.filter("translatable>0").withColumn("type", lit("three_prime_UTR")).select\
                ("exon_id", "type", "seq_region_start", "seq_region_end",
                                         "seq_region_strand", "phase", "seq_region_id", "exon_stable_id", "transcript_stable_id", "version", "stable_id", "tl_version", "rank", "source")
            
            result_five_prime_utr = result_five_prime_utr.union(result_three_prime_utr).union(five_prime_utr).union(three_prime_utr).dropDuplicates().withColumn("phase",lit("."))

            return result.union(result_five_prime_utr)
        
        return result
        
        
