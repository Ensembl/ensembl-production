#!/usr/bin/env python
# -*- coding: utf-8 -*-
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
import argparse
import itertools
import logging
import os
import sys
from os.path import expanduser
from ensembl.production.metadata.productionCommon import get_all_species_by_division
import configparser
import json
import glob

#os.chdir(os.path.normpath(os.path.join(os.path.abspath(__file__), os.pardir)))


logging.basicConfig(
    filename='checkftpfile.log',
    filemode='a',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S')

logger = logging.getLogger(__name__)

def read_config_file(filename: str):
    """Reads the config file with declared data_type

    Args:
        filename (str): config contains files format declaration 

    Returns:
        json :  file paths with data types
    """    
    try:
        config_details = configparser.ConfigParser()
        config_details.read(filename)
        
        return config_details
    except Exception as e:
        logger.error(f"Failed to read configuration file: {filename}")
        sys.exit(1)

    
    
if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Script to update directory path for Rapid Release')
    parser.add_argument('-v', '--verbose', help='Verbose output', action='store_true')
    parser.add_argument('-e', '--ens_version',action="extend", nargs="+", type=int, required=True, help='Ensembl Release numbers [101, 102]')
    parser.add_argument('-f', '--dump_path', type=str, required=True, help='release dumps directory path')    
    parser.add_argument('-s', '--species_names', action="extend", nargs="+", type=str, default=[],
                        help='species names ' )
    parser.add_argument('-g', '--eg_version', action="extend", nargs="+", type=int, required=True, help='Ensembl genome Release number [48, 49]')    
    parser.add_argument('-t', '--dump_type', action="extend", nargs="+", type=str,
                        choices=['embl', 'fasta_pep', 'genbank', 'gff3', 'gtf', 'json', 'tsv'], 
                        default=[],
                        help='datatype subdir for ftp dumps'
                        )
    
    parser.add_argument('-d', '--division', action="extend", nargs="+", 
                        choices=['vertebrates', 'plants', 'metazoa', 'bacteria', 'microbes', 'fungi'],
                        default=[],
                        required=True,
                        help='division' )
    
    parser.add_argument('-i', '--conf_file', 
                        default="./requiredFiles.conf",
                        help='config file with expected file paths')

    parser.add_argument('-m', '--metadata_url', type=str,
                        help='Metadata db Host Url format mysql://user:pass@host:port/ensembl_metadata')
    
    parser.add_argument('-c', '--coredb_url', type=str,
                        help='Core db Host Url format mysql://user:pass@host:port')

    
    
    arguments = parser.parse_args(sys.argv[1:])
    logger.setLevel(logging.INFO)
        
    if not os.path.exists(arguments.dump_path):
        logger.error(f"No ftp dump path found : {arguments.dump_path}")
        sys.exit(1)

    if not os.path.exists(arguments.conf_file):
        logger.error(f"conf_file not found : {arguments.conf_file}")
        sys.exit(1)
    
    logger.info(f"Reading Config file : {arguments.conf_file}")
    config_details = read_config_file(arguments.conf_file)
    
    if arguments.metadata_url:
        logger.info(f"Get All species from metadata : {arguments.metadata_url}")
    
    #check core dumps files
    if len(arguments.dump_type) :
        for division in arguments.division:
            division_uc = f"Ensembl{division.capitalize()}"
            
            species = arguments.species_names if len(arguments.species_names) and arguments.metadata_url else get_all_species_by_division( arguments.ens_version,
                                                                                                               arguments.eg_version, 
                                                                                                               arguments.metadata_url, 
                                                                                                               [division_uc]
                                                                                                               )
            for species, data_type in [p for p in itertools.product(*[species[division_uc], 
                                                                    arguments.dump_type])] :
                
                expected_files = config_details[data_type]['expected_files'].format(species_uc=species.capitalize()).split(',')
                sub_path = config_details[data_type]['path'].format(division=division, species_dir=species)
                
                for required_files in expected_files:
                    file_name = os.path.join(arguments.dump_path, sub_path, required_files)
                    if len(glob.glob(file_name)) == 0 :
                        logger.error(f"{data_type}  Files Missing For Species {species} in path {file_name}")
                        print(f"{data_type}  Files Missing For Species {species} in path {file_name}")
                        
                        
            
    
    
    
    
  
    
    
    
    
        
            
  