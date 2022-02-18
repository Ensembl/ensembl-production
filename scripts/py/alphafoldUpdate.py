#!/usr/bin/env python3

# License goes here

# Requirements:
#   Python 3.7+

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
#  --tmp-dir TMP_DIR  Path for temp dir to extract PDB files into. (Defaults to <script dir>/alpha_temp)
#  -v, --verbose      Increase output verbosity - UNUSED
#   python alphafoldUpdate.py jjj

import argparse
import urllib.request
import shutil
import json
import re
import os
import glob
import gzip
from os.path import exists as file_exists
from typing import Any, List, Dict

TARFILE_RE = re.compile(r'(UP.*)\.tar')
ALPHA_MAP_RE = re.compile(r'^DBREF')
METADATA_URL = "http://ftp.ebi.ac.uk/pub/databases/alphafold/download_metadata.json"


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
        with gzip.open(f, 'rt') as gfh:
            for line in gfh:
                if ALPHA_MAP_RE.match(line):
                    alpha_mappings.append(line)
    return alpha_mappings


def cleanup_unpacked_files(work_dir: str) -> None:
    files = glob.glob(work_dir + '/*.gz')
    for ff in files:
        os.remove(ff)


def dump_alphamapping(amap_list: List[str], work_dir: str, out_file_name: str = 'alpha_mapping.txt') -> None:
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
                        help='Path for temp dir to extract PDB files into. (Defaults to <script dir>/alpha_temp)')
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

    # Set tmp-dir to default value if it wasn't passed
    if not args.tmp_dir:
        args.tmp_dir = os.path.dirname(os.path.realpath(__file__))+'/alpha_temp'

    # Check if tmp-dir exists and is empty, create if it doesn't exist
    if os.path.exists(args.tmp_dir):
        if not os.path.isdir(args.tmp_dir):
            print('ERROR - Specified output exists, but it is not a directory.')
            exit(1)
        if os.listdir(args.tmp_dir):
            print('ERROR - Target output directory exixts, but it is not empty.')
            exit(1)
    else:
        try:
            os.mkdir(args.tmp_dir)
        except OSError as error:
            print('ERROR - Cannot create output folder {}'.format(args.tmp_dir))
            print(error)
            exit(1)

    # Split file name and path
    if args.tarfile_name.find('/') != -1:
        (tarfile_path, tarfile) = args.tarfile_name.rsplit('/', 1)
    else:
        tarfile = args.tarfile_name

    # Retrieve download_metadata.json file from AlphaFold web site
    af_meta = get_af_metadata(tarfile)

    # Unpack AlphaFold tar file - it expects to find it somewhere on the file system
    shutil.unpack_archive(args.tarfile_name, args.tmp_dir)

    # Read through the PDB files and extract mapping info
    alpha_mapping = get_alphamapping(args.tmp_dir)

    # Cleanup files extracted from the AlphaFold tar file
    cleanup_unpacked_files(args.tmp_dir)

    # Write out alphamapping.txt file
    dump_alphamapping(alpha_mapping, args.tmp_dir)

if __name__ == '__main__':
    main()
