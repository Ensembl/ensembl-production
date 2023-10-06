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
  
  @staticmethod
  def check_params(param):
    if  isinstance(param, tuple):
        param = param[0]
    if isinstance(param, list):
      if(len(param)==0):
        param = None
    if param is not None and not isinstance(param, list):
        param = [param]
    return param
    
  def run(self):

    genome_info_obj = GenomeAdaptor(metadata_uri=self.param("metadata_db_uri"), 
                                    taxonomy_uri=self.param("taxonomy_db_uri"))  
     
    for genome in genome_info_obj.fetch_genomes_info(
                                                     genome_uuid=self.check_params(self.param("genome_uuid")),
                                                     ensembl_name=self.check_params(self.param("ensembl_species")),
                                                     group=self.check_params(self.param("organism_group")),
                                                     group_type=self.check_params(self.param("organism_group_type")),
                                                     dataset_name=self.check_params(self.param("dataset_name")),
                                                     dataset_source=self.check_params(self.param("dataset_source")),
                                                     allow_unreleased_genomes=self.check_params(self.param("unreleased_genomes")),
                                                     allow_unreleased_datasets=self.check_params(self.param("unreleased_datasets")),
                                                     dataset_attributes=self.check_params(self.param("dataset_attributes"))                                            
                                                    ) or []:
      genome_info = { 
                     "genome_uuid": genome[0]['genome'][0].genome_uuid,
                     "species"    : genome[0]['genome'][1].ensembl_name,
                     "division"   : genome[0]['genome'][3].name,
                     "group"      : genome[0]['datasets'][0][4].type,   #dbtype (core|variation|otherfeatures)
                     "dbname"     : genome[0]['datasets'][0][4].name,
      }
            
      self.dataflow(
        genome_info  , 2
      )

  def write_output(self):
      pass
