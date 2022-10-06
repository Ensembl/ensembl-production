#!/usr/bin/env python3
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Print help:
#   python alphafoldUpdate.py -h

#usage: alphafoldUpdate.py [-h] [--tmp-dir TMP_DIR] [-v] tarfile_name
#
#PDB file extractor and alphamapping file generator
#
#positional arguments:
#  tarfile_name       Full path/filename to AlphaFold TAR archive containing PDB files
#
#options:
#  -h, --help         show this help message and exit
#  --tmp-dir TMP_DIR  Path for temp dir to extract PDB files into. (Defaults to <script dir>)
#  --out-dir OUT_DIR  Path for dir to store the mappings into. (Defaults to <script dir>/afdb_files)
#  -v, --verbose      Increase output verbosity - UNUSED

import argparse
import urllib.request
import shutil
import tempfile
import json
import re
import os
import glob
import gzip
from os.path import exists as file_exists
from pathlib import Path
from typing import Any, List, Dict

TARFILE_RE = re.compile(r'(UP.*)\.tar')
ALPHA_MAP_RE = re.compile(r'^DBREF')
METADATA_URL = "https://ftp.ebi.ac.uk/pub/databases/alphafold/download_metadata.json"

UNSAFE = True

def create_output_dir(dir_name: str, force: bool = False):
    # Check if dir_name exists and is empty, create if it doesn't exist
    my_dir = Path(dir_name)
    if my_dir.exists() and not my_dir.is_dir():
        raise OSError('ERROR - Specified dir name exists, but it is not a directory.')
    try:
        my_dir.mkdir(parents=True, exist_ok=True)
    except OSError as error:
        print('ERROR - Cannot create folder {}'.format(dir_name))
        print(error)
        raise


def get_af_metadata(tarfile: str, metadata_url: str = METADATA_URL) -> Dict[str, str]:
    af_metadata = None
    with urllib.request.urlopen(metadata_url) as url:
        json_data = json.loads(url.read().decode())
    for line in json_data:
        if line['archive_name'] == tarfile:
            af_metadata = line
            break
    return af_metadata


def get_alphamapping(work_dir: str) -> List[str]:
    alpha_mappings = []
    files = glob.glob(work_dir + '/*.pdb.gz')
    for f in files:
        f_name = os.path.basename(f)[:-len('.gz')]
        with gzip.open(f, 'rt') as gfh:
            for line in gfh:
                if ALPHA_MAP_RE.match(line):
                    my_line = f"{f_name}:{line}"
                    alpha_mappings.append(my_line)
    return alpha_mappings


def dump_alphamapping(amap_list: List[str], work_dir: str, out_file_name: str = 'alpha_mappings.txt') -> None:
    full_outfile = work_dir + '/' + out_file_name
    with open(full_outfile, 'wt') as wfh:
        for item in amap_list:
            wfh.write(item)


def main():
    # Parse arguments
    parser = argparse.ArgumentParser(description='PDB file extractor and alphamapping file generator')
    parser.add_argument('tarfile_name', type=str,
                        help='Full path/filename to AlphaFold TAR archive containing PDB files')
    parser.add_argument('--tmp-dir', type=str,
                        help='Path for temp dir to extract PDB files into. (Defaults to <script dir>)')
    parser.add_argument('--out-dir', type=str,
                        help='Path for output dir to store alpha mappings into. (Defaults to <script dir>/afdb_files)')
    parser.add_argument("-v", "--verbose", action="count", default=0,
                        help="Increase output verbosity - UNUSED")

    args = parser.parse_args()

    # Check if tarfile_name was passed and that it exists
    if not file_exists(args.tarfile_name):
        print('ERROR - Cannot find input file {}. Exiting...'.format(args.tarfile_name))
        exit(1)

    # Check if tarfile_name has the correct format
    m = TARFILE_RE.search(args.tarfile_name)
    if not m:
        print('ERROR - TAR file expected as input. Found instead {}. Exiting...'.format(args.tarfile_name))
        exit(1)

    # Set out-dir to default value if it wasn't passed
    if not args.out_dir:
        args.out_dir = os.path.dirname(os.path.realpath(__file__))+'/afdb_files'

    # Set tmp-dir to default value if it wasn't passed
    if not args.tmp_dir:
        args.tmp_dir = os.path.dirname(os.path.realpath(__file__))
    
    if not os.path.isdir(args.tmp_dir):
        print('ERROR - TMP-DIR is not a directory. Exiting...')
        exit(1)

    # Create temp directory
    temp_dir = tempfile.TemporaryDirectory(prefix="alphafoldtmp-", dir=args.tmp_dir)

    # Split file name and path
    if args.tarfile_name.find('/') != -1:
        (tarfile_path, tarfile) = args.tarfile_name.rsplit('/', 1)
    else:
        tarfile = args.tarfile_name

    # Retrieve download_metadata.json file from AlphaFold web site
    af_meta = get_af_metadata(tarfile)

    species_dir = Path(af_meta.get("species").lower().replace(" ","_"))
    out_dir = os.path.join(args.out_dir, species_dir)

    # DANGEROUS STUFF - aggressive cleanup of output directory
    if UNSAFE:
        shutil.rmtree(out_dir, ignore_errors=True)

    # Check if out-dir exists and is empty, create if it doesn't exist
    try:
        create_output_dir(out_dir, UNSAFE)
    except OSError as error:
        print(error)
        exit(1)

    # Unpack AlphaFold tar file - it expects to find it somewhere on the file system
    shutil.unpack_archive(args.tarfile_name, temp_dir.name)

    # Read through the PDB files and extract mapping info
    alpha_mapping = get_alphamapping(temp_dir.name)

    # Write out alphamapping.txt file
    dump_alphamapping(alpha_mapping, out_dir)


if __name__ == '__main__':
    main()
