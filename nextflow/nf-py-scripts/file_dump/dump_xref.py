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
from pyspark import SparkConf
from pyspark.sql import SparkSession
from pyspark.sql.functions import lit, col, concat, udf, least, greatest
from ensembl.production.spark.core.TranscriptSparkService import TranscriptSparkService
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

args = parser.parse_args()
# Individual arguments can be accessed as attributes...
pwd = args.password
username = args.username
url = args.db
base_dir = args.base_dir

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


#Get genes information
translation_xref = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", "select t.stable_id as protein_stable_id, t.transcript_id, ox.ensembl_id, x.* from translation t left join (select * from object_xref where ensembl_object_type=\"Translation\") ox on t.translation_id = ox.ensembl_id join xref x on x.xref_id = ox.xref_id")\
            .option("user", username)\
            .option("password", pwd)\
            .load()

transcript_xref = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", "select t.stable_id as transcript_stable_id, t.canonical_translation_id, t.transcript_id, t.gene_id, ox.ensembl_id, x.* from transcript t left join (select * from object_xref where ensembl_object_type=\"Transcript\") ox on t.transcript_id = ox.ensembl_id join xref x on x.xref_id = ox.xref_id")\
            .option("user", username)\
            .option("password", pwd)\
            .load()
gene_xref = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", "select g.stable_id as gene_stable_id, g.gene_id, ox.ensembl_id, x.* from gene g right join (select * from object_xref where object_xref.ensembl_object_type=\"Gene\") ox on g.gene_id = ox.ensembl_id left join xref x on x.xref_id = ox.xref_id")\
            .option("user", username)\
            .option("password", pwd)\
            .load()

gene = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", "select gene_id, stable_id as gene_stable_id from gene")\
            .option("user", username)\
            .option("password", pwd)\
            .load()

transcript = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", "select gene_id, transcript_id, stable_id as transcript_stable_id from transcript")\
            .option("user", username)\
            .option("password", pwd)\
            .load()

translation = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", "select translation_id as canonical_translation_id, stable_id as protein_stable_id from translation")\
            .option("user", username)\
            .option("password", pwd)\
            .load()

transcript = transcript.join(gene, on = ["gene_id"])

external_db = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", "select external_db_id, db_display_name as db_name from external_db")\
            .option("user", username)\
            .option("password", pwd)\
            .load()

dependent_xref = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", "select * from dependent_xref")\
            .option("user", username)\
            .option("password", pwd)\
            .load()

transcript_xref = transcript_xref.join(translation, on = ["canonical_translation_id"], how = "left_outer").drop("canonical_translation_id").join(gene.select("gene_id", "gene_stable_id"), on = ["gene_id"]).drop("gene_id")
translation_xref = translation_xref.join(transcript.select("gene_stable_id", "transcript_stable_id", "transcript_id"), on = ["transcript_id"]).drop("transcript_id")
transcript_xref = transcript_xref.drop("transcript_id")

gene_xref = gene_xref.withColumn("protein_stable_id", lit(""))\
    .withColumn("transcript_stable_id", lit("")).drop("gene_id")
xref = gene_xref.unionByName(transcript_xref).unionByName(translation_xref).dropDuplicates()\
    .withColumnRenamed("display_label", "xref_label")\
    .join(external_db, on = ["external_db_id"], how = "left_outer")
xref = xref.join(dependent_xref, on = [xref.xref_id==dependent_xref.dependent_xref_id], how = "left_outer")
xref.filter("protein_stable_id=\"ENSABMP00000000024\"").show()
xref_tmp = xref.withColumn("source", concat("db_name", lit(":"), "xref_label")).select("xref_id", "source")
xref = xref.join(xref_tmp, on = [xref.master_xref_id==xref_tmp.xref_id], how = "left_outer").drop("xref_id")

xref = xref.withColumnRenamed("dbprimary_acc", "xref_id")
    
xref = xref.select("gene_stable_id", "transcript_stable_id", "protein_stable_id", "xref_id", "xref_label", "description", "db_name", "info_type", "source")

#Write to fasta
xref.repartition(1)\
    .write\
    .mode('overwrite')\
    .option("header", True)\
    .option("delimiter", " \t")\
    .option("emptyValue", '')\
    .csv("./xref_csv")

file = glob.glob("./xref_csv" + "/part-0000*")[0]
shutil.copyfile(file, "xref.tsv")
