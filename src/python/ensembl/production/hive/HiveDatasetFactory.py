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

    @staticmethod
    def update_dataset_status(dataset_uuid, update_status, metadata_db_uri):
        return DatasetFactory().update_dataset_status(dataset_uuid, update_status, metadata_db_uri=metadata_db_uri)

    def run(self):
        try:

            if not self.param_required('update_dataset_status'):
                raise ValueError(f"Missing required param update_dataset_status or it set to null")

            if not self.param_required('metadata_db_uri'):
                raise ValueError(f"Missing required param metadata_db_uri or it set to null")

            # check if its a species list
            if self.param_is_defined('all_info'):
                for genome in self.param_is_defined('all_info'):
                    _, status = self.update_dataset_status(genome.get('dataset_uuid'), self.param_required('update_dataset_status'),
                                               self.param_required('metadata_db_uri'))
                    logger.info(
                        f"Updated Dataset status for dataset uuid: {genome.get('dataset_uuid')} to {self.param_required('update_dataset_status')} for genome {genome.get('genome_uuid')}"
                    )
                    genome['dataset_status'] = status
                    genome['updated_dataset_status'] = status

                self.dataflow(
                    self.param_is_defined('all_info'), 2
                )
            else:
                _, status = self.update_dataset_status(self.param_required('dataset_uuid'), self.param_required('update_dataset_status'),
                                           self.param_required('metadata_db_uri'))
                logger.info(
                    f"Updated Dataset status for dataset uuid: {self.param('dataset_uuid')} to {self.param_required('update_dataset_status')} for genome {self.param('genome_uuid')}"
                )
                self.dataflow(
                    {
                        'dataset_uuid': self.param('dataset_uuid'),
                        'genome_uuid': self.param('genome_uuid'),
                        'updated_dataset_status': status,
                        'dataset_status': status
                    }, 2
                )

        except KeyError as error:
            raise KeyError(f"Missing request parameters: {str(error)}")

        except Exception as e:
            raise Exception(f"An unexpected error occurred: {str(e)}")


def write_output(self):
    pass
