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
Fetch Genome Info from the new metadata api  
'''

import argparse
import logging
import json
from ensembl.production.metadata import genomeFactory

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)


def main():
    parser = argparse.ArgumentParser(
        prog='genome_info.py',
        description='Fetch Ensembl genome info from new ensembl production genomeFactory'
    )

    parser.add_argument('--metadata_db_uri', type=str, required=True,
                        help='metadata db mysql uri, ex: mysql://ensro@localhost:3366/ensembl_genome_metadata')
    parser.add_argument('--genome_uuid', type=str, nargs='*', required=False, default=None,
                        help='genome UUID, ex: a23663571,b236571')
    parser.add_argument('--released_genomes', help='Fetch only released genome ', default=False)
    parser.add_argument('--unreleased_genomes', help='Fetch only unreleased genome ', default=False)
    parser.add_argument('--organism_group', type=str, nargs='*', default=[], required=False,
                        help='versioned file name, ex: EnsemblVertbrates,EnsemblPlants')
    parser.add_argument('--organism_group_type', type=str, default='Division', required=False,
                        help='organism group type, ex: Division')
    parser.add_argument('--released_datasets', default=False, required=False,
                        help='Fetch all released datasets for genome')
    parser.add_argument('--unreleased_datasets', default=False, required=False,
                        help='Fetch all unreleased dataset for a genome')
    parser.add_argument('--dataset_source_type', type=str, nargs='*', default=[], required=False,
                        help='Fetch genomes with dataset source type ex: homo_sapiens_core_111_28')
    parser.add_argument('--dataset_type', type=str, nargs='*', default=[], required=False,
                        help='Fetch genome with dataset type ex: core, variation, compara etc.')
    parser.add_argument('--anti_dataset_type', type=str, nargs='*', default=[], required=False,
                        help='Fetch all genome with out dataset type')
    parser.add_argument('--organism_name', type=str, nargs='*', default=[], required=False,
                        help='Fetch genome based on ensembl_name ex: homo_sapiens, mus_musculus')
    parser.add_argument('--anti_organism_name', type=str, nargs='*', default=[], required=False,
                        help='Exclude genome for given anti_species')
    parser.add_argument('--query', type=str, default=None, required=False,
                        help='fetch only required columns Ex: genomeId, genomeUuid, productionName, organism{ensemblName}')
    parser.add_argument('--output', type=str, required=True, help='output file ex: genome_info.json')

    args = parser.parse_args()

    with open(args.output, 'w') as json_output:

        for genome in genomeFactory.get_genomes(
                genome_uuid=args.genome_uuid,
                metadata_db_uri=args.metadata_db_uri,
                released_genomes=args.released_genomes,
                unreleased_genomes=args.unreleased_genomes,
                organism_group_type=args.organism_group_type,
                unreleased_datasets=args.unreleased_datasets,
                released_datasets=args.released_datasets,
                dataset_source_type=args.dataset_source_type,
                dataset_type=args.dataset_type,
                anti_dataset_type=args.anti_dataset_type,
                organism_name=args.organism_name,
                organism_group=args.organism_group,
                anti_organism_name=args.anti_organism_name,
                query_param=args.query
        ):

            (database_name, dbtype, division) = (None, None, None)

            for organismgroup in genome.get('organism', {}).get('organismGroupMembers', []):
                if organismgroup.get('organismGroup', {}).get('type', None) == 'Division':
                    division = organismgroup.get('organismGroup', {}).get('name', None)

            for each_dataset in genome.get('genomeDatasets', []):
                if each_dataset.get('dataset', {}).get('name', None) == 'assembly':
                    database_name = each_dataset.get('dataset', {}).get('datasetSource', {}).get('name', None)
                    dbtype = each_dataset.get('dataset', {}).get('datasetSource', {}).get('type', None)

            genome_info = {
                "genome_uuid": genome.get('genomeUuid', None),
                "species": genome.get('productionName', None),
                "ensembl_name": genome.get('organism', {}).get('ensemblName', None),
                "assembly_default": genome.get('assembly', {}).get('assemblyDefault', None),
                "assembly_ensembl_name": genome.get('assembly', {}).get('ensemblName', None),
                "assembly_name": genome.get('assembly', {}).get('name', None),
                "assembly_accession": genome.get('assembly', {}).get('accession', None),
                "assembly_level": genome.get('assembly', {}).get('level', None),
                "division": division,
                "database_name": database_name,
                "type": dbtype,
            }
            json.dump(genome_info, json_output)
            json_output.write("\n")


if __name__ == '__main__':
    main()
