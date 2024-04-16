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
Fetch Genome Info from the new metadata api  
'''

import argparse
import logging
import json
import re
from sqlalchemy import text
from ensembl.production.metadata.api.factories.genomes import GenomeFactory
from ensembl.production.metadata.api.models import Genome, Dataset, DatasetSource, DatasetType, Assembly, OrganismGroup

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)


def default_columns():
    """
    Columns Required to generate thoas & genome browser config file
    """
    return [
        Genome.genome_uuid,
        Genome.production_name.label('species'),
        OrganismGroup.name.label('division'),
        Assembly.name.label('assembly_name'),
        Assembly.accession.label('assembly_accession'),
        Assembly.level.label('assembly_level'),
        Assembly.assembly_default.label('assembly_default'),
        Dataset.dataset_uuid,
        DatasetSource.name.label('database_name'),
        Dataset.status.label('dataset_status'),
        DatasetType.name.label('dataset_type'),
    ]


def validate_columns(values: str) -> list:
    """
    Validate the user provided comma separated columns names and convert to sqlalchemy text object
    """
    values = values.split(",")
    # check if column dataset.dataset_uuid provided by user
    if not [1 for item in values if item == "dataset.dataset_uuid"]:
        raise argparse.ArgumentTypeError(f"Required column dataset.dataset_uuid missing")
    pattern = re.compile(r'^(genome|assembly|dataset|dataset_type|dataset_source|organism|organism_group)\..*$')
    valid_columns = []
    if values:
        for item in values:
            if not pattern.match(item):
                raise argparse.ArgumentTypeError(f"Invalid value: {item}")
            valid_columns.append(text(item))
    return valid_columns


def main():
    parser = argparse.ArgumentParser(
        prog='genome_info.py',
        description='Fetch Ensembl genome info from new ensembl metadata'
    )

    parser.add_argument('--genome_uuid', type=str, nargs='*', default=[], required=False,
                        help='List of genome UUIDs to filter the query. Default is an empty list.')
    parser.add_argument('--dataset_uuid', type=str, nargs='*', default=[], required=False,
                        help='List of dataset UUIDs to filter the query. Default is an empty list.')
    parser.add_argument('--organism_group_type', type=str, default='DIVISION', required=False,
                        help='Organism group type to filter the query. Default is "DIVISION"')
    parser.add_argument('--division', type=str, nargs='*', default=[], required=False,
                        help='List of organism group names to filter the query. Default is an empty list.')
    parser.add_argument('--dataset_type', type=str, default="assembly", required=False,
                        help='List of dataset types to filter the query. Default is an empty list.')
    parser.add_argument('--species', type=str, nargs='*', default=[], required=False,
                        help='List of Species Production names to filter the query. Default is an empty list.')
    parser.add_argument('--antispecies', type=str, nargs='*', default=[], required=False,
                        help='List of Species Production names to exclude from the query. Default is an empty list.')
    parser.add_argument('--dataset_status', nargs='*', default=["Submitted"],
                        choices=['Submitted', 'Processing', 'Processed', 'Released'], required=False,
                        help='List of dataset statuses to filter the query. Default is an empty list.')
    parser.add_argument('--update_dataset_status', type=str, default="", required=False,
                        choices=['Submitted', 'Processing', 'Processed', 'Released', ''],
                        help='Update the status of the selected datasets to the specified value. ')
    parser.add_argument('--batch_size', type=int, default=50, required=False,
                        help='Number of results to retrieve per batch. Default is 50.')
    parser.add_argument('--page', default=1, required=False,
                        type=lambda x: int(x) if int(x) > 0 else argparse.ArgumentTypeError(
                            "{x} is not a positive integer"),
                        help='The page number for pagination. Default is 1.')
    parser.add_argument('--metadata_db_uri', type=str, required=True,
                        help='metadata db mysql uri, ex: mysql://ensro@localhost:3366/ensembl_genome_metadata')
    parser.add_argument('--columns', type=validate_columns,
                        default=default_columns(),
                        required=False,
                        help='fetch the genome data for given columns')
    parser.add_argument('--output', type=str, required=True, help='output file ex: genome_info.json')

    args = parser.parse_args()

    with open(args.output, 'w') as json_output:
        logger.info(f'Writing Results to {args.output}')
        for genome in GenomeFactory().get_genomes(
                metadata_db_uri=args.metadata_db_uri,
                update_dataset_status=args.update_dataset_status,
                genome_uuid=args.genome_uuid,
                dataset_uuid=args.dataset_uuid,
                organism_group_type=args.organism_group_type,
                division=args.division,
                dataset_type=args.dataset_type,
                species=args.species,
                antispecies=args.antispecies,
                batch_size=args.batch_size,
                dataset_status=args.dataset_status,
                columns=args.columns
        ) or []:
            logger.info(f'Writing genome info for {genome}')
            json.dump(genome, json_output)
            json_output.write("\n")


if __name__ == '__main__':
    main()
