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

__all__ = ['GFFService']
from pyspark.sql.types import StringType
from ensembl.production.spark.core.TranscriptSparkService import TranscriptSparkService
from pathlib import Path
import glob
import warnings
from pyspark.sql.functions import udf
from typing import Optional
import os
from pyspark.sql.functions import lit

class GFFService():

    feature_type = {
        'gene': 'gene',
        'pseudogene': 'gene',
        'miRNA_gene': 'gene',
        'ncRNA_gene': 'gene',
        'rRNA_gene': 'gene',
        'snoRNA_gene': 'gene',
        'snRNA_gene': 'gene',
        'tRNA_gene': 'gene',
        'transposable_element': 'gene',
        'mRNA': 'transcript',
        'transcript': 'transcript',
        'misc_RNA': 'transcript',
        'RNA': 'transcript',
        'pseudogenic_transcript': 'transcript',
        'pseudogenic_rRNA': 'transcript',
        'pseudogenic_tRNA': 'transcript',
        'ncRNA': 'transcript',
        'lincRNA': 'transcript',
        'miRNA': 'transcript',
        'pre_miRNA': 'transcript',
        'lncRNA': 'transcript',
        'lnc_RNA': 'transcript',
        'piRNA': 'transcript',
        'RNase_MRP_RNA': 'transcript',
        'RNAse_P_RNA': 'transcript',
        'rRNA': 'transcript',
        'snoRNA': 'transcript',
        'snRNA': 'transcript',
        'sRNA': 'transcript',
        'SRP_RNA': 'transcript',
        'tRNA': 'transcript',
        'scRNA': 'transcript',
        'guide_RNA': 'transcript',
        'tmRNA': 'transcript',
        'telomerase_RNA': 'transcript',
        'antisense_RNA': 'transcript',
        'transposable_element': 'transcript',
        'TR_V_gene': 'transcript',
        'TR_C_gene': 'transcript',
        'IG_V_gene': 'transcript',
        'IG_C_gene': 'transcript',
        'ribozyme': 'transcript',
        'exon': 'exon',
        'pseudogenic_exon': 'exon',
        'CDS': 'translation'
    }
    def __init__(self, spark_session) -> None:
            # Create SparkSession
            self._spark = spark_session

    def __repr__(self) -> str:
        return f'{self.__class__.__name__}(????)'

    def load_gff(self, file_path) -> None:
        # feature datastruct from gff
        region = ["name", "coord_system_id", "length"]

        exons = []
        genes = []
        transcripts = []
        regions = []
        translations = []
        f = open(file_path, "r")

        # read version
        file_line = f.readline()
        if (file_line.split(" ")[0] != "##gff-version"):
            print(file_line)
            warnings.warn(file_path + ": File is not gff3 format. Aborting")
            return []

        # read regions
        print("Looking for regions...")
        file_line = f.readline().split(" ")
        while file_line[0] == "##sequence-region":
            # parse region
            region_data = (file_line[3], 1, int(file_line[5]) -
                           int(file_line[4]))
            regions.append(region_data)
            file_line = f.readline().split(" ")

        while file_line[0][0] == "#":
            file_line = f.readline().split("\t")
        print("Looking for features...")
        gene = ["canonical_transcript_id", "analysis_id", "source", "biotype", "seq_region_name", "seq_region_start", "seq_region_end", "seq_region_strand", "stable_id", "version"]
        transcript = ["analysis_id", "source", "biotype", "seq_region_name",
                      "seq_region_start", "seq_region_end",
                      "seq_region_strand", "transcript_stable_id", "version",
                     "gene_stable_id"]
        exon = ["phase", "end_phase", "is_constitutive", "seq_region_name", "seq_region_start",
                "seq_region_end", "seq_region_strand", "exon_stable_id", "version",
               "transcript_stable_id", "rank"]
        translation = ["translation_stable_id", "transcript_stable_id",
                       "seq_start", "seq_end", "version", "start_exon_id",
                       "end_exon_id"]
        while file_line[0] != "###":
            #parse feature 
            source = "ensembl"
            analysis_id = 1
            attribs = self.parse_attribs(file_line[8])
            strand = 1
            if file_line[6] == "-":
                    strand = -1
            if self.feature_type[file_line[2]] == "gene":
                gene_data = (1, analysis_id, source, attribs["biotype"], file_line[0], file_line[3],
                             file_line[4], strand,
                             attribs["ID"], attribs["version"])
                genes.append(gene_data)

            if self.feature_type[file_line[2]] == "transcript":
                transcript_data = (analysis_id, source, attribs["biotype"],
                                   file_line[0], file_line[3],\
                                   file_line[4], strand, attribs["ID"], attribs["version"], attribs["Parent"])
                transcripts.append(transcript_data)

            if self.feature_type[file_line[2]] == "exon":
                exon_data = (attribs["ensembl_phase"],
                             attribs["ensembl_end_phase"],
                             attribs["constitutive"],
                                   file_line[0], file_line[3],\
                                   file_line[4], strand, attribs["exon_id"],
                             attribs["version"], attribs["Parent"],
                             attribs["rank"])
                exons.append(exon_data)

            if self.feature_type[file_line[2]] == "translation":
                translation_data = (attribs["ID"], attribs["Parent"],
                                    file_line[3], file_line[4], file_line[7],
                                   1, 1)
                translations.append(translation_data)
            file_line = f.readline().split()

        f.close()
        combined = {
            'region': [],
            'exon': [],
            'gene': [],
            'transcript': [],
            'translation': []
        };

        empty = True;
        #Create dataframes if any feature of a kind is found 
        if (len(exons) > 0):
            empty = False
            exonDf = self._spark.sparkContext.parallelize(exons).toDF(exon)
            combined["exon"] = exonDf

        if (len(translations) > 0):
            empty = False
            translationDf = self._spark.sparkContext.parallelize(translations).toDF(translation)
            combined["translation"] = translationDf

        if (len(genes) > 0):
            empty = False
            print("Genes found: " + str(len(genes)))
            geneDf = self._spark.sparkContext.parallelize(genes).toDF(gene)
            combined["gene"] = geneDf

        if (len(transcripts) > 0):
            empty = False
            print("Transcripts found: " + str(len(transcripts)))
            transcriptDf = self._spark.sparkContext.parallelize(transcripts).toDF(transcript)
            combined["transcript"] = transcriptDf

        if (len(exons) > 0):
            empty = False
            print("Exons found: " + str(len(exons)))
            exonDf = self._spark.sparkContext.parallelize(exons).toDF(exon)
            combined["exon"] = exonDf

        if (len(regions) > 0):
            print("Regions found: " + str(len(regions)))
            empty = False
            regionDf = self._spark.sparkContext.parallelize(regions).toDF(region)
            combined["region"] = regionDf

        if empty:
            warnings.warn("Nothing was found in file")

        return combined

    def parse_attribs(self, attribs) -> dict[str, str]:
         attribs_raw = attribs.split(";")
         attribs_map = {}
         for attrib_raw in attribs_raw:
             [key, value] = attrib_raw.split("=")
             if (value.find(":") != -1):
                 value = value.split(":")[1]
             attribs_map[key] = value
         return attribs_map

    def write_regions(self, regions_df):
        print("Writing regions to db")
        regions_df.write.mode("append")\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", self._db)\
                .option("dbtable","seq_region")\
                .option("user", self._user)\
                .option("password", self._password)\
                .save()

    def write_genes(self, genes_df):
        print("Writing genes to db")
        if (self._regions):
            genes_df = genes_df.join(self._regions.select("seq_region_id", "name"),
                                        on=[genes_df.seq_region_name ==
                          self._regions.name], how = 'left' )
        genes_df = genes_df.drop("seq_region_name").drop("name")
        genes_df.write.mode("append")\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", self._db)\
                .option("dbtable","gene")\
                .option("user", self._user)\
                .option("password", self._password)\
                .save()

    def write_exons(self, exons_df):
        print("Writing exons to db")
        if (self._regions):
            exons_df = exons_df.join(self._regions.select("seq_region_id", "name"),
                                        on=[exons_df.seq_region_name ==
                          self._regions.name], how = 'left' )
        # Fill region id
        exons_df = exons_df.drop("seq_region_name").drop("name")
        exons_df = exons_df.withColumnRenamed("exon_stable_id", "stable_id")
        exons_df_final = exons_df.drop("transcript_stable_id").drop("rank")
        exons_df_final.write.mode("append")\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", self._db)\
                .option("dbtable","exon")\
                .option("user", self._user)\
                .option("password", self._password)\
                .save()
        exons = self._spark.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", self._db)\
                .option("dbtable","exon")\
                .option("user", self._user)\
                .option("password", self._password)\
                .load()
        # Write exon_transcripts
        exon_transcript_df = exons.join(exons_df.select("stable_id", "rank",
                                                        "transcript_stable_id"),
                                        on=[exons.stable_id ==
                                            exons_df.stable_id], how="inner")
        exon_transcript_df = exon_transcript_df.drop_duplicates(["exon_id"])
        print(str(exon_transcript_df.count()))
        exon_transcript_df = exon_transcript_df.join(self._transcripts.select("stable_id",
                                                         "transcript_id"),\
                                on=[exon_transcript_df.transcript_stable_id == self._transcripts.stable_id])
        print(str(exon_transcript_df.count()))
        exon_transcript_df = exon_transcript_df.select("exon_id", "transcript_id", "rank")
        exon_transcript_df.write.mode("append")\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", self._db)\
                .option("dbtable","exon_transcript")\
                .option("user", self._user)\
                .option("password", self._password)\
                .save()

    def write_translations(self, translations_df):
        print("Writing translations to db")

        # Fill transcripts_id
        if (self._transcripts):
            translations_df = translations_df.join(self._transcripts.select("transcript_id", "stable_id"),
                                        on=[translations_df.transcript_stable_id ==
                                            self._transcripts.stable_id], how =
                                                 'left' )
        # We drop transcript.stable_id and translation.transcript_stable_id columns
        translations_df = translations_df.drop("transcript_stable_id").drop("stable_id")
        # Translation stable id cant be initially just stable id, not to mess
        # with transcript stable id.
        translations_df = translations_df.withColumnRenamed("translation_stable_id", "stable_id")
        translations_df.write.mode("append")\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", self._db)\
                .option("dbtable","translation")\
                .option("user", self._user)\
                .option("password", self._password)\
                .save()

    def write_transcripts(self, transcripts_df):
        print("Writing transcripts to db")
        # Fill region id
        if (self._regions):
            transcripts_df = transcripts_df.join(self._regions.select("seq_region_id", "name"),
                                        on=[transcripts_df.seq_region_name ==
                          self._regions.name], how = 'left' )
        transcripts_df = transcripts_df.drop("seq_region_name").drop("name")

        # Fill genes_id
        if (self._genes):
            transcripts_df = transcripts_df.join(self._genes.select("gene_id", "stable_id"),
                                        on=[transcripts_df.gene_stable_id ==
                                            self._genes.stable_id], how =
                                                 'left' )
        # We drop transcript.gene_stable_id and gene.stable_id columns
        transcripts_df = transcripts_df.drop("gene_stable_id").drop("stable_id")
        # Transcript stable id cant be initially just stable id, not to mess
        # with gene stable id.
        transcripts_df = transcripts_df.withColumnRenamed("transcript_stable_id", "stable_id")
        transcripts_df.write.mode("append")\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", self._db)\
                .option("dbtable","transcript")\
                .option("user", self._user)\
                .option("password", self._password)\
                .save()

    def load_to_ensembl (self, file_path) -> None:
        gff_frame = self.load_gff(file_path)
        # write should be in exact order - parent entries first
        if isinstance(gff_frame["region"], list) == False: #If it is not df
            self.write_regions(gff_frame["region"])
            self._regions = self._spark.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", self._db)\
                .option("dbtable","seq_region")\
                .option("user", self._user)\
                .option("password", self._password)\
                .load()

        if isinstance(gff_frame["gene"], list) == False: #If it is not df
            self.write_genes(gff_frame["gene"])
            self._genes = self._spark.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", self._db)\
                .option("dbtable","gene")\
                .option("user", self._user)\
                .option("password", self._password)\
                .load()

        if isinstance(gff_frame["transcript"], list) == False: #If it is not df
            self.write_transcripts(gff_frame["transcript"])
            self._transcripts = self._spark.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", self._db)\
                .option("dbtable","transcript")\
                .option("user", self._user)\
                .option("password", self._password)\
                .load()

        if isinstance(gff_frame["exon"], list) == False: #If it is not df
            self.write_exons(gff_frame["exon"])

        if isinstance(gff_frame["translation"], list) == False: #If it is not df
            self.write_translations(gff_frame["translation"])

    def dump_all_features (self, db, user, password) -> None:
        
        self._regions = self._spark.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", db)\
                .option("query","select s.*, syn.synonym as synonym from seq_region s left join seq_region_synonym syn on syn.seq_region_id=s.seq_region_id")\
                .option("user", user)\
                .option("password", password)\
                .load()

        self._transcripts = self._spark.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", db)\
                .option("dbtable","transcript")\
                .option("user", user)\
                .option("password", password)\
                .load()

        self._genes = self._spark.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", db)\
                .option("query","select g.*, x.display_label as gene_name from gene g left join object_xref ox on g.gene_id = ox.ensembl_id\
                     and ox.ensembl_object_type=\"Gene\" \
                    left join xref x on x.xref_id = ox.xref_id")\
                .option("user", user)\
                .option("password", password)\
                .load()

        self._exons = self._spark.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", db)\
                .option("dbtable","exon")\
                .option("user",  user)\
                .option("password", password)\
                .load()

        self._exon_transcript = self._spark.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", db)\
                .option("dbtable","exon_transcript")\
                .option("user", user)\
                .option("password", password)\
                .load()
                
        transcript_attrib = self._spark.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", db)\
                .option("dbtable","transcript_attrib")\
                .option("user", user)\
                .option("password", password)\
                .load()
                
        biotype_df = self._spark.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", db)\
                .option("dbtable","biotype")\
                .option("user", user)\
                .option("password", password)\
                .load()
                
        assembly_df = self._spark.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", db)\
                .option("dbtable","meta")\
                .option("user", user)\
                .option("password", password)\
                .load()

        biotype_df = biotype_df.select("name", "object_type", "so_term").withColumnRenamed("name", "biotype_name")
        assembly_name = assembly_df.where(assembly_df.meta_key == lit("assembly.name")).collect()[0][3]

        transcript_attrib_basic=transcript_attrib.filter("attrib_type_id=417").withColumnRenamed("value", "basic")
        transcript_attrib_mane_select=transcript_attrib.filter("attrib_type_id=535").withColumnRenamed("value", "mane_select")
        transcript_attrib_mane_clinical=transcript_attrib.filter("attrib_type_id=550").withColumnRenamed("value", "mane_clinical")
        
        # Type
        @udf(returnType=StringType())
        def type(type, so_term):
            result = "type"
            if(len(so_term)>1):
                if so_term == "protein_coding_gene":
                    so_term ="gene"
                result = so_term
            return result
        # Phase
        @udf(returnType=StringType())
        def map_phase(phase):
            if(phase < 0):
                return "."
            return str(phase)
        
        regions = self._regions.select("name", "synonym", "length")\
                    .withColumn("source", lit(assembly_name))\
                    .withColumn("type", lit("region"))\
                    .withColumn("seq_region_start", self._regions.name)\
                    .withColumnRenamed("length", "seq_region_end")\
                    .withColumn("score", lit("."))\
                    .withColumn("phase", lit("."))\
                    .withColumn("seq_region_strand", lit("."))

        genes = self._genes.join(self._regions.select("seq_region_id",
                                                    "name"), on = "seq_region_id")\
                            .join(biotype_df.filter(biotype_df["object_type"]=="gene").drop("object_type")\
                                , on=[biotype_df.biotype_name==self._genes.biotype])\
                            .drop("biotype_name")
        
        genes = genes\
                .withColumn("type", type(lit("gene"), "so_term"))\
                .withColumn("score", lit("."))\
                .withColumn("phase", lit("."))

        transcripts = self._transcripts.join(self._regions.select("seq_region_id",
                                                    "name"), on =
                               [self._transcripts.seq_region_id ==
                                self._regions.seq_region_id])\
                            .join(biotype_df.filter(biotype_df["object_type"]=="transcript").drop("object_type")\
                                , on=[biotype_df.biotype_name==self._transcripts.biotype])\
                            .drop("biotype_name")

        transcripts = transcripts.withColumnRenamed("stable_id",
                                                    "transcript_stable_id")

        
        transcripts = transcripts.join(self._genes.select("stable_id",\
                                                          "gene_id", "canonical_transcript_id", "version", "biotype", "source")\
                                                              .withColumnRenamed("version", "gene_version")\
                                                              .withColumnRenamed("source", "gene_source")\
                                                              .withColumnRenamed("biotype", "gene_biotype"),\
                                       on="gene_id")\
                                .join(transcript_attrib_basic.select("transcript_id", "basic"),\
                                    on = "transcript_id", how = "left")\
                                .join(transcript_attrib_mane_select.select("transcript_id", "mane_select"),\
                                    on= "transcript_id", how = "left")\
                                .join(transcript_attrib_mane_clinical.select("transcript_id", "mane_clinical"),\
                                    on = "transcript_id", how = "left") 
                                                                                      
        transcripts = transcripts\
                .withColumn("type", type(lit("transcript"), "so_term"))\
                .withColumn("score", lit("."))\
                .withColumn("phase", lit("."))

        exons = self._exons.join(self._regions.select("seq_region_id",
                                                    "name"), on =
                               ["seq_region_id"], how="left")

        exons = exons.join(self._exon_transcript, on = ["exon_id"],
                          how = "inner")
        exons = exons.withColumnRenamed("stable_id", "exon_stable_id")

        exons = exons.join(self._transcripts.select("stable_id", "transcript_id"),
                                       on=["transcript_id"])

        exons = exons\
                .withColumn("type", lit("exon"))\
                .withColumn("score", lit("."))\
                 .withColumn("source", lit("ensembl"))\
                 .withColumn("phase", map_phase("phase"))

        
        transcript_service = TranscriptSparkService(self._spark)
        cds = transcript_service.translatable_exons(db, user, password)
        cds = cds.join(self._regions.select("seq_region_id",
                                                    "name"), on =
                               ["seq_region_id"], how="left")
        cds = cds\
                .withColumn("score", lit("."))\
                .withColumn("source", lit("ensembl"))\
                .withColumn("phase", map_phase("phase"))
        
        
        return [genes, transcripts, exons, cds, assembly_df, regions]

    def write_gff(self, file_path,features=None, db="", user="", password="") -> None:
        
        # Join attribs
        @udf(returnType=StringType())
        def joinColumnsExon(feature_id, parent, version, rank, start_phase,
                        end_phase, constitutive):
            result = ""
            if parent:
                result = result + "Parent=transcript:"
                result = result + parent + ";"
            if constitutive:
                result = result + "constitutive=" + str(constitutive) + ";"
            else: 
                result = result + "constitutive=0;"
            if feature_id:
                result = result + "exon_id=" + feature_id + ";"
            if rank:
                result = result + "rank=" + str(rank) + ";"
            if version:
                result = result + "version=" + str(version)

            return result


        # Join attribs
        @udf(returnType=StringType())
        def joinColumnsCds(feature_id, parent, version, protein):
            result = ""
            if feature_id:
                result = result + "ID=CDS:" + str(protein) + ";"
            if parent:
                result = result + "Parent=transcript:"
                result = result + parent + ";"
            if protein:
                result = result + "protein_id=" + str(protein) + ";"
            if version:
                result = result + "version=" + str(version)

            return result


        # Join attribs
        @udf(returnType=StringType())
        def joinColumnsTranscript(parent, feature_id, version, biotype, canonical, basic, mane_select, mane_clinical):
            result = ""
            if feature_id:
                result = result + "ID=transcript:" + feature_id + ";"
            if parent:
                result = result + "Parent=gene:" + parent + ";"
            if biotype:
                result = result + "biotype=" + biotype + ";"
            if canonical or basic or mane_select or mane_clinical:
                result = result + "tag="
            if canonical:
                result = result + "Ensembl_canonical;"
            if basic:
                result = result + "basic;"
            if mane_clinical:
                result = result + "mane_clinical;"
            if mane_select:
                result = result + "mane_select;"
            if feature_id:
                result = result + "transcript_id=" + feature_id + ";"
            if version:
                result = result + "version=" + str(version)


            return result

        # Join attribs
        @udf(returnType=StringType())
        def joinColumnsGene(feature_id, version, name, biotype, description):
            result = ""
            if feature_id:
                result = result + "ID=gene:" + feature_id + ";"
            if name:
                result = result + "Name=" + str(name) + ";"
            if biotype:
                result = result + "biotype=" + biotype + ";"
            if description:
                result = result + "description=" + str(description) + ";"
            if feature_id:
                result = result + "gene_id=" + str(feature_id)  + ";"
            if version:
                result = result + "version=" + str(version)
            return result

        # Join attribs
        @udf(returnType=StringType())
        def joinColumnsRegion(name, synonym):
            result = ""
            if name:
                result = result + "ID=region:" + name + ";"
            if synonym:
                result = result + "Alias=" + str(synonym)
     
            return result
        
        if (features is None):
            features = self.dump_all_features(db, user, password)
        
        [genes, transcripts, exons, cds, assembly_df, regions] = features       
        tmp_fp = file_path + "_tpm"
        assembly_name = assembly_df.where(assembly_df.meta_key == lit("assembly.name")).collect()[0][3]
        assembly_date = assembly_df.where(assembly_df.meta_key == lit("assembly.date")).collect()[0][3]
        assembly_acc = assembly_df.where(assembly_df.meta_key == lit("assembly.accession")).collect()[0][3]
        genebuild_date = assembly_df.where(assembly_df.meta_key == lit("genebuild.last_geneset_update")).collect()[0][3]
        
                
        # Strand
        @udf(returnType=StringType())
        def code_strand(strand):
            result = "+"
            if(strand == -1):
                result = "-"
            return result
        
        regions = regions.withColumn("attributes", joinColumnsRegion("name", "synonym"))
                            
        regions = regions.select("name", "source", "type",\
                                       "seq_region_start", "seq_region_end",\
                                         "score", "seq_region_strand", "phase", "attributes")
        genes = genes.withColumn("attributes",
                                 joinColumnsGene("stable_id",\
                                                       "version",\
                                                       "gene_name",\
                                                       "biotype",\
                                                       "description"))
        genes = genes.select("name", "source", "type",
                        "seq_region_start", "seq_region_end",
                        "score", "seq_region_strand", "phase", "attributes")
        
        transcripts = transcripts.withColumn("attributes",
                                             joinColumnsTranscript("stable_id",
                                                                   "transcript_stable_id",
                                                                   "version",
                                                                   "biotype", 
                                                                   "canonical_transcript_id",
                                                                   "basic",
                                                                   "mane_select",
                                                                   "mane_clinical"))

        transcripts = transcripts.select("name", "source", "type",
                        "seq_region_start", "seq_region_end",
                        "score", "seq_region_strand", "phase", "attributes")
        
        
        exons = exons.withColumn("attributes",
                                             joinColumnsExon("exon_stable_id",\
                                                                   "stable_id",\
                                                                   "version",\
                                                                  "rank",\
                                                                  "phase",\
                                                                   "end_phase",\
                                                                "is_constitutive",\
                                                                 ))
        exons = exons.select("name", "source", "type",
                                       "seq_region_start", "seq_region_end",
                                         "score", "seq_region_strand", "phase", "attributes")
        
        cds = cds.withColumn("attributes",
                                             joinColumnsCds("exon_stable_id",\
                                                                   "transcript_stable_id",\
                                                                   "version",\
                                                                  "stable_id"
                                                                 ))
        cds = cds.select("name", "source", "type",
                                       "seq_region_start", "seq_region_end",
                                         "score", "seq_region_strand", "phase", "attributes")


        combined_df = genes.withColumn("priority", lit("3"))
        # Combined df append transcripts
        combined_df = combined_df.union(transcripts.withColumn("priority", lit("3")))
        combined_df = combined_df.union(exons.withColumn("priority", lit("3")))
        combined_df = combined_df.union(cds.withColumn("priority", lit("3")))
        combined_df = combined_df.withColumn("seq_region_strand", code_strand("seq_region_strand"))
        combined_df = combined_df.union(regions.withColumn("priority", lit("1"))) 
        combined_df = combined_df.withColumn("seq_region_start",combined_df.seq_region_start.cast('int'))       
        combined_df = combined_df.repartition(1).orderBy("name", "priority", "seq_region_start").drop("priority")
        combined_df.write.option("header", False).mode('overwrite').option("delimiter", "\t").csv(tmp_fp + "_features")
        head = "##sequence-region"
        regions_header = self._regions.withColumn("prompt", lit(head)).withColumn("start", lit("1"))
        regions_header = regions_header.select("prompt", "name", "start", "length")
        regions_header.dropDuplicates().repartition(1).orderBy("name").write.option("header", False).mode('overwrite').option("quote", "").option("delimiter", "\t").csv(tmp_fp + "_regions")
        
        try:
            os.remove(file_path)
        except OSError:
            pass
        
        
        # Find file in temp spark dir
        feature_file = glob.glob(tmp_fp + "_features/part-0000*")[0]
        region_file = glob.glob(tmp_fp + "_regions/part-0000*")[0]
        print(region_file)
        f = open(file_path, "a")
        #Write header
        f.write("##gff-version 3\n")
        #Write regions
        f_cvs = open(region_file)
        file_line = f_cvs.readline()
        while file_line:
            f.write(file_line)
            file_line = f_cvs.readline()
        f_cvs.close()
        #Write assembly

        
        f.write("#!genome-build " + assembly_name)
        f.write("\n#!genome-version " + assembly_name)
        f.write("\n#!genome-date " + assembly_date)
        f.write("\n#!genome-build-accession " + assembly_acc)
        f.write("\n#!genebuild-last-updated " + genebuild_date + "\n")

        #Write features       
        f_cvs = open(feature_file)
        file_line = f_cvs.readline()
        while file_line:
            if(file_line.find("ID=gene:") > -1):
                f.write("###\n")
            f.write(file_line)
            file_line = f_cvs.readline()
        f_cvs.close()
        f.close()
       # os.rmdir(tmp_fp + "_features")
       # os.rmdir(tmp_fp + "_regions")

        return
    
    
    def write_gtf(self, file_path, features=None, db="", user="", password="", ) -> None:
        
        if (features is None):
            features = self.dump_all_features(db, user, password)
        
        [genes, transcripts, exons, cds, assembly_df, regions] = features
                
        tmp_fp = file_path + "_tpm"
        assembly_name = assembly_df.where(assembly_df.meta_key == lit("assembly.name")).collect()[0][3]
        assembly_date = assembly_df.where(assembly_df.meta_key == lit("assembly.date")).collect()[0][3]
        assembly_acc = assembly_df.where(assembly_df.meta_key == lit("assembly.accession")).collect()[0][3]
        genebuild_date = assembly_df.where(assembly_df.meta_key == lit("genebuild.last_geneset_update")).collect()[0][3]
        
               
        # Join attribs
        @udf(returnType=StringType())
        def joinColumnsExon(feature_id, version, rank, constitutive, tr_stable_id, tr_biotype, tr_source, tr_version, g_stable_id, g_biotype, g_source, g_version):
            result = ""
            if g_stable_id:
                result = result + "gene_id \"" + g_stable_id + "\"; "
            if g_version:
                result = result + "gene_version \"" + str(g_version) + "\"; "
            if tr_stable_id:
                result = result + "transcript_id \"" + tr_stable_id + "\"; "
            if tr_version:
                result = result + "transcript_version \"" + str(tr_version) + "\"; "
            if rank:
                result = result + "exon_number \"" + str(rank) + "\"; "
            if g_source:
                result = result + "gene_source \"" + g_source + "\"; "
            if g_biotype:
                result = result + "gene_biotype \"" + g_biotype + "\"; "
            if tr_source:
                result = result + "transcript_source \"" + tr_source + "\"; "
            if tr_biotype:
                result = result + "transcript_biotype \"" + tr_biotype + "\"; "
            if feature_id: 
                result = result + "exon_id \"" + feature_id + "\"; "
            if version:
                result = result + "exon_version " + str(version) + "\"; "

            return result


        # Join attribs
        @udf(returnType=StringType())
        def joinColumnsCds(feature_id, parent, version, protein):
            result = ""
            if feature_id:
                result = result + "ID=CDS:" + str(protein) + ";"
            if parent:
                result = result + "Parent=transcript:"
                result = result + parent + ";"
            if protein:
                result = result + "protein_id=" + str(protein) + ";"
            if version:
                result = result + "version=" + str(version)

            return result


        # Join attribs
        @udf(returnType=StringType())
        def joinColumnsTranscript(parent, feature_id, version, biotype, canonical, basic, mane_select, mane_clinical, gene_version, gene_biotype, gene_source, transcript_source):
            result = ""

            if parent:
                result = result + "gene_id \"" + parent + "\"; "
            if gene_version:
                result = result + "gene_version \"" + str(gene_version) + "\"; " 
            if feature_id:
                result = result + "transcript_id \"" + feature_id + "\"; "           
            if version:
                result = result + "transcript_version \"" + str(version) + "\"; "  
            
            result = result + "gene_source \"" + gene_source +"\"; " 
            if gene_biotype:
                result = result + "gene_biotype \"" + gene_biotype + "\"; "
            result = result + "transcript_source \"" + transcript_source +"\"; " 
            if biotype:
                result = result + "transcript_biotype \"" + biotype + "\"; "
            if canonical or basic or mane_select or mane_clinical:
                result = result + "tag "
            if canonical:
                result = result + "\"Ensembl_canonical\";"
            if basic:
                result = result + "\"basic\";"
            if mane_clinical:
                result = result + "\"mane_clinical\";"
            if mane_select:
                result = result + "\"mane_select\";"
            return result

        # Join attribs
        @udf(returnType=StringType())
        def joinColumnsGene(feature_id, version, biotype, gene_source):
            result = ""
            if feature_id:
                result = result + "gene_id \"" + feature_id + "\"; "
            if version:
                result = result + "gene_version \"" + str(version) + "\"; "

            result = result + "gene_source \"" + gene_source +"\"; "
            if biotype:
                result = result + "gene_biotype \"" + biotype + "\"; "

            return result
                
        # Strand
        @udf(returnType=StringType())
        def code_strand(strand):
            result = "+"
            if(strand == -1):
                result = "-"
            return result
        
        genes = genes.withColumn("attributes",
                                 joinColumnsGene("stable_id",\
                                                       "version",\
                                                       "biotype", "source"))        
        genes = genes.withColumn("feature_type", lit("gene"))
        genes = genes.select("name", "source", "feature_type",
                        "seq_region_start", "seq_region_end",
                        "score", "seq_region_strand", "phase", "attributes")
        transcripts = transcripts.withColumn("attributes",
                                             joinColumnsTranscript("stable_id",
                                                                   "transcript_stable_id",
                                                                   "version",
                                                                   "biotype", 
                                                                   "canonical_transcript_id",
                                                                   "basic",
                                                                   "mane_select",
                                                                   "mane_clinical", "gene_version", "gene_biotype", "gene_source", "source"))
        
        transcripts = transcripts.withColumn("feature_type", lit("transcript"))

        exons = exons.join(transcripts.select("transcript_id", "source", "version", "biotype", "gene_biotype", "gene_source", "gene_version", "stable_id", "transcript_stable_id")\
            .withColumnRenamed("source", "transcript_source")\
            .withColumnRenamed("stable_id", "gene_stable_id")\
            .withColumnRenamed("version", "transcript_version")\
            .withColumnRenamed("biotype", "transcript_biotype"),\
            on = ["transcript_id"])

        exons = exons.withColumn("attributes",
                                             joinColumnsExon("exon_stable_id",\
                                                                "version",\
                                                                "rank",\
                                                                "is_constitutive",\
                                                                "transcript_stable_id",\
                                                                "transcript_biotype",\
                                                                "transcript_source",\
                                                                "transcript_version",\
                                                                "gene_stable_id",\
                                                                "gene_biotype",\
                                                                "gene_source",\
                                                                "gene_version"))
        exons = exons.withColumn("feature_type", lit("exon"))
        transcripts = transcripts.select("name", "source", "feature_type",
                        "seq_region_start", "seq_region_end",
                        "score", "seq_region_strand", "phase", "attributes")
        exons = exons.select("name", "source", "feature_type",
                                       "seq_region_start", "seq_region_end",
                                         "score", "seq_region_strand", "phase", "attributes")
        cds = cds.withColumn("attributes",
                                             joinColumnsCds("exon_stable_id",\
                                                                   "transcript_stable_id",\
                                                                   "version",\
                                                                  "stable_id"
                                                                 ))        
        cds = cds.withColumn("feature_type", lit("CDS"))
        cds = cds.select("name", "source", "feature_type",
                                       "seq_region_start", "seq_region_end",
                                         "score", "seq_region_strand", "phase", "attributes")

        combined_df = genes.withColumn("priority", lit("3"))
        # Combined df append transcripts
        combined_df = combined_df.union(transcripts.withColumn("priority", lit("3")))
        combined_df = combined_df.union(exons.withColumn("priority", lit("3")))
        combined_df = combined_df.union(cds.withColumn("priority", lit("3")))
        combined_df = combined_df.withColumn("seq_region_strand", code_strand("seq_region_strand"))
        combined_df = combined_df.withColumn("seq_region_start",combined_df.seq_region_start.cast('int'))       
        combined_df = combined_df.repartition(1).orderBy("name", "priority", "seq_region_start").drop("priority")
        combined_df.write.option("quote", "").option("escape", "\"").option("header", False).mode('overwrite').option("delimiter", "\t").csv(tmp_fp + "_features")
        
        try:
            os.remove(file_path)
        except OSError:
            pass
        
        
        # Find file in temp spark dir
        feature_file = glob.glob(tmp_fp + "_features/part-0000*")[0]

        f = open(file_path, "a")
        #Write assembly
        
        f.write("#!genome-build " + assembly_name)
        f.write("\n#!genome-version " + assembly_name)
        f.write("\n#!genome-date " + assembly_date)
        f.write("\n#!genome-build-accession " + assembly_acc)
        f.write("\n#!genbuild-last-updated " + genebuild_date + "\n")

        #Write features       
        f_cvs = open(feature_file)
        file_line = f_cvs.readline()
        while file_line:
            f.write(file_line)
            file_line = f_cvs.readline()
        f_cvs.close()
        f.close()
       # os.rmdir(tmp_fp + "_feature/")

        return

    def _check_gff_file (self, file_path) -> bool:
        if (os.path.exists(file_path) == False):
            f = open(file_path, "a")
            f.write("##gff-version 3\n")
            f.close()
            return True
        f = open(file_path, "r")
        # read version
        file_line = f.readline()
        f.close()
        if (file_line.split(" ")[0] != "##gff-version"):
            warnings.warn("File is not gff3, either input correct gff3 file or non-existing file path, to be crreated")
            return False
        return True

