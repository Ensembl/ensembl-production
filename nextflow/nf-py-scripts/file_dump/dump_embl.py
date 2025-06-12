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
from pyspark.sql.functions import concat, concat_ws, lit, expr, udf, regexp_replace, desc
from pyspark.sql.types import BooleanType, StringType, IntegerType
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
seq = args.sequence

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
mRNA_neg = mRNA.filter("seq_region_strand<0").withColumn("coordinates", concat(lit("complement("), "seq_region_start", lit(".."), "seq_region_end", lit(")")))
mRNA = mRNA_neg.unionByName(mRNA_pos)

mRNA =\
        mRNA.groupBy("transcript_stable_id", "version", "gene_id")\
        .agg(concat_ws(",", expr("""transform(sort_array(collect_list(struct(rank,coordinates)),True), x -> x.coordinates)"""))\
        .alias("coordinates"))\
        .drop("created_date", "modified_date", "stable_id")

#Is transcript canonical
@udf(returnType=StringType())
def gene_desc(locus_tag, desc):
    result = ""
    if (locus_tag):
        result = result + "FT                   /locus_tag=" + locus_tag
    if(desc):
        result = result + "\nFT                   /note=" + desc
    return result

#Is transcript canonical
@udf(returnType=BooleanType())
def is_single(coordinates):
    return coordinates.find(",") < 0

#Split coordinates to lines
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

#Split coordinates to lines
@udf(returnType=StringType())
def splitSequence(seq):
    seq = seq.replace("!", "")
    seq = seq.replace("*", "")
    result = seq[:45]
    i = 45
    while(i < len(seq)):
        result = result + "\nFT                   " + seq[i:i+59]
        i = i + 59
    return result

genes = spark_session.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", url)\
                .option("query","select g.*, x.display_label as locus_tag, x.description as note from gene g left join object_xref ox on g.gene_id = ox.ensembl_id\
                     and ox.ensembl_object_type=\"Gene\" \
                    left join xref x on x.xref_id = ox.xref_id")\
                .option("user", username)\
                .option("password", pwd)\
                .load()
transcripts = spark_session.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", url)\
                .option("query","select * from transcript")\
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

mRNA = mRNA.withColumn("gene_id_note", concat(lit("FT                   /gene=\""), "gene_stable_id", lit("."), "gene_version",lit("\"")))
mRNA = mRNA.join(transcripts.withColumnRenamed("stable_id", "transcript_stable_id").select("transcript_stable_id", "seq_region_start", "seq_region_end"), on = ["transcript_Stable_id"] )
cds = mRNA
mRNA = mRNA.withColumn("feature_id", concat(lit("FT                   /standard_name=\""), "transcript_stable_id", lit("."), "version",lit("\"")))

gene_pos = genes.filter("seq_region_strand > 0").withColumn("coordinates", concat(lit("FT   gene            "), "seq_region_start", lit(".."), "seq_region_end"))
gene_neg = genes.filter("seq_region_strand < 0").withColumn("coordinates", concat(lit("FT   gene            compliment("), "seq_region_start", lit(".."), "seq_region_end", lit(")")))
gene = gene_pos.unionByName(gene_neg)
gene = gene.withColumn("gene_id_note", concat(lit("FT                   /gene="), "stable_id", lit("."), "version"))
gene = gene.withColumn("feature_id", gene_desc("locus_tag", "description"))

sequence = spark_session.read.orc(seq)
cds = cds.drop("version").join(sequence.drop("gene_id"), on = ["transcript_stable_id"])
cds_codon = cds.filter("codon_table>1").withColumn("gene_id_note", concat(lit("FT                   /transl_table="), "codon_table", lit("\n"), "gene_id_note"))
cds_codon.show()
cds_non_codon = cds.filter("codon_table=1").withColumn("gene_id_note", cds.gene_id_note)
cds = cds_non_codon.union(cds_codon)
cds = cds.withColumn("coordinates", regexp_replace(cds.coordinates, "mRNA", "CDS "))
cds = cds.withColumn("feature_id", concat(lit("FT                   /protein_id=\""), "translation_stable_id", lit("."), "tl_version", lit("\"")))
cds = cds.withColumn("sequence", splitSequence("sequence"))
cds = cds.withColumn("feature_id", concat("feature_id", lit("\nFT                   /translation=\""), "sequence", lit("\"")))
mRNA = mRNA.select("coordinates", "gene_id_note", "feature_id", "gene_id", "seq_region_start", "seq_region_end")
gene = gene.select("coordinates", "gene_id_note", "feature_id", "gene_id", "seq_region_start", "seq_region_end")
cds = cds.select("coordinates", "gene_id_note", "feature_id", "gene_id", "seq_region_start", "seq_region_end")
result = gene.unionByName(mRNA).unionByName(cds)

file_path = "./test.embl"
tmp_fp = "_embl"

result.repartition(1).orderBy("gene_id", "seq_region_start", desc("seq_region_end")).drop("gene_id", "seq_region_start", "seq_region_end").write.option("header", False).mode('overwrite').option("quote", "").option("delimiter", "\n").csv(tmp_fp + "_features")
             
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
        if (len(file_line) < 5):
            file_line = f_cvs.readline()
            continue
        f.write(file_line)
        file_line = f_cvs.readline()

f_cvs.close()
f.close()