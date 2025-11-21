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

from ensembl.production.spark.fileio.FtpService import get_dataset_path
import argparse

# Define the parser
parser = argparse.ArgumentParser(description='Fasta files dump')
parser.add_argument('--password', action="store", dest='password', default="")
parser.add_argument('--username', action="store", dest='username', default="ensro")
parser.add_argument('--db', action="store", dest='db', default="")
parser.add_argument('--species', action="store", dest='species', default="")

args = parser.parse_args()
# Individual arguments can be accessed as attributes...
pwd = args.password
username = args.username
url = args.db
species = args.species
print(get_dataset_path(url, username, pwd, species), end="")

