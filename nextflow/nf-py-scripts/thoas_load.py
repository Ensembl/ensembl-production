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
Generate Thoas Config file  
'''

import argparse
import logging
import sys
import json
import configparser 
import json
import os 
from datetime import datetime
import subprocess

from ensembl.create_collection_schema import create_collection_and_schema
from ensembl.util.mongo import MongoDbClient
from ensembl.load_metadata import load_metadata
from ensembl.util.utils import load_config

def main():  
  ARG_PARSER = argparse.ArgumentParser(
       prog='thoas_load.py',
      description='Load genome information into thoas collection'
  )  
  ARG_PARSER.add_argument('-i', '--config', 
                      required=True,
                      help='config file, ex: load_config.json')
  
  ARG_PARSER.add_argument('-c', '--code_path', 
                      required=True,
                      help='thoash genome loading  scripts path')
  
  ARG_PARSER.add_argument('-l', '--load_metadata',  
                      action='store_true',
                      help='Create Mongo Collection declared in config file')
  
  ARG_PARSER.add_argument('-a', '--load_species',  
                      action='store_true',
                      help='Flag to load species genome features')
  
  ARG_PARSER.add_argument('-s', '--species_name', 
                      required=False,
                      help='thoash genome loading  scripts path')
  
  ARG_PARSER.add_argument('-e', '--extract_genomic_features', help='Extract genomic features from core db ', 
                          default=False,
                          action='store_true')
  
  ARG_PARSER.add_argument('-t', '--extract_genomic_features_type', metavar='N', type=str, nargs='+', choices=['cds','genes', 'proteins'],
                         help='Choose one or more genomefeature to extract : cds genes proteins')
  

  ARG_PARSER.add_argument('-f', '--load_genomic_features',  action='store_true',
                         help='flag to load genomic feature into mongo collections')  
  
  ARG_PARSER.add_argument('-g', '--load_genomic_features_type', metavar='N', type=str, nargs='+', choices=['genome','genes', 'regions'],
                         help='Choose one or more genomic feature to load : genome genes regions')

  
  CLI_ARGS = ARG_PARSER.parse_args()

  CONF_PARSER = load_config(CLI_ARGS.config)

  mongo_collection_name = CONF_PARSER["MONGO DB"]["collection"]
  if CLI_ARGS.load_metadata:
    #create collection and load 
    MONGO_CLIENT = MongoDbClient(CONF_PARSER, mongo_collection_name)
    create_collection_and_schema(MONGO_CLIENT)
    load_metadata(CONF_PARSER, MONGO_CLIENT)
    
  if CLI_ARGS.load_species:
    try:
      if not CLI_ARGS.species_name:
        raise("missing species name to load the thoas mongo")
      load_each_species(CONF_PARSER, CLI_ARGS, mongo_collection_name)
    except Exception as e:
      raise(str(e))

def load_each_species (CONF_PARSER, CLI_ARGS, mongo_collection_name):
  species_details = CONF_PARSER[CLI_ARGS.species_name]
  
  # Get extra parameters from the GENERAL section.
  # The per-section parameters will override any GENERAL ones if there is a collision.
  section_args = {**CONF_PARSER["GENERAL"], **species_details}
  section_args["config_file"] = CLI_ARGS.config
  section_args["section_name"] = CLI_ARGS.species_name
  
  run_assembly(mongo_collection_name, CLI_ARGS, args=section_args)

  
def run_assembly(mongo_collection_name, CLI_ARGS, args):
    """
    Successively run all the other loading scripts
    """
    
    # Append the correct release number, division, and override the base path for GRCh37
    if args["assembly"] == "GRCh37":
        data_path = args["grch37_data_path"]
    else:
        data_path = f'{args["base_data_path"]}/{args["division"]}/json/'

    collection_param = (
        "" if "collection" not in args else f'--collection {args["collection"]}'
    )

    log_faulty_urls = (
        "--log_faulty_urls"
        if "log_faulty_urls" in args and args["log_faulty_urls"] == "True"
        else ""
    )
    if CLI_ARGS.extract_genomic_features:
      shell_extract_command={}
      shell_extract_command['cds'] = f"""
        perl {CLI_ARGS.code_path}/extract_cds_from_ens.pl --host={args["host"]} --user={args["user"]} --port={args["port"]} --species={args["production_name"]} --species_production={args["species_production"]} --assembly='{args["assembly"]}' --division={args["division"]}    
      """
      shell_extract_command['genes'] = f"""
        python {CLI_ARGS.code_path}/prepare_gene_name_metadata.py --section_name {args["section_name"]} --config_file {args["config_file"]}
      """
      shell_extract_command['proteins'] = f"""
        python {CLI_ARGS.code_path}/dump_proteins.py --section_name {args["section_name"]} --config_file {args["config_file"]}
      """
      for each_extract_type in CLI_ARGS.extract_genomic_features_type:  
        log_filename = f"{CLI_ARGS.species_name}.extract.{each_extract_type}.log"
        run_subprocess(shell_extract_command[each_extract_type], log_filename )
         
    if CLI_ARGS.load_genomic_features:
      shell_load_command = {}
      shell_load_command['genome'] = f"""
        python {CLI_ARGS.code_path}/load_genome.py --data_path {data_path} --species {args["production_name"]} --section_name {args["section_name"]} --config_file {args["config_file"]} {collection_param} --assembly={args["assembly"]} --release={args["release"]} --mongo_collection={mongo_collection_name}
      """
      shell_load_command['genes'] = f"""
        python {CLI_ARGS.code_path}/load_genes.py --data_path {data_path} --classifier_path {args["classifier_path"]} --species {args["production_name"]} --config_file {args["config_file"]} {collection_param} --assembly='{args["assembly"]}' --xref_lod_mapping_file={args["xref_lod_mapping_file"]} --release={args["release"]} --mongo_collection={mongo_collection_name} {log_faulty_urls}
      """
      shell_load_command['regions'] = f"""
        python {CLI_ARGS.code_path}/load_regions.py --section_name {args["section_name"]} --config_file {args["config_file"]} --mongo_collection={mongo_collection_name}
      """
      for each_feature in CLI_ARGS.load_genomic_features_type:
        log_filename = f"{CLI_ARGS.species_name}.load.{each_feature}.log"
        run_subprocess(shell_load_command[each_feature], log_filename )
        


def run_subprocess(cmd, log_filename):
  
  logging.basicConfig(filename=log_filename, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
  logger = logging.getLogger(__name__)
  logger.setLevel(logging.DEBUG)
  
  process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

  # Wait for the process to terminate
  stdout, stderr = process.communicate()
  
  exit_status = process.returncode
  
  logger.info(stdout.decode('utf-8'))
  
  if exit_status:
    logger.error(stderr.decode('utf-8'))
    sys.exit(1)
    
if __name__ == '__main__':
  main()
