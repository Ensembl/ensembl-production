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
#need to create working dirs $output_dir, $timestamped_dir, $web_dir, $ftp_dir for each assembly (species) and data category
# we assume the following data categories for core fd:  
# 'GenomeDirectoryPaths','GenesetDirectoryPaths','RNASeqDirectoryPaths', 'HomologyDirectoryPaths'

try:
    os.remove("unmasked.fa")
except OSError:
    pass

try:
    os.remove("softmasked.fa")
except OSError:
    pass

try:
    os.remove("hardmasked.fa")
except OSError:
    pass

f_unmasked = open("unmasked.fa", "a")
f_smasked = open("softmasked.fa", "a")
f_hmasked = open("hardmasked.fa", "a")

result = None
if (len(pwd) > 0):
    url = "mysql://" + username + ":" + pwd + "@" + url.split("//")[1]
else: 
    url = "mysql://" + username + "@" + url.split("//")[1]

engine = sqlalchemy.create_engine(url)

with engine.connect() as conn:
    query = text("select * from seq_region sr join coord_system cs on cs.coord_system_id = sr.coord_system_id where cs.rank=1")
    regions = conn.execute(query)
    result = ""
    for region in regions:
        seq_id = str(region.seq_region_id)
        results = ""
        try:
            f = open(sequence + "/" + seq_id + ".txt", "r")
            sequence_str = f.read()
            f.close()
        except OSError:
            pass             
        if(len(sequence_str) == 0):
            print(seq_id)
            print(sequence + "/" + seq_id + ".txt")
            continue

        info = ">" + seq_id + "\n"
        f_unmasked.write(info)
        f_hmasked.write(info)
        f_smasked.write(info)
        sequence_str = ('\n').join((sequence_str[i:i+60]) for i in range(0, len(sequence_str), 60)) + "\n"
        f_unmasked.write(sequence_str)
        

f_unmasked.close()
f_smasked.close()
f_hmasked.close()