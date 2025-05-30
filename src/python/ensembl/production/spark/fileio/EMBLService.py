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

__all__ = ['EMBLService']
from pyspark.sql.types import StringType, BooleanType, DecimalType
from ensembl.production.spark.core.TranscriptSparkService import TranscriptSparkService
from pathlib import Path
import glob
import warnings
from pyspark.sql.functions import udf, substring, concat_ws, expr, collect_list, sort_array
from pyspark.sql.window import Window
from typing import Optional
import os
from pyspark.sql.functions import lit
from ensembl.production.spark.core.FileSystemSparkService import FileSystemSparkService


class EMBLService():

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


    def write_embl(self, file_path, features=None, sequence=None, db="", user="", password="", ) -> None:
        
        if (features is None):
            features = self.dump_all_features(db, user, password)
        
        if (sequence is None):
            return 1
        sequence = self._spark.read.orc(sequence)
        
        [genes, transcripts, exons, cds, assembly_df, regions] = features
        assembly_name = assembly_df.where(assembly_df.meta_key == lit("assembly.name")).collect()[0][3]
        assembly_date = assembly_df.where(assembly_df.meta_key == lit("assembly.date")).collect()[0][3]
        assembly_acc = assembly_df.where(assembly_df.meta_key == lit("assembly.accession")).collect()[0][3]
        genebuild_date = assembly_df.where(assembly_df.meta_key == lit("genebuild.last_geneset_update")).collect()[0][3]

        tmp_fp = assembly_name + "_embl"

        cds.write.option("header", False).mode('overwrite').option("delimiter", "\t").csv(tmp_fp + "_features")
             
        try:
            os.remove(file_path)
        except OSError:
            pass
        

        feature_file = glob.glob(tmp_fp + "_features/part-0000*")[0]
        f = open(file_path, "a")

        #Write features       
        f_cvs = open(feature_file)
        file_line = f_cvs.readline()
        while file_line:
            f.write(file_line)
            file_line = f_cvs.readline()
        f_cvs.close()
        f.close()

        return
