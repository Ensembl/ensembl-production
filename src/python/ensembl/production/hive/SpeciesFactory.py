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
from ensembl.production.metadata import genomeFactory


class SpeciesFactory(eHive.BaseRunnable):

    def run(self):

        query = """      
            genomeId
            genomeUuid
            productionName
            organism {      
                ensemblName         
            }
            genomeDatasets {
                dataset {
                datasetSource {
                    name
                    type
                }
            }
          }
        """

        for genome in genomeFactory.get_genomes(
                metadata_db_uri=self.param("metadata_db_uri"),
                organism_name=self.param("organism_name"),
                genome_uuid=self.param("genome_uuid"),
                unreleased_genomes=self.param("unreleased_genomes"),
                released_genomes=self.param("released_genomes"),
                organism_group_type=self.param("organism_group_type"),
                organism_group=self.param("organism_group"),
                anti_organism_name=self.param("anti_organism_name"),
                query_param=query
        ):

            (database_name, dbtype) = (None, None)

            for each_dataset in genome.get('genomeDatasets', []):
                if each_dataset.get('dataset', {}).get('name', None) == 'assembly':
                    database_name = each_dataset.get('dataset', {}).get('datasetSource', {}).get('name', None)
                    dbtype = each_dataset.get('dataset', {}).get('datasetSource', {}).get('type', None)

            genome_info = {
                "genome_uuid": genome.get('genomeUuid', None),
                "species": genome.get('productionName', None),
                "ensembl_name": genome.get('organism', {}).get('ensemblName', None),
                "dbname": database_name,
                "type": dbtype,
            }

            self.dataflow(
                genome_info, 2
            )

    def write_output(self):
        pass
