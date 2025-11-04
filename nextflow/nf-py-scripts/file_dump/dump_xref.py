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
parser.add_argument('--species', action="store", dest='species', default="")

args = parser.parse_args()
# Individual arguments can be accessed as attributes...
pwd = args.password
username = args.username
url = args.db
base_dir = args.base_dir
species = args.species
import os
confi=SparkConf()
confi.set("spark.executor.memory", "10g")
confi.set("spark.driver.memory", "15g")
confi.set("spark.cores.max", "1")
confi.set("spark.jars",  base_dir + "/ensembl-production/mysql-connector-j-8.1.0.jar")
confi.set("spark.driver.maxResultSize", "3G")
confi.set("spark.ui.showConsoleProgress", "false")
spark_session = SparkSession.builder.appName('ensembl.org').config(conf = confi).getOrCreate()
spark_session.sparkContext.setLogLevel("ERROR")


#Get genes information

gene_xref = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", """select
      g.stable_id as gene_stable_id,
      x.dbprimary_acc as xref_id,
      x.display_label as xref_label,
      coalesce(x.description, "") as description,
      e.db_display_name as db_name,
      x.info_type,
      coalesce(group_concat(e2.db_display_name, ":", x2.dbprimary_acc separator'; '), "") as source,
      coalesce(ix.ensembl_identity, "") as ensembl_identity,
      coalesce(ix.xref_identity, "") as xref_identity
    from
      gene g inner join
      object_xref ox on g.gene_id = ox.ensembl_id inner join
      xref x on ox.xref_id = x.xref_id inner join
      external_db e on x.external_db_id = e.external_db_id left outer join
      identity_xref ix on ox.object_xref_id = ix.object_xref_id left outer join
      dependent_xref dx on ox.object_xref_id = dx.object_xref_id left outer join
      xref x2 on dx.master_xref_id = x2.xref_id left outer join
      external_db e2 on x2.external_db_id = e2.external_db_id
    where
      ox.ensembl_object_type = "Gene" and
      e.db_display_name <> "GO" and
      g.seq_region_id in (select seq_region_id from seq_region sr join coord_system cs on sr.coord_system_id = cs.coord_system_id and cs.species_id = (select species_id from meta where meta_value=\"{species_name}\" and meta_key=\"organism.production_name\"))
    group by
      g.stable_id,
      x.dbprimary_acc,
      x.display_label,
      x.description,
      e.db_display_name,
      ix.ensembl_identity,
      ix.xref_identity""".format(species_name=species))\
            .option("user", username)\
            .option("password", pwd)\
            .load().withColumn("transcript_stable_id", lit("")).withColumn("protein_stable_id", lit(""))

transcript_xref = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", """
select
      g.stable_id as gene_stable_id,
      t.stable_id as transcript_stable_id,
      coalesce(tn.stable_id, "") as protein_stable_id,
      x.dbprimary_acc as xref_id,
      x.display_label as xref_label,
      coalesce(x.description, "") as description,
      e.db_display_name as db_name,
      x.info_type,
      coalesce(group_concat(e2.db_display_name, ":", x2.dbprimary_acc separator'; '), "") as source,
      coalesce(ix.ensembl_identity, "") as ensembl_identity,
      coalesce(ix.xref_identity, "") as xref_identity
    from
      gene g inner join
      transcript t using (gene_id) left outer join
      translation tn using (transcript_id) inner join
      object_xref ox on t.transcript_id = ox.ensembl_id inner join
      xref x on ox.xref_id = x.xref_id inner join
      external_db e on x.external_db_id = e.external_db_id left outer join
      identity_xref ix on ox.object_xref_id = ix.object_xref_id left outer join
      dependent_xref dx on ox.object_xref_id = dx.object_xref_id left outer join
      xref x2 on dx.master_xref_id = x2.xref_id left outer join
      external_db e2 on x2.external_db_id = e2.external_db_id
    where
      ox.ensembl_object_type = "Transcript" and
      e.db_display_name <> "GO" and
      g.seq_region_id in (select seq_region_id from seq_region sr join coord_system cs on sr.coord_system_id = cs.coord_system_id and cs.species_id = (select species_id from meta where meta_value=\"{species_name}\" and meta_key=\"organism.production_name\"))
    group by
      g.stable_id,
      t.stable_id,
      tn.stable_id,
      x.dbprimary_acc,
      x.display_label,
      x.description,
      e.db_display_name,
      ix.ensembl_identity,
      ix.xref_identity
""".format(species_name=species))\
            .option("user", username)\
            .option("password", pwd)\
            .load()


translation_xref = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", """
select
      g.stable_id as gene_stable_id,
      t.stable_id as transcript_stable_id,
      tn.stable_id as protein_stable_id,
      x.dbprimary_acc as xref_id,
      x.display_label as xref_label,
      coalesce(x.description, "") as description,
      e.db_display_name as db_name,
      x.info_type,
      coalesce(group_concat(e2.db_display_name, ":", x2.dbprimary_acc separator'; '), "") as source,
      coalesce(ix.ensembl_identity, "") as ensembl_identity,
      coalesce(ix.xref_identity, "") as xref_identity
    from
      gene g inner join
      transcript t using (gene_id) left outer join
      translation tn using (transcript_id) inner join
      object_xref ox on tn.translation_id = ox.ensembl_id inner join
      xref x on ox.xref_id = x.xref_id inner join
      external_db e on x.external_db_id = e.external_db_id left outer join
      identity_xref ix on ox.object_xref_id = ix.object_xref_id left outer join
      dependent_xref dx on ox.object_xref_id = dx.object_xref_id left outer join
      xref x2 on dx.master_xref_id = x2.xref_id left outer join
      external_db e2 on x2.external_db_id = e2.external_db_id
    where
      ox.ensembl_object_type = "Translation" and
      e.db_display_name <> "GO" and
      g.seq_region_id in (select seq_region_id from seq_region sr join coord_system cs on sr.coord_system_id = cs.coord_system_id and cs.species_id = (select species_id from meta where meta_value=\"{species_name}\" and meta_key=\"organism.production_name\"))
    group by
      g.stable_id,
      t.stable_id,
      tn.stable_id,
      x.dbprimary_acc,
      x.display_label,
      x.description,
      e.db_display_name,
      ix.ensembl_identity,
      ix.xref_identity
""".format(species_name=species))\
            .option("user", username)\
            .option("password", pwd)\
            .load()

go_xref = spark_session.read\
            .format("jdbc")\
            .option("driver", "com.mysql.cj.jdbc.Driver")\
            .option("url", url)\
            .option("query", """
select
      g.stable_id as gene_stable_id,
      t.stable_id as transcript_stable_id,
      coalesce(tn.stable_id, "") as protein_stable_id,
      x.dbprimary_acc as xref_id,
      x.display_label as xref_label,
      coalesce(x.description, "") as description,
      e.db_display_name as db_name,
      x.info_type,
      coalesce(group_concat(distinct replace(e2.db_display_name, " generic accession number (TrEMBL or SwissProt not differentiated)", ""), ":", x2.dbprimary_acc, ":", linkage_type separator "; "), "") as source
    from
      gene g inner join
      transcript t using (gene_id) left outer join
      translation tn using (transcript_id) inner join
      object_xref ox on t.transcript_id = ox.ensembl_id inner join
      xref x on ox.xref_id = x.xref_id inner join
      external_db e on x.external_db_id = e.external_db_id inner join
      ontology_xref ontx on ox.object_xref_id = ontx.object_xref_id inner join
      xref x2 on ontx.source_xref_id = x2.xref_id inner join
      external_db e2 on x2.external_db_id = e2.external_db_id
    where
      ox.ensembl_object_type = "Transcript" and
      e.db_display_name = "GO" and
      g.seq_region_id in (select seq_region_id from seq_region sr join coord_system cs on sr.coord_system_id = cs.coord_system_id and cs.species_id = (select species_id from meta where meta_value=\"{species_name}\" and meta_key=\"organism.production_name\"))
    group by
      g.stable_id,
      t.stable_id,
      tn.stable_id,
      x.dbprimary_acc,
      x.display_label,
      x.description,
      e.db_display_name
""".format(species_name=species))\
            .option("user", username)\
            .option("password", pwd)\
            .load()\
            .withColumn("ensembl_identity", lit(""))\
            .withColumn("xref_identity", lit(""))\

xref = gene_xref.unionByName(transcript_xref).unionByName(translation_xref).unionByName(go_xref)
xref = xref.select("gene_stable_id", "transcript_stable_id", "protein_stable_id", "xref_id",\
                    "xref_label", "description", "db_name", "info_type", "source", "ensembl_identity", "xref_identity")

#Write to fasta
xref.repartition(1)\
    .write\
    .mode('overwrite')\
    .option("header", True)\
    .option("delimiter", " \t")\
    .option("escapeQuotes", True)\
    .option("emptyValue", '')\
    .csv("./xref_csv")

file = glob.glob("./xref_csv" + "/part-0000*")[0]
shutil.copyfile(file, "xref.tsv")
