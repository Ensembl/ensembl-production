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

from ensembl.production.spark.core.TranscriptSparkService import TranscriptSparkService
from ensembl.production.spark.core.FileSystemSparkService import FileSystemSparkService
import sqlalchemy

from pyspark.sql.functions import concat, concat_ws, col, lit, expr, udf, regexp_replace, desc
import argparse
from sqlalchemy import text
from pyspark import SparkConf
from pyspark.sql import SparkSession
from pyspark.sql.types import *
import glob

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


confi=SparkConf()
confi.set("spark.executor.memory", "10g")
confi.set("spark.driver.memory", "15g")
confi.set("spark.cores.max", "1")
confi.set("spark.jars",  base_dir + "/ensembl-production/mysql-connector-j-8.1.0.jar")
confi.set("spark.sql.autoBroadcastJoinThreshold", 7485760)
confi.set("spark.driver.extraJavaOptions", "-XX:+HeapDumpOnOutOfMemoryError")
confi.set("spark.driver.maxResultSize", "3G")
confi.set("spark.ui.showConsoleProgress", "false")
spark_session = SparkSession.builder.appName('ensembl.org').config(conf = confi).getOrCreate()
spark_session.sparkContext.setLogLevel("ERROR")

import os
#need to create working dirs $output_dir, $timestamped_dir, $web_dir, $ftp_dir for each assembly (species) and data category
# we assume the following data categories for core fd:  
# 'GenomeDirectoryPaths','GenesetDirectoryPaths','RNASeqDirectoryPaths', 'HomologyDirectoryPaths'

line_length = 60

dna = spark_session.read.orc(sequence)
regions = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("dbtable", "(select sr.name as sr_name, sr.seq_region_id, sr.length, cs.* from seq_region sr join coord_system cs on cs.coord_system_id = sr.coord_system_id where cs.rank=1)tmp")\
            .option("user", username)\
            .option("password", pwd)\
            .load().dropDuplicates()

assembly_level = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("dbtable", "(select meta_value from meta where meta_key=\"assembly.level\")tmp")\
            .option("user", username)\
            .option("password", pwd)\
            .load().collect()

if (len(assembly_level) > 0):
    assembly_level = assembly_level[0][0]
else: 
    assembly_level = "chromosome"

@udf(returnType=StringType())
def split_seq(sequence):
    return ('\n').join((sequence[i:i+line_length]) for i in range(0, len(sequence), line_length)) + "\n"

@udf(returnType=StringType())
def apply_repeats(sequence, repeats):
    repeats = repeats.split(" ")
    result = ""
    offset = 0
    for repeat in repeats:
        seq_region_start = int(repeat.split(":")[0]) - offset
        seq_region_end = int(repeat.split(":")[1]) - offset
        seq_start = seq_region_start - 1
        if seq_region_end < 0:
            continue
        if seq_region_start <= 0:
            seq_start = 0          
        result = result + sequence[:seq_start] + sequence[seq_start:seq_region_end].lower()
        sequence = sequence[seq_region_end:]
        offset = seq_region_end
    return result

@udf(returnType=StringType())
def apply_repeats_hard(sequence, repeats):
    repeats = repeats.split(" ")
    result = ""
    offset = 0
    for repeat in repeats:
        seq_region_start = int(repeat.split(":")[0]) - offset
        seq_region_end = int(repeat.split(":")[1]) - offset
        seq_start = seq_region_start - 1
        if seq_region_end < 0:
            continue
        if seq_region_start <= 0:
            seq_start = 0          
        result = result + sequence[:seq_start] + "N"*(seq_region_end - seq_region_start)
        sequence = sequence[seq_region_end:]
        offset = seq_region_end
    return result


dna = dna.join(regions, on = ["seq_region_id"], how = "left_outer")
dna_unmasked = dna.withColumn("info", concat(\
    lit(">") , "sr_name", lit(" unmasked:"), lit(assembly_level + " "), "name", lit(":"),\
        "version", lit(":"), "sr_name", lit(":1:"), "length", lit(":"), "rank"))\
        .withColumn("sequence", split_seq("sequence"))\
        .orderBy("seq_region_id")\
        .select("info", "sequence")

dna_unmasked.repartition(1)\
    .write\
    .mode('overwrite')\
    .option("header", False)\
    .option("escapeQuotes", False)\
    .option("quote", "$")\
    .option("quoteAll", False)\
    .option("delimiter", "\n")\
    .csv("./fasta_unmasked")
file = glob.glob( "./fasta_unmasked"  + "/part-0000*")[0]

f_cvs = open(file)
f = open("unmasked.fa", "w")
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

repeats = spark_session.read\
        .format("jdbc")\
        .option("driver", "com.mysql.cj.jdbc.Driver")\
        .option("url", url)\
        .option("dbtable", "(select * from repeat_feature where analysis_id in (select analysis_id from analysis join meta on meta.meta_value=analysis.logic_name and meta.meta_key=\"repeat.analysis\"))tmp")\
        .option("user", username)\
        .option("password", pwd)\
        .load()

file_service = FileSystemSparkService(spark_session)
repeats = file_service.write_df_to_orc(repeats,
                                            "repeats", "repeats")
repeats = repeats.withColumn("ends", concat("seq_region_start", lit(":"), "seq_region_end"))
repeats = repeats.groupBy("seq_region_id")\
            .agg(concat_ws(" ",expr("""transform(sort_array(collect_list(struct(seq_region_id,ends)),True), x -> x.ends)"""))\
                    .alias("ends"))

dna_softmasked = dna.withColumn("info", concat(\
    lit(">") , "sr_name", lit(" softmasked:"), lit(assembly_level + " "), "name", lit(":"),\
        "version", lit(":"), "sr_name", lit(":1:"), "length", lit(":"), "rank"))\
        .orderBy("seq_region_id")\
        .select("seq_region_id", "info", "sequence")\
        .join(repeats.select("seq_region_id", "ends"), on = ["seq_region_id"])
dna_softmasked = file_service.write_df_to_orc(dna_softmasked,
                                            "dna_softmasked", "dna_softmasked")

dna_softmasked = dna_softmasked.withColumn("sequence", apply_repeats("sequence", "ends")).select("info", "sequence")

dna_softmasked.repartition(1)\
    .write\
    .mode('overwrite')\
    .option("header", False)\
    .option("escapeQuotes", False)\
    .option("quote", "$")\
    .option("quoteAll", False)\
    .option("delimiter", "\n")\
    .csv("./fasta_softmasked")
file = glob.glob( "./fasta_softmasked"  + "/part-0000*")[0]

f_cvs = open(file)
f = open("softmasked.fa", "w")
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

dna_hardmasked = dna.withColumn("info", concat(\
    lit(">") , "sr_name", lit(" softmasked:"), lit(assembly_level + " "), "name", lit(":"),\
        "version", lit(":"), "sr_name", lit(":1:"), "length", lit(":"), "rank"))\
        .orderBy("seq_region_id")\
        .select("seq_region_id", "info", "sequence")\
        .join(repeats.select("seq_region_id", "ends"), on = ["seq_region_id"])
dna_hardmasked = file_service.write_df_to_orc(dna_hardmasked,
                                            "dna_hardmasked", "dna_hardmasked")

dna_hardmasked = dna_hardmasked.withColumn("sequence", apply_repeats_hard("sequence", "ends")).select("info", "sequence")

dna_hardmasked.repartition(1)\
    .write\
    .mode('overwrite')\
    .option("header", False)\
    .option("escapeQuotes", False)\
    .option("quote", "$")\
    .option("quoteAll", False)\
    .option("delimiter", "\n")\
    .csv("./fasta_hardmasked")
file = glob.glob( "./fasta_hardmasked"  + "/part-0000*")[0]

f_cvs = open(file)
f = open("hardmasked.fa", "w")
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
