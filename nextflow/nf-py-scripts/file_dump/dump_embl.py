#!/usr/bin/env python3
"""
.. See the NOTICE file distributed with this work for additional information
   regarding copyright ownership.
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
       http://www.apache.org/licenses/LICENSE-2.0
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
"""

url =\
"jdbc:mysql://mysql-ens-core-prod-1:4524/mus_musculus_casteij_core_114_2"
username = "ensro"
pwd = ""

import sys
import glob
from pyspark import SparkConf
from pyspark.sql import SparkSession
from ensembl.production.spark.core.TranscriptSparkService import TranscriptSparkService
from pyspark.sql.functions import concat, concat_ws, collect_list, lit, expr

import argparse

# Define the parser
parser = argparse.ArgumentParser(description='Fasta files dump')
parser.add_argument('--password', action="store", dest='password', default="")
parser.add_argument('--username', action="store", dest='username', default="ensro")
parser.add_argument('--db', action="store", dest='db', default="")
parser.add_argument('--base_dir', action="store", dest='base_dir', default="")
parser.add_argument('--sequence', action="store", dest='sequence', default="")

args = parser.parse_args()
# Individual arguments can be accessed as attributes...
pwd = args.password
username = args.username
url = args.db
base_dir = args.base_dir
sequence = args.sequence

import os
confi=SparkConf()
confi.set("spark.executor.memory", "14g")
confi.set("spark.driver.memory", "40g")
confi.set("spark.cores.max", "4")
confi.set("spark.jars",  base_dir + "/ensembl-production/mysql-connector-j-8.1.0.jar")
confi.set("spark.sql.autoBroadcastJoinThreshold", 7485760)
confi.set("spark.driver.extraJavaOptions", "-XX:+HeapDumpOnOutOfMemoryError")
confi.set("spark.driver.maxResultSize", "15G")
confi.set("spark.ui.showConsoleProgress", "false")
spark_session = SparkSession.builder.appName('ensembl.org').config(conf = confi).getOrCreate()
spark_session.sparkContext.setLogLevel("ERROR")

transcript_service = TranscriptSparkService(spark_session)

translatable_exons = transcript_service.translatable_exons(url, username, pwd, None, None, False)
mRNA = translatable_exons
mRNA = mRNA.withColumn("coordinates", concat("seq_region_start", lit(".."), "seq_region_end"))
mRNA =\
        mRNA.groupBy("transcript_stable_id")\
        .agg(concat_ws(",", expr("""transform(sort_array(collect_list(struct(rank,coordinates)),True), x -> x.coordinates)"""))\
        .alias("coordinates"))\
        .drop("version", "created_date", "modified_date", "stable_id")\

file_path = "./test.embl"
sequence = spark_session.read.orc(sequence)


tmp_fp = "_embl"

mRNA.write.option("header", False).mode('overwrite').option("delimiter", "\t").csv(tmp_fp + "_features")
             
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