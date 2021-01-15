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
import sys
from os import getenv
from os.path import isdir
from os.path import join, isfile, realpath

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)

divisions = (
    'vertebrates',
    'metazoa',
    'fungi',
    'protists',
    'plants'
)
parser = argparse.ArgumentParser(
    description='Parse outputs from `~ensemble-metadata/misc_scripts/genomes_report.pl to get species_list for hive'
                ' init_pipeline command')
parser.add_argument('-i', '--input_dir', type=str, required=True, help='Input directory')
parser.add_argument('-d', '--division', help='Restrict to a single division', type=str, choices=divisions)
parser.add_argument('-v', '--version', help='versioned file name', required=False, default=getenv('ENS_VERSION'))
parser.add_argument('-t', '--genomes_types', help='List genomes events (n r ua ug)', type=str, nargs='+',
                    default=['n', 'r', 'ua', 'ug'])


names = {
    'n': '{}-new_genomes.txt',
    'r': '{}-renamed_genomes.txt',
    'ua': '{}-updated_annotations.txt',
    'ug': '{}-updated_assemblies.txt',
}

if __name__ == '__main__':
    args = parser.parse_args()
    if args.division:
        logger.info("Process only division %s", args.division)
        divisions = [args.division]
    else:
        logger.info("Process all divisions")

    home_dir = getenv("HOME")
    if not isdir(args.input_dir):
        sys.exit("Input dir is mandatory")
    scan_dir = realpath(args.input_dir)
    logger.info("Input Dir: %s", realpath(scan_dir))

    species = []
    expected_files_names = [names[n] for n in args.genomes_types]

    for div in divisions:
        logger.info("Division: %s", div)
        expected_files = [ex.format(div) for ex in expected_files_names]
        for file in expected_files:
            file_path = join(scan_dir, file)
            if isfile(file_path):
                with open(file_path, 'r') as f:
                    logger.info("Current File: %s", f.name)
                    reader = csv.reader(f, delimiter="\t")
                    next(reader)
                    for row in reader:
                        species.append([row[0], row[2]])
            else:
                logger.info("File not found: %s", file_path)

    logger.info("Retrieved species:")
    [logger.info('%s', spec) for spec in species]
    with open(join(home_dir, 'species_%s.txt' % args.version), 'w') as f:
        [f.write('-species {} '.format(spec[0])) for spec in species]
        logger.info("Generated %s", f.name)
    with open(join(home_dir, 'database_%s.txt' % args.version), 'w') as f:
        [f.write('-database {} '.format(spec[1])) for spec in species]
        logger.info("Generated %s", f.name)
    with open(join(home_dir, 'dblist_%s.txt' % args.version), 'w') as f:
        dbs = [spec[1] for spec in species]
        f.write(','.join(dbs))
        logger.info("Generated %s", f.name)
