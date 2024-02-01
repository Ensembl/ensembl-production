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
SpeciesFactory for MVP
"""

import eHive
from ensembl.production.factories.metadata import genomeFactory


class SpeciesFactory(eHive.BaseRunnable):

  def run(self):
    
    query = self.param("query")
    
    if self.param("query") is None:
      query = """      
          genomeUuid
          productionName
          organism {      
              biosampleId         
          }
          genomeDatasets {
              dataset {
                  datasetUuid,
                  name,
                  datasetSource {
                      name
                      type
                  }
              }
          }
      """

    for genome in genomeFactory.get_genomes(
            metadata_db_uri=self.param_required("metadata_db_uri"),
            genome_uuid=self.param("genome_uuid"),
            released_genomes=self.param("released_genomes"),
            unreleased_genomes=self.param("unreleased_genomes"),
            organism_group_type=self.param("organism_group_type"),
            organism_group=self.param("organism_group"),
            unreleased_datasets=self.param("unreleased_datasets"),
            released_datasets=self.param("released_datasets"),
            dataset_source_type=self.param("dataset_source_type"),
            dataset_type=self.param("dataset_type"),
            anti_dataset_type=self.param("anti_dataset_type"),
            species_production_name=self.param("species_production_name"),
            anti_species_production_name=self.param("anti_species_production_name"),
            biosample_id=self.param("biosample_id"),
            anti_biosample_id=self.param("anti_biosample_id"),
            batch_size=self.param("batch_size"),
            dataset_status= self.param_required("dataset_status"),
            update_dataset_status=self.param("update_dataset_status"),
            query=query
            
    ):
      
      genome_info = {
        "genome_uuid": genome.get('genomeUuid', None),
        "species": genome.get('productionName', None),
        "biosample_id": genome.get('organism', {}).get('bioSampleId', None),
        "datasets": genome.get('genomeDatasets', []),  
      }

      self.dataflow(
          genome_info, 2
      )

  def write_output(self):
    pass
