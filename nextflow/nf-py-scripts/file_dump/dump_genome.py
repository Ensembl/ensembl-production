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

import sys
from pyspark import SparkConf
from pyspark.sql import SparkSession
from pyspark.sql.functions import lit, col, concat, length, udf, least, greatest
from ensembl.production.spark.core.FileSystemSparkService import FileSystemSparkService
from ensembl.production.spark.core.SequenceService import SequenceService
from pyspark.sql.types import StringType
import argparse
import glob
import shutil
import os

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
confi.set("spark.driver.memory", "20g")
confi.set("spark.cores.max", "4")
confi.set("spark.jars",  base_dir + "/ensembl-production/mysql-connector-j-8.1.0.jar")
confi.set("spark.sql.autoBroadcastJoinThreshold", 7485760)
confi.set("spark.driver.extraJavaOptions", "-XX:+HeapDumpOnOutOfMemoryError")
confi.set("spark.driver.maxResultSize", "10G")
confi.set("spark.ui.showConsoleProgress", "false")
spark_session = SparkSession.builder.appName('ensembl.org').config(conf = confi).getOrCreate()
spark_session.sparkContext.setLogLevel("ERROR")
#need to create working dirs $output_dir, $timestamped_dir, $web_dir, $ftp_dir for each assembly (species) and data category
# we assume the following data categories for core fd:  
# 'GenomeDirectoryPaths','GenesetDirectoryPaths','RNASeqDirectoryPaths', 'HomologyDirectoryPaths'

# Genome fasta
sequence_service = SequenceService(spark_session)
genome_path = "genome_sequence"
fasta_df = sequence_service.build_top_level_seq(url,  username, pwd, genome_path)
file_service = FileSystemSparkService(spark_session)
#fasta = file_service.write_df_to_orc(fasta, "genome", "")

@udf(returnType=StringType())
def seq_split(seq):
    line_length = 60
    result = seq[:line_length]
    i = line_length
    while(i < len(seq)):
        result = result + "\n" + seq[i:i+line_length]
        i = i + line_length
    return  result
            
#Getting cs version
csversion = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", "select cs.version from coord_system cs join seq_region sr on sr.coord_system_id = cs.coord_system_id right join transcript t on t.seq_region_id = sr.seq_region_id limit 1")\
            .option("user", username)\
            .option("password", pwd)\
            .load()\
            .collect()[0][0]


#Unite pep header
fasta = fasta.orderBy("name")

fasta = fasta\
    .select(concat(lit(">"),col("name"),\
       lit(":")).alias("info"),\
       col("sequence"))

fasta = fasta.select("info", "sequence")
fasta = fasta.withColumn("sequence", seq_split("sequence"))
#Write to fasta
fasta.repartition(1)\
    .write\
    .mode('overwrite')\
    .option("header", False)\
    .option("escapeQuotes", False)\
    .option("quote", "$")\
    .option("delimiter", "\n")\
    .csv("./fasta_genome")
file = glob.glob("./fasta_genome" + "/part-0000*")[0]
f_cvs = open(file)
f = open("genome.fa", "a")
file_line = f_cvs.readline()
while file_line:
    if(file_line[0:1] == "$"):
        file_line = file_line[1:]
    if(file_line[-2:-1] == "$"):
        file_line = file_line[:-2] + "\n"
    f.write(file_line)
    file_line = f_cvs.readline()
f_cvs.close()
f.close()

    
    
