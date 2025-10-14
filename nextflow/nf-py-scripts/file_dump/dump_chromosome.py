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
import argparse
from sqlalchemy import text


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

try:
    os.remove("chromosome.tsv")
except OSError:
    pass

f_unmasked = open("chromosome.tsv", "a")

result = None
if (len(pwd) > 0):
    url = "mysql://" + username + ":" + pwd + "@" + url.split("//")[1]
else: 
    url = "mysql://" + username + "@" + url.split("//")[1]

engine = sqlalchemy.create_engine(url)

with engine.connect() as conn:
    query = text('select meta_value from meta where meta_key="assembly.level"')
    assembly_level = conn.execute(query)
    assembly_level = assembly_level.all()
    if(len(assembly_level) < 1):
        assembly_level = 'chromosome'
    else:
        for row in assembly_level:
            print(str(row.meta_value))
            assembly_level = str(row.meta_value)
    if (assembly_level == "chromosome"):
      query = text("select sr.* from seq_region sr join coord_system cs on cs.coord_system_id = sr.coord_system_id right join seq_region_attrib sa on sa.seq_region_id = sr.seq_region_id where cs.rank=1 and sa.attrib_type_id=367 order by sr.seq_region_id")
      regions = conn.execute(query)
      for region in regions:
        seq_id = str(region.name)
        seq_length = str(region.length)
        f_unmasked.write(seq_id + "\t" + seq_length + "\n")
f_unmasked.close()
