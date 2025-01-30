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
Dump the json files for solr indexing  
'''

import re
import json
import argparse
import ijson
import logging
import os
import csv
from sqlalchemy import func, select
from ensembl.database import DBConnection
from ensembl.production.metadata.api.models.dataset import DatasetType, Dataset, DatasetSource, DatasetStatus
from ensembl.production.metadata.api.models.genome import Genome, GenomeDataset
from ensembl.production.metadata.api.models.organism import Organism, OrganismGroup, OrganismGroupMember

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def check_directory(path):
    if not os.path.isdir(path):
        raise argparse.ArgumentTypeError(f"The directory '{path}' does not exist.")
    return path

if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="Create Metadata CSV File For Track API Loading"
    )
    parser.add_argument(
        '--genome_uuid',
        type=str,
        nargs='*',
        default=[],
        required=False,
        help='List of genome UUIDs to filter the query. Default is an empty list.'
    )
    parser.add_argument(
        '--species',
        type=str,
        nargs='*',
        default=[],
        required=False,
        help='List of Species Production names to filter the query. Default is an empty list.'
    )
    parser.add_argument(
        '--dataset_attributes',
        type=str,
        nargs='*',
        default=['genebuild.provider_name', 'genebuild.provider_url'],
        required=False,
        help="Fetch dataset attribute values for given dataset type name"
    )
    parser.add_argument(
        '--metadata_db_uri',
        type=str,
        required=True,
        help='metadata db mysql uri, ex: mysql://ensro@localhost:3366/ensembl_genome_metadata'
    )
    parser.add_argument(
        '--dataset_type',
        type=str,
        default='genebuild',
        required=False,
        help="Fetch Dataset Based on dataset type Ex: genebuild"
    )
    parser.add_argument(
        '--file_path',
        type=check_directory,
        required=False,
        help="Path to the genome browser files directory "
    )
    parser.add_argument(
        '--file_name',
        type=str,
        default='chrom.hashes.ncd,chrom.sizes.ncd,genome_report.txt,genome_summary.bed,contigs.bb,contigs.bed,gc.bw,transcripts.bb,transcripts.bed,jump.ncd',
        required=False,
        help="Comma separated list of file name"
    )
    parser.add_argument(
        '--output_filename',
        type=str,
        default='track_api.csv',
        help='output filename ex: track_api.csv '
    )

    ARGS = parser.parse_args()
    logger.info(
        f"Provided Arguments  {ARGS} "
    )
    query = (select(Dataset).outerjoin(Dataset.genome_datasets)
             .filter(Dataset.dataset_type.has(DatasetType.name.in_([ARGS.dataset_type]))))
    if ARGS.genome_uuid:
        query = query.filter(GenomeDataset.genome.has(Genome.genome_uuid.in_(ARGS.genome_uuid)))
    if ARGS.species:
        query = query.filter(GenomeDataset.genome.has(Genome.production_name.in_(ARGS.species)))

    logger.info(
        f"Quering metadata : {query} "
    )

    with open(ARGS.output_filename, mode='w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=[])
        logger.info(
            f"Writing to file  : {ARGS.output_filename} "
        )
        with DBConnection(ARGS.metadata_db_uri).session_scope() as session:
            for dataset in  session.scalars(query):
                row_data = {'core_db': dataset.dataset_source.name}
                #set species and uuid from genome
                for genome_dataset in dataset.genome_datasets:
                    genome = genome_dataset.genome
                    row_data['species'] = genome.production_name
                    row_data['genome_uuid'] =  genome.genome_uuid
                #set attribute values
                for attrib in dataset.dataset_attributes :
                    if attrib.attribute.name in ARGS.dataset_attributes:
                        row_data[attrib.attribute.name] = attrib.value
                        row_data.setdefault('annotation_type', 'Annotated')
                #set annotation type
                if row_data.get('genebuild.provider_name') == 'Ensembl':
                    row_data['annotation_type']= 'Imported'
                #set file directory and file names
                row_data.setdefault('file_path', ARGS.file_path)
                row_data.setdefault('file_name', ARGS.file_name)

                if not writer.fieldnames:
                    writer.fieldnames = list(row_data.keys())
                    writer.writeheader()
                writer.writerow(row_data)

        logger.info(
            f"Writing to file  : {ARGS.output_filename} completed ! "
        )
