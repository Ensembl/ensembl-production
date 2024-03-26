#!/usr/bin/env python
#  See the NOTICE file distributed with this work for additional information
#  regarding copyright ownership.
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
"""Production Variation VCF sync script tp target ftp"""
import logging
import os
import subprocess
from pathlib import Path
from typing import List

from ensembl.database import DBConnection
from ensembl.production.metadata.api.models import *
from ensembl.utils import argparse
from sqlalchemy import select, update
from sqlalchemy.engine import Row

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)


def rsync(source, destination):
    try:
        # Construct the rsync command
        rsync_cmd = ["rsync", "-av", source, destination]

        # Execute the rsync command
        subprocess.run(rsync_cmd, check=True)

        print(f"rsync completed successfully from '{source}' to '{destination}'.")
    except subprocess.CalledProcessError as e:
        print(f"Error occurred during rsync: {e}")


def main():
    parser = argparse.ArgumentParser(
        prog='variation_copy_ftp.py',
        description='Copy submitted VCF files onto FTP related genome directory'
    )
    parser.add_argument('--tgt-root', type=str, required=True)
    parser.add_argument('--dry-run', action='store_true', required=False)
    parser.add_argument('-g', '--genome_uuid', type=str, nargs='*', required=False, default=None,
                        help='genome UUID, ex: a23663571,b236571')
    parser.add_argument('-s', '--species', type=str, nargs='*', required=False, default=None,
                        help='Ensembl species names, ex: homo_sapiens,mus_musculus')
    parser.add_argument('-m', '--metadata-db-uri', type=str, required=False, default=os.getenv('METADATA_URI'),
                        help='metadata db mysql uri, ex: mysql://ensro@localhost:3366/ensembl_genome_metadata')
    parser.add_argument('-t', '--taxonomy-db-uri', type=str, required=False, default=os.getenv('TAXONOMY_URI'),
                        help='taxonomy db mysql uri, ex: mysql://ensro@localhost:3366/ncbi_taxonomy')
    args = parser.parse_args()
    # Should be using GenomeFactory to fetch genomes with a dataset of type name 'vcf'
    logger.info(f'Get Genomes ')
    with DBConnection(args.metadata_db_uri).session_scope() as session:
        query = select(Genome,
                       Dataset,
                       DatasetSource).select_from(Genome) \
            .join(GenomeDataset, Genome.genome_id == GenomeDataset.genome_id) \
            .join(Dataset, GenomeDataset.dataset_id == Dataset.dataset_id) \
            .join(DatasetSource) \
            .join(DatasetType, Dataset.dataset_type_id == DatasetType.dataset_type_id) \
            .filter(DatasetType.name == 'variation')
        if args.species is not None:
            species_list = list(args.species)
            query = query.filter(Genome.production_name in species_list)
        datasets: List[Row] = session.execute(query).all()
        for row in datasets:
            print(f"Processing {row.Genome.production_name} ")
            ftp_path = row.Genome.get_public_path(dataset_type='variation')
            dest_dir_path = Path(f"{args.tgt_root}/{ftp_path[0]['path']}")

            # Check if source file exists
            src_file = Path(row.DatasetSource.name)
            if not src_file.exists():
                print(f"Source file '{src_file}' does not exist.")
                continue

            # Check if destination directory exists, if not, create it
            if not dest_dir_path.exists():
                dest_dir_path.mkdir(parents=True, exist_ok=True)

            # Construct the destination file path
            dest_file = dest_dir_path / src_file.name

            try:
                # Copy the file
                print(f"File '{src_file}' >> '{dest_file}'")
                if not args.dry_run:
                    rsync(src_file, dest_dir_path)
                    try:
                        # update dataset to its new source path
                        stmt = update(DatasetSource).values(name=dest_file)
                        session.execute(stmt)
                    except Exception as e:
                        print(f"Unable to update corresponding DatasetSource with new file path {e}")
                print("..... copied!")
            except Exception as e:
                print(f"Error occurred while copying file: {e}")


if __name__ == '__main__':
    main()
