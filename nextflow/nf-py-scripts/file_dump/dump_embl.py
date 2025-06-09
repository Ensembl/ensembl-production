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
from pyspark.sql.functions import concat, concat_ws, lit, expr, udf
from pyspark.sql.types import BooleanType, StringType
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
mRNA_pos = mRNA.filter("seq_region_strand>0").withColumn("coordinates", concat("seq_region_start", lit(".."), "seq_region_end"))
mRNA_neg = mRNA.filter("seq_region_strand<0").withColumn("coordinates", concat(lit("compliment("), "seq_region_start", lit(".."), "seq_region_end", lit(")")))
mRNA = mRNA_neg.unionByName(mRNA_pos)
mRNA =\
        mRNA.groupBy("transcript_stable_id", "version", "gene_id")\
        .agg(concat_ws(",", expr("""transform(sort_array(collect_list(struct(rank,coordinates)),True), x -> x.coordinates)"""))\
        .alias("coordinates"))\
        .drop("created_date", "modified_date", "stable_id")

#Is transcript canonical
@udf(returnType=BooleanType())
def is_single(coordinates):
    return coordinates.find(",") < 0

#Slit coordinates to lines
@udf(returnType=StringType())
def splitCoordinates(coordinates):
    coordinates = coordinates.split(",")
    if(len(coordinates) < 2):
         return "\nFT   " + coordinates[0]
    length = len(coordinates[1])
    repeats = 57//length
    
    i = 1
    coord_local = "\nFT   " + coordinates[0] + ","
    for j in range(0, repeats - 1):
        coord_local = coord_local + coordinates[i] + ","
        if (i < len(coordinates)-1):
            i = i+1
    result = coord_local

    for x in range(0, len(coordinates) - 1, repeats):
         coord_local = ""
         if (i >= len(coordinates)-1):
             break
         for j in range(0, repeats):
              coord_local = coord_local + coordinates[i] + ","
              if (i < len(coordinates)-1):
                i = i+1
              else:
                  break
 
         result = result + "\nFT                   " + coord_local
    
    return result[:-1]

genes = spark_session.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", url)\
                .option("query","select g.*, x.display_label as gene_name from gene g left join object_xref ox on g.gene_id = ox.ensembl_id\
                     and ox.ensembl_object_type=\"Gene\" \
                    left join xref x on x.xref_id = ox.xref_id")\
                .option("user", username)\
                .option("password", pwd)\
                .load()

mRNA = mRNA.withColumn("single", is_single("coordinates"))

mRNA_single = mRNA.filter("single=True")

mRNA =\
    mRNA.filter("single=False").withColumn("coordinates", concat(lit("join("), "coordinates", lit(")")))

mRNA = mRNA.unionByName(mRNA_single)
mRNA = mRNA.withColumn("coordinates", concat(lit("mRNA            "), "coordinates"))
mRNA = mRNA.withColumn("coordinates", splitCoordinates("coordinates"))
mRNA = mRNA.join(genes.withColumnRenamed("stable_id", "gene_stable_id").withColumnRenamed("version", "gene_version").select("gene_id", "gene_stable_id", "gene_version"), on=["gene_id"])
mRNA = mRNA.withColumn("gene_id", concat(lit("FT                   /gene=\""), "gene_stable_id", lit("."), "gene_version",lit("\"")))
mRNA = mRNA.withColumn("feature_id", concat(lit("FT                   /standard_name=\""), "transcript_stable_id", lit("."), "version",lit("\"")))
mRNA = mRNA.orderBy("transcript_stable_id").select("coordinates", "gene_id", "feature_id")

file_path = "./test.embl"
sequence = spark_session.read.orc(sequence)

tmp_fp = "_embl"

mRNA.repartition(1).write.option("header", False).mode('overwrite').option("quote", "").option("delimiter", "\n").csv(tmp_fp + "_features")
             
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
        file_line = file_line.replace("\x00", "")         
        f.write(file_line)
        file_line = f_cvs.readline()

f_cvs.close()
f.close()