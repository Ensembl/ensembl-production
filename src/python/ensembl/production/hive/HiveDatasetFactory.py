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
Hive DatasetFactory module to perform CRUD operation on dataset 
"""
import logging
import eHive
from ensembl.production.metadata.api.factories.datasets import DatasetFactory

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class HiveDatasetFactory(eHive.BaseRunnable):

    def run(self):
        try:
            # Set next update status mappings
            next_status = {
                'Submitted': 'Processing',
                'Processing': 'Processed',
                'Processed': 'Released'
            }

            if not self.param_required('metadata_db_uri') or self.param('metadata_db_uri') == '':
                raise ValueError(f"Missing required param metadata_db_uri or it set to null")

            if not self.param_is_defined('update_dataset_status') and not self.param_is_defined('attribute_dict'):
                raise ValueError(f"Either update_dataset_status or attribute_dict must be defined")

            # Retrieve parameter values
            update_dataset_status = self.param_is_defined('update_dataset_status')
            attribute_dict = self.param('attribute_dict')

            if not isinstance(attribute_dict, dict):
                raise TypeError("attribute_dict must be a dictionary")

            if not self.param_is_defined('all_info'):
                genomes = [{
                    'dataset_source': self.param('dataset_source'),
                    'dataset_status': self.param('dataset_status'),
                    'dataset_type': self.param('dataset_type'),
                    'dataset_uuid': self.param('dataset_uuid'),
                    'genome_uuid': self.param('genome_uuid'),
                    'species': self.param('species'),
                    'updated_dataset_status': self.param('updated_dataset_status'),
                }]
                self.param('all_info', genomes)

            for genome in self.param('all_info'):
                # Update status if specified
                if update_dataset_status:
                    if genome.get('updated_dataset_status') and \
                            self.param('update_dataset_status') == genome.get('updated_dataset_status'):
                        update_dataset_status = next_status[genome.get('updated_dataset_status')]

                    _, status = DatasetFactory().update_dataset_status(
                        genome.get('dataset_uuid'),
                        update_dataset_status,
                        metadata_uri=self.param_required('metadata_db_uri')
                    )
                    genome['dataset_status'] = genome.get('updated_dataset_status', genome.get('dataset_status'))
                    genome['updated_dataset_status'] = status
                    logger.info(
                        f"Updated Dataset status for dataset uuid: {genome.get('dataset_uuid')} to {update_dataset_status} for genome {genome.get('genome_uuid')}")

                # Update dataset attributes if specified
                if attribute_dict:
                    DatasetFactory(self.param_required('metadata_db_uri')).update_dataset_attributes(
                        genome.get('dataset_uuid'),
                        attribute_dict,
                    )
                    logger.info(f"Updated Dataset attributes {attribute_dict} for genome {genome.get('genome_uuid')}")

                self.dataflow(genome, 2)

            self.dataflow({'all_info': self.param('all_info')}, 3)

        except KeyError as error:
            raise KeyError(f"Missing request parameters: {str(error)}")
        except Exception as e:
            raise Exception(f"An unexpected error occurred: {str(e)}")
