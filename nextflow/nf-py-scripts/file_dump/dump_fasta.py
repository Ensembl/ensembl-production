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

from pyspark import SparkConf
from pyspark.sql import SparkSession
from pyspark.sql.functions import lit, col, concat, udf, least, greatest
from ensembl.production.spark.core.TranscriptSparkService import TranscriptSparkService
from pyspark.sql.types import StringType
import argparse
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

import os
confi=SparkConf()
confi.set("spark.executor.memory", "10g")
confi.set("spark.driver.memory", "15g")
confi.set("spark.cores.max", "3")
confi.set("spark.jars",  base_dir + "/ensembl-production/mysql-connector-j-8.1.0.jar")
confi.set("spark.sql.autoBroadcastJoinThreshold", 7485760)
confi.set("spark.driver.extraJavaOptions", "-XX:+HeapDumpOnOutOfMemoryError")
confi.set("spark.driver.maxResultSize", "3G")
confi.set("spark.ui.showConsoleProgress", "false")
spark_session = SparkSession.builder.appName('ensembl.org').config(conf = confi).getOrCreate()
spark_session.sparkContext.setLogLevel("ERROR")
transcript_service = TranscriptSparkService(spark_session)
#need to create working dirs $output_dir, $timestamped_dir, $web_dir, $ftp_dir for each assembly (species) and data category
# we assume the following data categories for core fd:  
# 'GenomeDirectoryPaths','GenesetDirectoryPaths','RNASeqDirectoryPaths', 'HomologyDirectoryPaths'


@udf(returnType=StringType())
def trimSeq(sequence):
        if(sequence[0:1] == "!"):
            sequence = sequence[1:]
        if(sequence[-1:] == "*"):
            sequence = sequence[:-1]
        return sequence

fastaDf = spark_session.read.orc(sequence + "/sequence")

fastaDf = fastaDf.withColumn("sequence", trimSeq("sequence"))
#Get genes information
genes = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", "select gene.*, xref.display_label from gene left join xref on gene.display_xref_id=xref.xref_id")\
            .option("user", username)\
            .option("password", pwd)\
            .load()

@udf(returnType=StringType())
def describe(display_label, description):
    result = ""
    if(display_label != None):
      result += " gene_symbol:" + display_label
    if(description != None):
      result += " description: " + description
    return result        
genes = genes.withColumn("gene_description", describe("display_label", "description"))

@udf(returnType=StringType())
def seq_split(seq):
    line_length = 60
    result = ('\n').join((seq[i:i+line_length]) for i in range(0, len(seq), line_length))
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
#TODO: extract path to config option 
cdna_fasta = spark_session.read.orc(sequence + "/sequence_cdna")
pep_fasta = fastaDf

#Unite pep header
pep_fasta = pep_fasta.orderBy("seq_region_name", "tl_start")

pep_fasta = pep_fasta\
    .join(genes.drop("seq_region_strand").withColumnRenamed("version", "gene_version"), on=["gene_id"], how = "left")\
    .select(concat(lit(">"), col("translation_stable_id"), lit("."), col("tl_version"),\
       lit(" pep "), lit(csversion),\
       lit(":"), col("seq_region_name"),\
       lit(":"), least(col("tl_start"), col("tl_end")),\
       lit(":"), greatest(col("tl_start"), col("tl_end")),\
       lit(":"), col("seq_region_strand")).alias("info"),\
       col("sequence"), "stable_id", "transcript_stable_id","version", "gene_version", "biotype", "transcript_biotype", "gene_description")

@udf(returnType=StringType())
def append_info(info, gene_stable_id, transcript_stable_id, version, gene_version, biotype, transcript_biotype, gene_description):
        result = info
        if (gene_stable_id):
             result = result + " gene:" + gene_stable_id + "." + str(gene_version)
        if (transcript_stable_id):
             result = result + " transcript:" + transcript_stable_id + "." + str(version)
        if (biotype):
             result = result + " gene_biotype:" + biotype
        if (transcript_biotype):
             result = result + " transcript_biotype:" + transcript_biotype
        if (gene_description):
             result = result + gene_description
        return result

pep_fasta = pep_fasta.withColumn("info", append_info("info", "stable_id", "transcript_stable_id","version", "gene_version", "biotype", "transcript_biotype", "gene_description"))
pep_fasta = pep_fasta.select("info", "sequence")
pep_fasta = pep_fasta.withColumn("sequence", seq_split("sequence"))
#Write to fasta
pep_fasta.repartition(1)\
    .write\
    .mode('overwrite')\
    .option("header", False)\
    .option("escapeQuotes", False)\
    .option("quote", "$")\
    .option("delimiter", "\n")\
    .csv("./fasta_pep")
file = glob.glob("./fasta_pep" + "/part-0000*")[0]
f_cvs = open(file)
f = open("pep.fa", "a")
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

#Unite header
cdna_fasta = cdna_fasta\
    .join(genes.drop("seq_region_strand", "seq_region_start", "seq_region_end").withColumnRenamed("version", "gene_version"), on=["gene_id"])\
    .select(concat(lit(">"), col("transcript_stable_id"), lit("."), col("version"),\
       lit(" cdna "), lit(csversion),\
       lit(":"), col("seq_region_name"),\
       lit(":"), least(col("seq_region_start"), col("seq_region_end")),\
       lit(":"),  greatest(col("seq_region_start"), col("seq_region_end")),\
       lit(":"), col("seq_region_strand"),\
       lit("gene:"), col("stable_id"), lit("."), col("gene_version"),\
       lit(" gene_biotype:"), col("biotype"),\
       lit(" transcript_biotype:"), col("transcript_biotype"),\
       col("gene_description")),\
       col("sequence"))
cdna_fasta = cdna_fasta.withColumn("sequence", seq_split("sequence"))
#Write cdna to fasta
cdna_fasta.repartition(1)\
    .write\
    .mode('overwrite')\
    .option("header", False)\
    .option("escapeQuotes", False)\
    .option("quote", "$")\
    .option("quoteAll", False)\
    .option("delimiter", "\n")\
    .csv("./fasta_cdna")
file = glob.glob( "./fasta_cdna"  + "/part-0000*")[0]

f_cvs = open(file)
f = open("cdna.fa", "a")
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
    
    
