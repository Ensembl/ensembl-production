#!/usr/bin/env python
"""
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute

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
Generate Thoas Config file  
'''

import argparse
import logging
import json
import configparser 
import json

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)

def main():  
  parser = argparse.ArgumentParser(
       prog='generate_thoas_conf.py',
      description='Generate the thoas config file'
  )
  parser.add_argument('-i', '--genome_file', 
                      type=argparse.FileType('r', encoding='UTF-8'), 
                      required=True,
                      help='genome json file, ex: genome_info.json')
  parser.add_argument('-o', '--output', 
                      type=argparse.FileType('w', encoding='UTF-8'), 
                      required=True,
                      help='output filename, ex: load-108.conf')
  
  #general paths for thoas
  parser.add_argument( '--thoas_code_location'   ,  type=str, required=True)
  parser.add_argument( '--thoas_data_location'   ,  type=str, required=True)
  parser.add_argument( '--base_data_path'        ,  type=str, required=True)
  parser.add_argument( '--grch37_data_path'      ,  type=str, required=True)
  parser.add_argument( '--classifier_path'       ,  type=str, required=True)
  parser.add_argument( '--chr_checksums_path'    ,  type=str, required=True)
  parser.add_argument( '--xref_lod_mapping_file' ,  type=str, required=True)
  parser.add_argument( '--log_faulty_urls'       ,  required=False, action='store_true', default=False )
  parser.add_argument( '--release'               ,  type=str, required=True)
  
  #core db host
  parser.add_argument('--core_db_host'  ,  type=str, required=True)
  parser.add_argument('--core_db_port'  ,  type=str, required=True)
  parser.add_argument('--core_db_user'  ,  type=str, required=False,  default='ensro')

  #metadata info
  parser.add_argument('--metadata_db_host'  ,  type=str, required=True)
  parser.add_argument('--metadata_db_port'  ,  type=str, required=True)
  parser.add_argument('--metadata_db_user'  ,  type=str, required=False,  default='ensro')
  parser.add_argument('--metadata_db_dbname',  type=str, required=False,   default='ensembl_metadata_genome')
  parser.add_argument('--metadata_db_password',  type=str, required=False, default='')
  #taxonomy db
  parser.add_argument('--taxonomy_db_host'  ,  type=str, required=True)
  parser.add_argument('--taxonomy_db_port'  ,  type=str, required=True)
  parser.add_argument('--taxonomy_db_user'  ,  type=str, required=False, default='ensro')
  parser.add_argument('--taxonomy_db_dbname',  type=str, required=False, default='ncbi_taxonomy')
  parser.add_argument('--taxonomy_db_password',  type=str, required=False, default='')

  parser.add_argument('--mongo_db_host'      ,  type=str, required=True)
  parser.add_argument('--mongo_db_port'      ,  type=str, required=True)
  parser.add_argument('--mongo_db_dbname'    ,  type=str, required=True)
  parser.add_argument('--mongo_db_user'      ,  type=str, required=True)
  parser.add_argument('--mongo_db_password'  ,  type=str, required=True)
  parser.add_argument('--mongo_db_schema'    ,  type=str, required=True)
  parser.add_argument('--mongo_db_collection',  type=str, required=True)
      
  args = parser.parse_args()
  
  #default values
  genome_file         = args.genome_file
  output              = args.output
  genomes             = configparser.ConfigParser()  
      
  with genome_file as infile:       
    for line in infile:
      each_genome = json.loads(line)
      
      species = each_genome['species']
      division = each_genome['division'].lower().replace('ensembl','') 
      if each_genome['assembly_default'] == 'GRCh37':
        species='homo_sapiens_37'
                
      genomes[species] = {
        'production_name'  : species,
        'species_production': species,
        'ensembl_name'     : each_genome['ensembl_name'], 
        'assembly'         : each_genome['assembly_name'],
        'division'         : division,
        'database'         : each_genome['database_name'],
        'genome_uuid'      : each_genome['genome_uuid'],
        'host'             : args.core_db_host,
        'port'             : args.core_db_port,
        'user'             : args.core_db_user,
      }
    
      
    genomes['GENERAL'] = {
      'base_data_path'       : args.base_data_path,
      'grch37_data_path'     : args.grch37_data_path,
      'release'              : args.release,
      'classifier_path'      : args.classifier_path,
      'chr_checksums_path'   : args.chr_checksums_path,
      'xref_lod_mapping_file': args.xref_lod_mapping_file,
      'log_faulty_urls'      : args.log_faulty_urls,
    }

    genomes['METADATA DB'] = {
      'host'        : args.metadata_db_host,
      'port'        : args.metadata_db_port,
      'user'        : args.metadata_db_user,
      'database'    : args.metadata_db_dbname,
      'password'    : args.metadata_db_password,
      
    }
    
    genomes['TAXON DB'] = {
      'host'        : args.taxonomy_db_host,
      'port'        : args.taxonomy_db_port,
      'user'        : args.taxonomy_db_user,
      'database'    : args.taxonomy_db_dbname,
      'password'    : args.taxonomy_db_password,
    }        

    genomes['MONGO DB'] = {
      'host'        : args.mongo_db_host, 
      'port'        : args.mongo_db_port, 
      'user'        : args.mongo_db_user, 
      'password'    : args.mongo_db_password,
      'db'          : args.mongo_db_dbname,  
      'schema'      : args.mongo_db_schema,
      'collection'  : args.mongo_db_collection,
    }            

  #write config parser
  with args.output as configfile:
    genomes.write(configfile)
      
if __name__ == '__main__':
  main()
