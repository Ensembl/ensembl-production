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
import math
import glob
from datetime import datetime
from pyspark import SparkConf
from pyspark.sql import SparkSession
from ensembl.production.spark.core.TranscriptSparkService import TranscriptSparkService
from ensembl.production.spark.core.ExonSparkService import ExonSparkService
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
parser.add_argument('--top_level_seq', action="store", dest='top_sequence', default="")

args = parser.parse_args()
# Individual arguments can be accessed as attributes...
pwd = args.password
username = args.username
url = args.db
base_dir = args.base_dir
seq = args.sequence + "/sequence"
top_level_sequence = args.top_sequence

import os
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

transcript_service = TranscriptSparkService(spark_session)
exon_service = ExonSparkService(spark_session)

def lines_break(full, prefix):
    if (full is None):
        full = "ERROR"
    result = ""
    full = "\n"+ prefix + full
    full = full.split(" ")
    line = ""
    line_length = 83
    for word in full:
        word = word + " " 
        if((len(line) + len(word)) < line_length):
            line = line + word
        else:
            result = result + line
            line = "\n"+ prefix + word
    result = result + line[:-1]
    return result

@udf(returnType=StringType())
def split_intro(full, prefix):
    return lines_break(full, prefix)

#Split coordinates to lines
@udf(returnType=StringType())
def split_coordinates(coordinates):
    full = coordinates
    if (full is None):
        full = "ERROR"
    prefix = "FT                   "
    result = ""
    full = "\nFT   " + full
    full = full.split(",")
    line = ""
    line_length = 83
    for word in full:
        word = word + ","
        if((len(line) + len(word)) < line_length):
            line = line + word
        else:
            result = result + line
            line = "\n"+ prefix + word
    result = result + line[:-1]
    return result

#Is transcript canonical
@udf(returnType=StringType())
def gene_desc(locus_tag, desc):
    result = ""
    if (locus_tag):
        result = result + "FT                   /locus_tag=\"" + locus_tag + "\""
    if(desc):
        desc = "/note=\""  + desc + "\""
        result = result + lines_break(desc, "FT                   ")
    return result

@udf(returnType=StringType())
def join_coord(coordinates):
    if (coordinates.find(",") < 0):
        return coordinates
    else:
        return "join(" + coordinates + ")"

@udf(returnType=StringType())
def xref_note(xref, prefix=None): 
    result = ""
    if (xref is None):
        return ""
    if (prefix is None):
        for xref_id in xref.split(";"):
            result = result + "\nFT                   /db_xref=\"" + xref_id + "\""
    else:
        for xref_id in xref.split(";"):
            result = result + "\nFT                   /db_xref=\"" + prefix + xref_id + "\""
        
    return result

#Split coordinates to lines
@udf(returnType=StringType())
def split_sequence(seq):
    seq = seq.replace("!", "")
    seq = seq.replace("*", "")
    seq = "/translation=\"" + seq + "\""
    length = 59
    result =  "\nFT                   " + ('\nFT                   ').join((seq[i:i+length]) for i in range(0, len(seq), length))
    return result

@udf(returnType=StringType())
def split_region_sequence(seq):
    #This split must be kept exactly like this, not in for loop or whatever - only this function, that is python wrapper of c++
    # give adequate performance. Other options kill perfomants immediatly.
    block_length = 10
    line_length = 66
    result = ' '.join(seq[i:i+block_length] for i in range(0, len(seq), block_length))
    length = len(result)
    len_seq = len(seq)
    lines = (length//line_length)*line_length
    remain_length = length%line_length
    remain = result[-remain_length:]

    result = "    " + ('\n    ').join((result[i:i+line_length]  + "   " + str(((i+line_length)//11)*block_length))\
                                       for i in range(0, lines, line_length))\
                                     +"\n    " + remain + (' '*(69-remain_length)) + str(len_seq) + "\n//"
    return result

@udf(returnType=StringType())
def seq_stats(seq):
    result = ""
    int_a = seq.count("A")
    int_c = seq.count("C")
    int_t = seq.count("T")
    int_g = seq.count("G")
    int_total = len(seq)
    total = "   " + str(int_total) + "  BP;"
    a = "   " + str(int_a) + " A;"
    c = "   " + str(int_c) + " C;"
    g = "   " + str(int_g) + " G;"
    t = "   " + str(int_t) + " T;"
    other = "       " + str(int_total - (int_a + int_t + int_c + int_g)) + " other;"

    result = "\nSQ   Sequence" + total + a + c + g + t + other
    return  result

dna = spark_session.read.orc(top_level_sequence)

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

exons = exon_service.load_exons_fs(url, username, pwd, "exons")

region = spark_session.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", url)\
                .option("query","select seq_region.seq_region_id, seq_region.name as sr_name, seq_region.length, coord_system.* from seq_region join coord_system on seq_region.coord_system_id = coord_system.coord_system_id")\
                .option("user", username)\
                .option("password", pwd)\
                .load()
dna = dna.join(region, on = ["seq_region_id"], how = "left")
taxonomy_id = spark_session.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", url)\
                .option("query","select meta_value from meta where meta_key=\"species.taxonomy_id\"")\
                .option("user", username)\
                .option("password", pwd)\
                .load().first()[0]
scientific_name = spark_session.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", url)\
                .option("query","select meta_value from meta where meta_key=\"species.scientific_name\"")\
                .option("user", username)\
                .option("password", pwd)\
                .load().first()[0]

common_name = spark_session.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", url)\
                .option("query","select meta_value from meta where meta_key=\"species.common_name\"")\
                .option("user", username)\
                .option("password", pwd)\
                .load().first()[0]

classification = spark_session.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", url)\
                .option("query","select distinct group_concat(meta_value order by meta_id desc separator '; ') from meta where meta_key=\"species.classification\" order by meta_id desc")\
                .option("user", username)\
                .option("password", pwd)\
                .load().first()[0]

classification = classification[:classification.rfind(";")] + "."
#If performance boost needed - sorting can be romeved here, to spedd up twice
gene_xref = spark_session.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", url)\
                .option("query","select group_concat(x.dbprimary_acc  order by x.dbprimary_acc separator \";\") as gene_xref, ox.ensembl_id from object_xref ox join xref x on x.xref_id=ox.xref_id where ox.ensembl_object_type=\"Gene\" group by ox.ensembl_id")\
                .option("user", username)\
                .option("password", pwd)\
                .load()
genes = genes.join(gene_xref, on = [genes.gene_id == gene_xref.ensembl_id], how = "left_outer")

transcript_xref = spark_session.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", url)\
                .option("query","select group_concat(x.dbprimary_acc order by x.dbprimary_acc separator \";\" ) as xref, ox.ensembl_id from object_xref ox join xref x on x.xref_id=ox.xref_id where ox.ensembl_object_type=\"Transcript\" group by ox.ensembl_id")\
                .option("user", username)\
                .option("password", pwd)\
                .load()
transcripts = transcripts.join(transcript_xref, on = [transcripts.transcript_id == transcript_xref.ensembl_id], how = "left_outer")

translation_xref = spark_session.read\
                .format("jdbc")\
                .option("driver","com.mysql.cj.jdbc.Driver")\
                .option("url", url)\
                .option("query","select group_concat(x.dbprimary_acc separator \";\") as translation_xref, ox.ensembl_id from object_xref ox join xref x on x.xref_id=ox.xref_id where ox.ensembl_object_type=\"Translation\" group by ox.ensembl_id")\
                .option("user", username)\
                .option("password", pwd)\
                .load()

mRNA=exons.withColumnRenamed("stable_id", "exon_stable_id") 

mRNA_pos = mRNA.filter("seq_region_strand>0").withColumn("coordinates", concat("seq_region_start", lit(".."), "seq_region_end"))\
    .drop("seq_region_start", "seq_region_end")
mRNA_neg = mRNA.filter("seq_region_strand<0").withColumn("coordinates", concat(lit("complement("), "seq_region_start", lit(".."), "seq_region_end", lit(")")))\
    .drop("seq_region_start", "seq_region_end")
mRNA = mRNA_neg.unionByName(mRNA_pos)
mRNA = mRNA.join(transcripts.withColumnRenamed("stable_id", "transcript_stable_id").withColumnRenamed("version", "transcript_version")\
                 .select("transcript_stable_id", "gene_id", "transcript_version", "transcript_id", "seq_region_start", "seq_region_end", "biotype", "xref"), on = ["transcript_id"])

mRNA =\
        mRNA.groupBy("transcript_stable_id", "transcript_version", "gene_id", "seq_region_start", "seq_region_end", "biotype", "xref")\
        .agg(concat_ws(",", expr("""transform(sort_array(collect_list(struct(rank,coordinates)),True), x -> x.coordinates)"""))\
        .alias("coordinates"))\
        .drop("created_date", "modified_date", "stable_id")

mRNA =\
    mRNA.withColumn("coordinates", join_coord("coordinates"))

mRNA = mRNA.join(genes.withColumnRenamed("stable_id", "gene_stable_id").withColumnRenamed("version", "gene_version").select("gene_id", "gene_stable_id", "gene_version", "seq_region_id"), on=["gene_id"])

mRNA = mRNA.withColumn("gene_id_note", concat(lit("FT                   /gene=\""), "gene_stable_id", lit("."), "gene_version",lit("\"")))

mRNA = mRNA.withColumn("feature_id", concat(lit("FT                   /standard_name=\""), "transcript_stable_id", lit("."), "transcript_version",lit("\"")))

miscRNA = mRNA.filter((mRNA.biotype != "protein_coding") & (mRNA.biotype!="IG_V_gene") & (mRNA.biotype!="IG_C_gene")& (mRNA.biotype!="IG_J_gene") & (mRNA.biotype!="TR_V_gene")  )  
mRNA = mRNA.filter((mRNA.biotype == "protein_coding") | (mRNA.biotype=="IG_V_gene") | (mRNA.biotype=="IG_C_gene") | (mRNA.biotype=="IG_J_gene") | (mRNA.biotype=="TR_V_gene"))

mRNA = mRNA.withColumn("coordinates", concat(lit("mRNA            "), "coordinates"))
mRNA = mRNA.withColumn("coordinates", split_coordinates("coordinates"))

miscRNA = miscRNA.withColumn("coordinates", concat(lit("misc_RNA        "), "coordinates"))
miscRNA = miscRNA.withColumn("coordinates", split_coordinates("coordinates"))

miscRNA = miscRNA.withColumn("feature_id",  xref_note("xref", lit("RNAcentral:")))
miscRNA = miscRNA.withColumn("feature_id", concat("feature_id", lit("\nFT                   /note=\""), "biotype", lit("\"")))
miscRNA = miscRNA.withColumn("feature_id", concat("feature_id", lit("\nFT                   /standard_name=\""), "transcript_stable_id", lit("."), "transcript_version",lit("\"")))

gene_pos = genes.filter("seq_region_strand > 0").withColumn("coordinates", concat(lit("FT   gene            "), "seq_region_start", lit(".."), "seq_region_end"))
gene_neg = genes.filter("seq_region_strand < 0").withColumn("coordinates", concat(lit("FT   gene            complement("), "seq_region_start", lit(".."), "seq_region_end", lit(")")))
gene = gene_pos.unionByName(gene_neg)
gene = gene.withColumn("gene_id_note", concat(lit("FT                   /gene="), "stable_id", lit("."), "version"))
gene = gene.withColumn("feature_id", gene_desc("locus_tag", "description"))

sequence = spark_session.read.orc(seq)
cds = transcript_service.translatable_exons(url, username, pwd, None, None, False)
cds_pos = cds.filter("seq_region_strand>0").withColumn("coordinates", concat("seq_region_start", lit(".."), "seq_region_end"))
cds_neg = cds.filter("seq_region_strand<0").withColumn("coordinates", concat(lit("complement("), "seq_region_start", lit(".."), "seq_region_end", lit(")")))
cds = cds_neg.unionByName(cds_pos)
cds =\
        cds.groupBy("transcript_stable_id", "version", "gene_id")\
        .agg(concat_ws(",", expr("""transform(sort_array(collect_list(struct(rank,coordinates)),True), x -> x.coordinates)"""))\
        .alias("coordinates"))\
        .drop("created_date", "modified_date", "stable_id")

cds =\
    cds.withColumn("coordinates", join_coord("coordinates"))

cds = cds.withColumn("coordinates", concat(lit("CDS             "), "coordinates"))
cds = cds.withColumn("coordinates", split_coordinates("coordinates"))
cds = cds.join(genes.withColumnRenamed("stable_id", "gene_stable_id").withColumnRenamed("version", "gene_version").select("gene_id", "gene_stable_id", "gene_version"), on=["gene_id"])

cds = cds.withColumn("gene_id_note", concat(lit("FT                   /gene=\""), "gene_stable_id", lit("."), "gene_version",lit("\"")))
cds = cds.join(transcripts.withColumnRenamed("stable_id", "transcript_stable_id").select("transcript_stable_id", "seq_region_start", "seq_region_end", "xref"), on = ["transcript_stable_id"] )
cds = cds.drop("version").join(sequence.drop("gene_id"), on = ["transcript_stable_id"])
cds_codon = cds.filter("codon_table>1").withColumn("gene_id_note", concat(lit("FT                   /transl_table="), "codon_table", lit("\n"), "gene_id_note"))
cds_non_codon = cds.filter("codon_table=1").withColumn("gene_id_note", cds.gene_id_note)
cds = cds_non_codon.union(cds_codon)
cds = cds.join(translation_xref, on=[cds.canonical_translation_id==translation_xref.ensembl_id], how = "left_outer")
cds = cds.withColumn("feature_id", concat(lit("FT                   /protein_id=\""), "translation_stable_id", lit("."), "tl_version", lit("\"")))
cds = cds.withColumn("feature_id", concat("feature_id", lit("\nFT                   /note=\"transcript_id="), "transcript_stable_id", lit("."), "version", lit("\"")))
cds = cds.withColumn("xref_tmp", xref_note("xref"))
cds = cds.withColumn("feature_id", concat("feature_id", "xref_tmp", lit(""))).drop("xref_tmp")
cds = cds.withColumn("xref_tmp", xref_note("translation_xref", lit("UniParc:")))
cds = cds.withColumn("feature_id", concat("feature_id", "xref_tmp", lit(""))).drop("xref_tmp")

cds = cds.withColumn("sequence", split_sequence("sequence"))
cds = cds.withColumn("feature_id", concat("feature_id", "sequence"))
#About wierd column names: we must have some column names to maintain the union order, but there are very different features and impossible
# to put names with correct meaning, so names of the columns are inherited from major features and spread for other features
exon = exons.join(transcripts.withColumnRenamed("stable_id", "transcript_stable_id").select("transcript_id", "transcript_stable_id", "gene_id"), on = ["transcript_id"])\
    .join(genes.withColumnRenamed("stable_id", "gene_stable_id").select("gene_id", "gene_stable_id"), on = ["gene_id"]).dropDuplicates(["stable_id"])

exon_pos = exon.filter("seq_region_strand > 0").withColumn("coordinates", concat(lit("FT   exon            "), "seq_region_start", lit(".."), "seq_region_end"))
exon_neg = exon.filter("seq_region_strand < 0").withColumn("coordinates", concat(lit("FT   exon            "),lit("complement("), "seq_region_start", lit(".."), "seq_region_end", lit(")")))
exon = exon_neg.unionByName(exon_pos)
exon = exon.withColumn("gene_id_note", concat(lit("FT                   /note=\"exon_id="), "stable_id", lit("."), "version", lit("\"")))
exon = exon.withColumn("feature_id", lit(""))

intro = region.withColumn("coordinates", concat(lit("ID   "), "sr_name", lit("    standard; DNA; HTG; "), "length", lit(" BP.\nXX\n")))
intro = intro.withColumn("gene_id_note", concat(lit("AC   "), "name", lit(":"), "version", lit(":"), "sr_name", lit(":"), lit("1"), lit(":"), "length", lit(":"), "rank"))
intro = intro.withColumn("gene_id_note", concat("gene_id_note", lit("\nXX\nSV   "), "sr_name", lit("."), "version"))
intro = intro.withColumn("gene_id_note", concat("gene_id_note", lit("\nXX\nDT   "), lit(datetime.today().strftime('%d-%b-%Y')), lit("\nXX")))
intro = intro.withColumn("tmp_note", concat(lit(scientific_name + " "), "name", lit(" "), "sr_name",lit(" "), "version", lit("full sequence 1.."), "length", lit(" annotated by Ensembl")))
intro = intro.withColumn("gene_id_note", concat("gene_id_note", split_intro("tmp_note", lit("DE   ")))).drop("tmp_note")
intro = intro.withColumn("gene_id_note", concat("gene_id_note", lit("\nXX\nKW   .\nXX"), lit("\nOS   "), lit(scientific_name + " (" + common_name + ")")))
intro = intro.withColumn("gene_id_note", concat("gene_id_note", lit(lines_break(classification, "OC   "))))
intro = intro.withColumn("feature_id", concat(lit("XX\nCC   This sequence was annotated by Ensembl (www.ensembl.org). Please visit the\nCC   Ensembl or EnsemblGenomes web site, http://www.ensembl.org/ or\nCC   http://www.ensemblgenomes.org/ for more information.\nXX\nCC   All feature locations are relative to the first (5') base of the sequence\nCC   in this file.  The sequence presented is always the forward strand of the\nCC   assembly. Features that lie outside of the sequence contained in this file\nCC   have clonal location coordinates in the format: <clone\nCC   accession>.<version>:<start>..<end>\nXX\nCC   The /gene indicates a unique id for a gene, /note=\"transcript_id=...\" a\nCC   unique id for a transcript, /protein_id a unique id for a peptide and\nCC   note=\"exon_id=...\" a unique id for an exon. These ids are maintained\nCC   wherever possible between versions.\nXX\nCC   All the exons and transcripts in Ensembl are confirmed by similarity to\nCC   either protein or cDNA sequences.\nXX"), lit("")))
intro = intro.withColumn("gene_id", lit(1)).withColumn("seq_region_start", lit(1)).withColumn("seq_region_end", lit(2))

region = region.withColumn("coordinates", concat(lit("FH   Key             Location/Qualifiers\nFT   source          1.."), "length"))
region = region.withColumn("gene_id_note", concat(lit("FT                   /organism=\""), lit(scientific_name), lit("\"")))
region = region.withColumn("feature_id", concat(lit("FT                   /db_xref=\"taxon:"), lit(taxonomy_id), lit("\"")))
region = region.withColumn("gene_id", lit(1)).withColumn("seq_region_start", lit(1)).withColumn("seq_region_end", lit(2))

sequence = dna.withColumn("coordinates", concat(lit("FT   misc_feature    1.."), "length"))
sequence = sequence.withColumn("gene_id_note", concat(lit("FT                   /note=\"contig "), "name", lit(" 1.."),  "length", lit("(1)\"")))
sequence = sequence.withColumn("feature_id", split_region_sequence("sequence"))
sequence = sequence.withColumn("feature_id", concat(lit("\nXX"), seq_stats("sequence"), lit("\n"), "feature_id"))

sequence = sequence.withColumn("seq_region_start", lit(1)).withColumn("seq_region_end", lit(2)).withColumn("transcript_stable_id", lit("1"))
#Transcripts stable id and gene_id serve to maintain entries order in file
exon = exon.select("seq_region_id", "coordinates", "gene_id_note", "feature_id", "transcript_stable_id", "seq_region_start", "seq_region_end").withColumn("gene_id", lit(99999)).dropDuplicates(["gene_id_note"])

mRNA = mRNA.select("seq_region_id","coordinates", "gene_id_note", "feature_id", "gene_id", "seq_region_start", "seq_region_end", "transcript_stable_id")
miscRNA = miscRNA.select("seq_region_id","coordinates", "gene_id_note", "feature_id", "gene_id", "seq_region_start", "seq_region_end", "transcript_stable_id")
gene = gene.select("seq_region_id", "coordinates", "gene_id_note", "feature_id", "gene_id", "seq_region_start", "seq_region_end").withColumn("transcript_stable_id", lit("3"))
region = region.select("seq_region_id", "coordinates", "gene_id_note", "feature_id", "gene_id", "seq_region_start", "seq_region_end").withColumn("transcript_stable_id", lit("2"))
intro = intro.select("seq_region_id", "coordinates", "gene_id_note", "feature_id", "gene_id", "seq_region_start", "seq_region_end").withColumn("transcript_stable_id", lit("1"))
cds = cds.select("seq_region_id", "coordinates", "gene_id_note", "feature_id", "gene_id", "seq_region_start", "seq_region_end", "transcript_stable_id")
sequence = sequence.select("seq_region_id", "coordinates", "gene_id_note", "feature_id", "transcript_stable_id", "seq_region_start", "seq_region_end").withColumn("gene_id", lit(9999999))
result = gene.unionByName(region).unionByName(mRNA).unionByName(miscRNA).unionByName(cds).unionByName(exon).unionByName(intro).unionByName(sequence)

file_path = "./test.embl"
tmp_fp = "_embl"

result.repartition(1).orderBy("seq_region_id", "gene_id", "transcript_stable_id", "seq_region_start", desc("seq_region_end"))\
    .drop("transcript_stable_id", "gene_id", "seq_region_start", "seq_region_end", "seq_region_id")\
    .write\
    .option("header", False).mode('overwrite').option("quote", "$").option("emptyValue", '')\
    .option("delimiter", "\n").csv(tmp_fp + "_features")
             
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
    if(len(file_line) < 2):
        file_line = f_cvs.readline()
        continue
    if(file_line[0:1] == "$"):
        file_line = file_line[1:]
    if(file_line[-2:-1] == "$"):
        file_line = file_line[:-2] + "\n"
    f.write(file_line)

    file_line = f_cvs.readline()
f_cvs.close()
f.close()