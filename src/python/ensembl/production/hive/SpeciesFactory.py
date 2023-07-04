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
from dataclasses import asdict
from ensembl.production.metadata.api.genome import GenomeAdaptor

class SpeciesFactory(eHive.BaseRunnable):
  def fetch_input(self):
    #set default params  
    self.param("genome_uuid", None)
    self.param_defaults("species", None) 
    self.param_defaults("organism_group", None)       
    self.param_defaults("organism_group_type", None)      
    self.param_defaults("dataset_name", None)
    self.param_defaults("dataset_source", None)        
    self.param_required("unreleased_genomes")
    self.param_required("metadata_db_uri")  
    self.param_required("taxonomy_db_uri")   

  def run(self):
    genome_info_obj = GenomeAdaptor(metadata_uri=self.param("metadata_db_uri"), 
                                    taxonomy_uri=self.param("taxonomy_db_uri"))           
    for genome in genome_info_obj.fetch_genomes_info(genome_uuid=self.param("genome_uuid"),
                                                     ensembl_name=self.param("species"),
                                                     group=self.param("organism_group"),
                                                     group_type=self.param("organism_group_type"),
                                                     dataset_name=self.param("dataset_name"),
                                                     dataset_source=self.param("dataset_source"),
                                                     unreleased_genomes=self.param("unreleased_genomes")) or []:
      
      genome_info = { 
                     "genome_uuid": genome[0]['genome'][0].genome_uuid,
                     "group"      : genome[0]['datasets'][-1][-1].type   #dbtype (core|variation|otherfeatures)
      }
      
      if self.param("species"):
          genome_info["species"] = genome[0]['genome'][1].ensembl_name
      
      if self.param("organism_group"):
        genome_info["division"] = genome[0]['genome'][-1].name
      
      self.dataflow(
        asdict(genome_info)  , 2
      )

  def write_output(self):
      pass
