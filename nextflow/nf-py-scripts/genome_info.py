#!/usr/bin/env python
"""
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

'''
Fetch Genome Info from the new metadata api  
'''

import argparse
import logging
import sys
import json
import configparser 
from os import getenv
from os.path import isdir
from os.path import join, isfile, realpath
from ensembl.production.metadata.api.genome import GenomeAdaptor

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)

def main():  
  parser = argparse.ArgumentParser(
       prog='genome_info.py',
      description='Fetch Ensembl genome info from new metadata API'
  )
  parser.add_argument('-g', '--genome_uuid', type=str, nargs='*', required=False, default=None, help='genome UUID, ex: a23663571,b236571')
  parser.add_argument('-s', '--species',     type=str, nargs='*', required=False, default=None, help='Ensembl species names, ex: homo_sapiens,mus_musculus')
  parser.add_argument('-d', '--organism_group', type=str, nargs='*', required=False, default=None, help='versioned file name, ex: EnsemblVertbrates,EnsemblPlants')
  parser.add_argument('-p', '--organism_group_type', type=str, nargs='*', required=False, default=None, help='organism group type, ex: Division')
  parser.add_argument('-u', '--allow_unreleased_genomes', help='Fetch only unreleased genome ', action='store_true')
  parser.add_argument('-e', '--allow_unreleased_datasets', help='Fetch only unreleased datasets', action='store_true')
  parser.add_argument('-n', '--dataset_name', type=str, nargs='*', required=False, default=None, help='ensembl dataset type to fetch unique genomes, ex: assembly, genebuild')
  parser.add_argument('-r', '--dataset_source', type=str, nargs='*', required=False, default=None, help='ensembl dataset source, ex: homo_sapiens_core_111_38')
  parser.add_argument('-m', '--metadata_db_uri', type=str, required=True,  help='metadata db mysql uri, ex: mysql://ensro@localhost:3366/ensembl_genome_metadata')
  parser.add_argument('-t', '--taxonomy_db_uri', type=str, required=True,  help='taxonomy db mysql uri, ex: mysql://ensro@localhost:3366/ncbi_taxonomy')
  parser.add_argument('-o', '--output', type=str, required=True,  help='output file ex: genome_info.json')
  
  args = parser.parse_args()
  
  
  #default values
  genome_uuid         = args.genome_uuid
  species             = args.species
  organism_group      = args.organism_group
  organism_group_type = args.organism_group_type
  dataset_name        = args.dataset_name
  dataset_source      = args.dataset_source
  
  
  #required values
  allow_unreleased_genomes   = args.allow_unreleased_genomes
  allow_unreleased_datasets  = args.allow_unreleased_datasets
  metadata_db_uri      = args.metadata_db_uri
  taxonomy_db_uri      = args.taxonomy_db_uri
  output_file_name     = args.output
  
  genome_info_obj = GenomeAdaptor(metadata_uri=metadata_db_uri, taxonomy_uri=taxonomy_db_uri)    
  with open(output_file_name, 'w') as json_output:       
    for genome in genome_info_obj.fetch_genomes_info(genome_uuid=genome_uuid,
                                                     ensembl_name=species,
                                                     group=organism_group,
                                                     group_type=organism_group_type,
                                                     dataset_name=dataset_name,
                                                     dataset_source=dataset_source,
                                                     allow_unreleased_genomes=allow_unreleased_genomes,
                                                     allow_unreleased_datasets=allow_unreleased_datasets) or []:
      
      genome_info = {
                      "genome_uuid"          : genome[0]['genome'][0].genome_uuid,
                      "species"              : genome[0]['genome'][1].ensembl_name,
                      "assembly"             : genome[0]['genome'][2].assembly_default,
                      "assembly_name"        : genome[0]['genome'][2].ensembl_name,
                      "assembly_accession"   : genome[0]['genome'][2].accession,
                      "assembly_level"       : genome[0]['genome'][2].level,
                      "division"             : genome[0]['genome'][-2].name,
                      "database"             : genome[0]['datasets'][-1][-1].name,
                      "database_type"        : genome[0]['datasets'][-1][-1].type
      }
      json.dump(genome_info, json_output)
      json_output.write("\n")
      
if __name__ == '__main__':
  main()
