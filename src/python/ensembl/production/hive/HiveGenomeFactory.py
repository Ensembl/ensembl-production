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

import eHive
from ensembl.production.factories.metadata.genomeFactory import GenomeFetcher, GenomeQuery, DatasetStatusEnum


class HiveGenomeFactory(eHive.BaseRunnable):
    
    def fetch_input(self):
        query_param = self.param("query_param")
        dataset_status = self.param("dataset_status")
        
        if dataset_status is None:
            self.param('dataset_status', [DatasetStatusEnum.SUBMITTED])
        
        if not query_param or query_param is None:
            query_param = """
          genomeUuid
          productionName
          organism {      
              biosampleId         
          }
          genomeDatasets {
              dataset {
                  datasetUuid,
                  name,
                  status
                  datasetSource {
                      name
                      type
                  }
              }
          }
      """
            self.param("query_param", query_param)
    
    def run(self):
        genome_fetcher = GenomeFetcher(metadata_db_uri=self.param_required("metadata_db_uri"))
        for genome in genome_fetcher.get_genomes(
                GenomeQuery,
                self.param('update_dataset_status'),
                genome_uuid=self.param('dataset_uuid'),
                dataset_type=self.param('dataset_type'),
                dataset_status=self.param('dataset_status'),
                division=self.param('division'),
                organism_group_type=self.param('organism_group_type'),
                species=self.param('species'),
                anti_species=self.param('antispecies'),
                batch_size=self.param('batch_size'),
        ):
            genome_info = {
                "genome_uuid": genome.get('genomeUuid', None),
                "species": genome.get('productionName', None),
                "biosample_id": genome.get('organism', {}).get('bioSampleId', None),
                "datasets": genome.get('genomeDatasets', []),
                "request_methods": ['update_dataset_status'],
                # If multiple dataset type are queried, only the last one is selected and processed.
                "request_method_params": {
                    "update_dataset_status": {k.replace('datasetUuid', 'dataset_uuid'): v for dataset in
                                              genome.get('genomeDatasets', []) for k, v in
                                              dataset.get('dataset', {}).items() if k == 'datasetUuid'}}
            }
            # standard flow similar to production modules
            self.dataflow(
                genome_info, 2
            )
    
    def write_output(self):
        pass
