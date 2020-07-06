#!/usr/bin/env python
"""
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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
This script takes an directory path as parameter and convert the output from ~metadata/misc_scripts/report_genomes.pl
and turn it into a flat file names `species_list.txt` to `cat` into a eHive pipeline configuration script.
Example:
- species AAA \
- species BBB \
     
'''
import argparse
import csv
import logging
from os import getenv
from os.path import isdir
from os.path import join, isfile, realpath

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)
parser = argparse.ArgumentParser(
    description='Parse outputs from `~ensemble-metadata/misc_scripts/genomes_report.pl to get species_list for hive'
                ' init_pipeline command')
parser.add_argument('-i', '--input_dir', type=str, required=True, help='Input directory')
parser.add_argument('-d', '--division', help='Restrict to a single division', type=str, choices=divisions)
parser.add_argument('-f', '--output_file', help='Overwrite default output file name', required=False)
parser.add_argument('-t', '--genomes_types', help='List genomes events (n,r,ua,ug)', required=False, type=str,
                    default='n,r,ua,ug')
parser.add_argument('-o', '--output', help='species,dbname', required=False, type=str,
                    default='species')

divisions = (
    'vertebrates',
    'metazoa',
    'fungi',
    'protists',
    'plants'
)
names = {
    'n': '{}-new_genomes.txt',
    'r': '{}-renamed_genomes.txt',
    'ua': '{}-updated_annotations.txt',
    'ug': '{}-updated_assemblies.txt',
}

if __name__ == '__main__':
    args = parser.parse_args()
    if not args.output_file:
        logger.setLevel(logging.ERROR)
    if args.division:
        assert args.division in divisions, "Unknown Division name, please chose in {}".format(divisions)
        logger.info("Process only division {}".format(args.division))
        divisions = [args.division]
    else:
        logger.info("Process all divisions")

    home_dir = getenv("HOME")
    assert isdir(args.input_dir), "Input dir is mandatory when not running report_genomes.pl"
    scan_dir = realpath(args.input_dir)
    logger.info("Input Dir: {}".format(realpath(scan_dir)))

    species = []
    expected_files_names = [names[n] for n in args.genomes_types.split(',')]

    for div in divisions:
        logger.info("Division: {}".format(div))
        expected_files = [ex.format(div) for ex in expected_files_names]
        for file in expected_files:
            file_path = join(scan_dir, file)
            if isfile(file_path):
                with open(file_path, 'r') as f:
                    logger.info("Current File: {}".format(f.name))
                    reader = csv.reader(f, delimiter="\t")
                    next(reader)
                    for row in reader:
                        species.append(row[0]) if args.output == 'species' else species.append(row[2])
            else:
                logger.info("File not found: {}".format(file_path))

    logger.info("Retrieved species:")
    logger.info(species)
    if args.output_file:
        out_file_path = join(home_dir, args.output_file)
        with open(out_file_path, 'w') as f:
            for spec in species:
                f.write('-species {} '.format(spec)) if args.output == 'species' else f.write('{},'.format(spec))
        logger.info("File generated in {}".format(out_file_path))
    else:
        for spec in species:
            print('-species {} '.format(spec), end="", flush=True) if args.output == 'species' else print(
                '{},'.format(spec), end="", flush=True)
