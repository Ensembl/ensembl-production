#!/usr/bin/env python
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

parser = argparse.ArgumentParser(
    description='Parse outputs from `~ensemble-metadata/misc_scripts/genomes_report.pl to get species_list for hive'
                ' init_pipeline command')
parser.add_argument('-i', '--input_dir', type=str, required=True, help='Input directory')
parser.add_argument('-d', '--division', help='Restrict to a single division', type=str)
parser.add_argument('-f', '--file_output', help='Overwrite default output file name', required=False, type=str)
parser.add_argument('-t', '--genomes_types', help='List genomes events (n,r,ua,ug)', required=False, type=str,
                    default='n,r,ua,ug')

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
    if args.division:
        assert args.division in divisions, "Unknown Division name, please chose in {}".format(divisions)
        logging.info("Process only division {}".format(args.division))
        divisions = [args.division]
    else:
        logging.info("Process all divisions")

    home_dir = getenv("HOME")
    assert isdir(args.input_dir), "Input dir is mandatory when not running report_genomes.pl"
    scan_dir = realpath(args.input_dir)
    logging.info("Input Dir: {}".format(realpath(scan_dir)))

    species = []
    expected_files_names = [names[n] for n in args.genomes_types.split(',')]

    for div in divisions:
        logging.info("Division: {}".format(div))
        expected_files = [ ex.format(div) for ex in expected_files_names]
        for file in expected_files:
            file_path = join(scan_dir, file)
            if isfile(file_path):
                with open(file_path, 'r') as f:
                    logging.info("Current File: {}".format(f.name))
                    reader = csv.reader(f, delimiter="\t")
                    next(reader)
                    for row in reader:
                        species.append(row[0])
            else:
                logging.info("File not found: {}".format(file_path))

    logging.info("Retrieved species:")
    logging.info(species)
    with open(join(home_dir, 'species.txt'), 'w') as f:
        for spec in species:
            f.write('-species {} '.format(spec))
    logging.info("File generated in {}".format(join(home_dir, 'species.txt')))
