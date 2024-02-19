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
    
    if not dataset_status or dataset_status is None :
      dataset_status = [DatasetStatusEnum.SUBMITTED]
      
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
      self.param("query_param", query_param )

  def run(self):  
    genome_fetcher = GenomeFetcher(metadata_db_uri=self.param_required("metadata_db_uri") )    
    for genome in genome_fetcher.get_genomes(
      query_schema=GenomeQuery,
      genome_uuid=self.param('genome_uuid'),
      released_genomes=self.param('released_genomes'),
      unreleased_genomes=self.param('unreleased_genomes'),
      organism_group_type=self.param('organism_group_type'),
      division=self.param('division'),
      unreleased_datasets=self.param('unreleased_datasets'),
      released_datasets=self.param('released_datasets'),
      dataset_source_type=self.param('dataset_source_type'),
      dataset_type=self.param('dataset_type'),
      anti_dataset_type=self.param('anti_dataset_type'),
      species=self.param('species'),
      anti_species=self.param('antispecies'),
      biosample_id=self.param('biosample_id'),
      anti_biosample_id=self.param('anti_biosample_id'),
      batch_size=self.param('batch_size'),
      run_all=self.param('run_all'),
      dataset_status=self.param('dataset_status'),
      update_dataset_status=self.param('update_dataset_status'),
      query_param=self.param('query_param')
    ):
  
      genome_info = {
        "genome_uuid": genome.get('genomeUuid', None),
        "species": genome.get('productionName', None),
        "biosample_id": genome.get('organism', {}).get('bioSampleId', None),
        "datasets": genome.get('genomeDatasets', [] ),
        "request_methods": ['update_dataset_status'],
        #If multiple dataset type are queried, only the last one is selected and processed.
        "request_method_params": {"update_dataset_status": { k.replace('datasetUuid', 'dataset_uuid'): v for dataset in genome.get('genomeDatasets', [] ) for k, v in dataset.get('dataset', {}).items() if k=='datasetUuid' } }   
      }
      #standard flow similar to production modules 
      self.dataflow(
          genome_info, 2
      )

  def write_output(self):
    pass
