#!/usr/bin/env python3

url =\
"jdbc:mysql://mysql-ens-core-prod-1:4524/mus_musculus_casteij_core_114_2"
username = "ensro"
pwd = ""

import sys
from pyspark import SparkConf
from pyspark.sql import SparkSession
from pyspark.sql.functions import lit, col, concat, length, udf
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
parser.add_argument('--dest', action="store", dest='dest', default="")
parser.add_argument('--base_dir', action="store", dest='base_dir', default="")

args = parser.parse_args()
# Individual arguments can be accessed as attributes...
pwd = args.password
username = args.username
url = args.db
dest = args.dest
base_dir = args.base_dir
out_subfolder = url.split("/")[3]

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
#need to create working dirs $output_dir, $timestamped_dir, $web_dir, $ftp_dir for each assembly (species) and data category
# we assume the following data categories for core fd:  
# 'GenomeDirectoryPaths','GenesetDirectoryPaths','RNASeqDirectoryPaths', 'HomologyDirectoryPaths'

# Assembly chain

# Genome fasta
fastaDf = transcript_service.translated_seq(url, username, pwd, None, True)

#Get genes information
genes = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", "select gene.*, xref.display_label from gene join xref on gene.display_xref_id=xref.xref_id")\
            .option("user", username)\
            .option("password", pwd)\
            .load()
@udf(returnType=StringType())
def describe(display_label, description):
    result = ""
    if(display_label != None):
      result += " gene_symbol:" + display_label
    if(description != None):
      result += " description:" + description
    return result        
genes = genes.withColumn("gene_description", describe("display_label", "description"))
            

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

cdna_fasta = fastaDf.filter(length(fastaDf.sequence) < 1)
pep_fasta = fastaDf.filter(length(fastaDf.sequence) > 1)
os.makedirs(os.path.dirname(dest + "/" + out_subfolder + "/"), exist_ok=True)

#Unite pep header
pep_fasta = pep_fasta\
    .join(genes.drop("seq_region_strand"), on=["gene_id"])\
    .select(concat(lit(">"), col("translation_stable_id"), lit(" "),\
       lit("pep"), lit(" "), lit(csversion),\
       lit(":"), col("seq_region_name"),\
       lit(":"), col("translation_region_start"),\
       lit(":"), col("translation_region_end"),\
       lit(":"), col("seq_region_strand"),\
       lit(" gene:"), col("stable_id"),\
       lit(" transcript:"), col("transcript_stable_id"),\
       lit(" gene_biotype:"), col("biotype"),\
       lit(" transcript_biotype:"), col("transcript_biotype"),\
       col("gene_description")),\
       col("sequence"))

#Write to fasta
pep_fasta.repartition(1)\
    .write\
    .mode('overwrite')\
    .option("header", False)\
    .option("delimiter", "\n")\
    .csv("./" + dest + "/fasta_pep")
file = glob.glob("./" + dest + "/fasta_pep" + "/part-0000*")[0]
shutil.copy(file, dest + "/" + out_subfolder + "/pep.fa")

#Unite header
cdna_fasta = cdna_fasta\
    .join(genes.drop("seq_region_strand", "seq_region_start", "seq_Region_End"), on=["gene_id"])\
    .select(concat(lit(">"), col("transcript_stable_id"), lit(" "),\
       lit("cds"), lit(" "), lit(csversion),\
       lit(":"), col("seq_region_name"),\
       lit(":"), col("seq_region_start"),\
       lit(":"), col("seq_region_end"),\
       lit(":"), col("seq_region_strand"),\
       lit("gene:"), col("stable_id"),\
       lit(" gene_biotype:"), col("biotype"),\
       lit(" transcript_biotype:"), col("transcript_biotype"),\
       col("gene_description")),\
       col("transcript_seq"))

#Write cdna to fasta
cdna_fasta.repartition(1)\
    .write\
    .mode('overwrite')\
    .option("header", False)\
    .option("delimiter", "\n")\
    .csv("./" + dest + "/fasta_cdna")
file = glob.glob("." + dest + "/fasta_cdna"  + "/part-0000*")[0]

shutil.copy(file, dest + "/" + out_subfolder + "/cdna.fa")
    
    
