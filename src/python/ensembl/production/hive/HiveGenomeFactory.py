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

"""
GenomeFactory Module to fetch genome information from new metadata schema
"""

import logging
import eHive
from ensembl.production.metadata.api.factories.genomes import GenomeFactory

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class HiveGenomeFactory(eHive.BaseRunnable):
    
    def fetch_input(self):

        for param in ['dataset_status', 'dataset_type']:
            if not self.param_is_defined(param):
                raise KeyError(f"Missing Required Param {param}")

            if not isinstance(self.param('dataset_status'), list):
                self.param('dataset_status', [param_value for param_value in self.param(param).split(',')])

        if not self.param_is_defined('update_dataset_status') or \
                not isinstance(self.param('update_dataset_status'), str) \
                or self.param('update_dataset_status') not in ['Submitted',
                                                               'Processing',
                                                               'Processed',
                                                               'Released']:

            raise KeyError("""Missing Required Param update_dataset_status or 
                            Param update_dataset_status is not a type string""")

    def run(self):
        # default status updated to processing
        fetched_genomes = GenomeFactory().get_genomes(
            metadata_db_uri=self.param_required('metadata_db_uri'),
            update_dataset_status=self.param('update_dataset_status'),
            genome_uuid=self.param('genome_uuid'),
            dataset_uuid=self.param('dataset_uuid'),
            dataset_type=self.param('dataset_type'),
            dataset_status=self.param('dataset_status'),
            division=self.param('division'),
            organism_group_type=self.param('organism_group_type'),
            species=self.param('species'),
            antispecies=self.param('antispecies'),
            batch_size=self.param('batch_size'),
        )

        species_list = []
        all_info = []

        for genome_info in fetched_genomes:

            # standard flow similar to production modules
            self.dataflow(
                genome_info, 2
            )
            logger.info(
                f"Found genome {genome_info}"
            )
            species_list.append(genome_info.get('species', None))
            all_info.append(genome_info)

        # hive flow for all species as a list
        self.dataflow(
            {
                "species": species_list,
                "all_info": all_info
             }, 3
        )

    def write_output(self):
        pass
