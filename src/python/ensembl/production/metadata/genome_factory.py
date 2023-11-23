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
import json
import argparse
import logging
import graphene
from graphene_sqlalchemy import SQLAlchemyObjectType
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select
from ensembl.production.metadata.api.models.genome import Genome, GenomeDataset
from ensembl.production.metadata.api.models.organism import Organism, OrganismGroup ,OrganismGroupMember
from ensembl.production.metadata.api.models.assembly import Assembly 
from ensembl.production.metadata.api.models.dataset import DatasetType , Dataset, DatasetSource

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)

# Define the Enum type
class DatasetStatusEnum(graphene.Enum):
  SUBMITTED = 'Submitted'
  PROGRESSING = 'Progressing'
  PROCESSED = 'Processed'
 
class GenomeFilterInput(graphene.InputObjectType):
  genome_uuid         = graphene.List(graphene.String)
  released_genomes    = graphene.Boolean(default_value=False)
  unreleased_genomes  = graphene.Boolean(default_value=False)
  organism_group_type = graphene.String(default_value='DIVISION')
  organism_group      = graphene.List(graphene.String, default=[])
  unreleased_datasets = graphene.Boolean(default_value=False)
  released_datasets   = graphene.Boolean(default_value=False)
  dataset_source_type = graphene.List(graphene.String, default=[])
  dataset_type        = graphene.List(graphene.String, default=[])
  anti_dataset_type   = graphene.List(graphene.String, default=[])
  organism_name       = graphene.List(graphene.String, default=[])
  anti_organism_name  = graphene.List(graphene.String, default=[]) 
  
class AssemblyType(SQLAlchemyObjectType):
    class Meta:
        model = Assembly

class OrganismGroupMemberType(SQLAlchemyObjectType):
    class Meta:
        model = OrganismGroupMember

class OrganismType(SQLAlchemyObjectType):
    class Meta:
        model = Organism
  
    organism_group_members = graphene.List(OrganismGroupMemberType)
    
    def resolve_organism_group_members(self, info):
      # Assuming there is a backref named 'organism' in GenomeModel
      return self.organism_group_members
    
class OrganismGroupType(SQLAlchemyObjectType):
    class Meta:
        model = OrganismGroup

class GrapheneDatasetTopicType(SQLAlchemyObjectType):
    class Meta:
        model = DatasetType

class GrapheneDatasetSourceType(SQLAlchemyObjectType):
    class Meta:
        model = DatasetSource

class GrapheneDatasetType(SQLAlchemyObjectType):
    class Meta:
        model = Dataset
    status = graphene.Field(DatasetStatusEnum)

class GenomeDatasetType(SQLAlchemyObjectType):
    class Meta:
        model = GenomeDataset
    
class GenomeType(SQLAlchemyObjectType):
    class Meta:
        model = Genome

    organism = graphene.Field(OrganismType)
    genome_datasets = graphene.List(GenomeDatasetType)
    

    def resolve_organism(self, info):
        return self.organism
      
    def resolve_assembly(self, info):
        return self.assembly

    def resolve_genome_datasets(self, info):
      return self.genome_datasets
    
class Query(graphene.ObjectType):

    genome_list = graphene.List(GenomeType, filters=GenomeFilterInput())

    def resolve_genome_list(self, info, filters=None):
        query = GenomeType.get_query(info)
        
           
        query = query.join(Genome.organism).join(Organism.organism_group_members).join(OrganismGroupMember.organism_group) \
                    .outerjoin(Genome.genome_datasets).join(GenomeDataset.dataset).join(Dataset.dataset_source).join(Dataset.dataset_type) \
        
        #default filter with organism group type to DIVISION
        query = query.filter(OrganismGroup.type == filters.organism_group_type)
  
        if filters:
          if filters.genome_uuid:
            query =  query.filter(Genome.genome_uuid.in_(filters.genome_uuid))
          
          if filters.organism_group: 
            query =  query.filter(OrganismGroup.name.in_(filters.organism_group))
            
          if filters.organism_name:
            ensembl_names = set(filters.organism_name) - set(filters.anti_organism_name) 
            if ensembl_names:
              query = query.filter(Genome.organism.has(Organism.ensembl_name.in_(ensembl_names)))
            else:
              query = query.filter(~Genome.organism.has(Organism.ensembl_name.in_(filters.anti_organism_name)))
          elif filters.anti_organism_name :
            query = query.filter(~Genome.organism.has(Organism.ensembl_name.in_(filters.anti_organism_name)))
          
          if filters.unreleased_genomes :
            
            query = query.filter(~Genome.genome_releases.any())
          
          if filters.released_genomes:
            query = query.filter(Genome.genome_releases.any())
            
          if filters.unreleased_datasets:
            query = query.filter(~GenomeDataset.ensembl_release.has())
  
          if filters.released_datasets:
            query = query.filter(GenomeDataset.ensembl_release.has())

          if filters.dataset_type:   
            query = query.filter(Genome.genome_datasets.any(DatasetType.name.in_(filters.dataset_type)))
          
          if filters.anti_dataset_type:   
            query = query.filter(
              ~Genome.genome_id.in_(
                  select([GenomeDataset.genome_id])
                  .join(Dataset)
                  .join(DatasetType)
                  .join(DatasetSource)
                  .where(
                      # DatasetSource.type == 'compara',
                      DatasetType.name.in_(filters.anti_dataset_type)
                  )
                  .distinct()
              )
          )
          
          if filters.dataset_source_type:   
            query = query.filter(Genome.genome_datasets.any(DatasetSource.type.in_(filters.dataset_source_type)))
        
        return query.all()

def list_to_string(data:list = []):
  formatted_data = ', '.join([f'"{element}"' for element in data])
  return f'[{formatted_data}]'

def get_genomes(
  metadata_db_uri     : graphene.String, 
  genome_uuid         : graphene.List = [],
  released_genomes    : graphene.Boolean = False,
  unreleased_genomes  : graphene.Boolean = False,
  organism_group_type : graphene.String = 'DIVISION',
  unreleased_datasets : graphene.Boolean =False,
  released_datasets   : graphene.Boolean =False,
  dataset_source_type : graphene.List = [],
  dataset_type        : graphene.List = [],
  anti_dataset_type   : graphene.List = [],
  organism_name       : graphene.List =[],
  organism_group      : graphene.List =[],
  anti_organism_name  : graphene.List=[], 
  query_param         : graphene.String = None, 
  
):

  schema = graphene.Schema(query=Query)
  DATABASE_URI = metadata_db_uri
  engine = create_engine(DATABASE_URI)
  session = sessionmaker(bind=engine)()
  
  if query_param is None:
    query_param = """
            genomeId
            genomeUuid
            productionName
            organism {
              commonName
              scientificName
              ensemblName
              organismGroupMembers{
                isReference
                organismGroup{
                  name
                  type
                }
              } 
          }
          assembly {
            assemblyUuid
            accession
            assemblyDefault
            level
            name
            ensemblName
          }
          genomeDatasets {
            isCurrent
            dataset {
              datasetUuid
                name
                label
                status
              datasetType {
                    topic,
                    name
              }
              datasetSource {
                  name
                  type
              }
            }
          }
    """

  query  = f"""
      {{
        genomeList(filters: {{
            genomeUuid: {list_to_string(genome_uuid)},
            unreleasedGenomes: { 'true' if unreleased_genomes else 'false' },
            releasedGenomes: { 'true' if released_genomes else 'false' },
            releasedDatasets: { 'true' if released_datasets else 'false' },
            unreleasedDatasets: { 'true' if unreleased_datasets else 'false' }, 
            datasetSourceType: {list_to_string(dataset_source_type)},
            organismGroupType: "{organism_group_type}",
            organismGroup: {list_to_string(organism_group)},
            datasetType: {list_to_string(dataset_type)},
            antiDatasetType: {list_to_string(anti_dataset_type)},
            organismName : {list_to_string(organism_name)}, 
            antiOrganismName : {list_to_string(anti_organism_name)}
            }}) {{
              
              {query_param}

          }}
        }}
      """
    
  result = schema.execute(query, context_value={'session': session}) 
  if result.errors is not None:
    raise ValueError(str(result.errors))
  for genome in result.data['genomeList']:
    yield genome

def main():  
  parser = argparse.ArgumentParser(
       prog='genome_factory.py',
      description='Fetch Ensembl genome info from new metadata API'
  )
  
  parser.add_argument('--genome_uuid', type=str, nargs='*', default=[], required=False, help='')        
  parser.add_argument('--released_genomes', default=False, required=False, help='')   
  parser.add_argument('--unreleased_genomes', default=False, required=False, help='') 
  parser.add_argument('--organism_group_type', type=str, default='DIVISION', required=False, help='')
  parser.add_argument('--organism_group', type=str, nargs='*', default=[], required=False, help='')
  parser.add_argument('--unreleased_datasets',  default=False, required=False, help='')
  parser.add_argument('--released_datasets', default=False, required=False, help='')  
  parser.add_argument('--dataset_source_type', type=str, nargs='*',  default=[], required=False, help='')
  parser.add_argument('--dataset_type', type=str, nargs='*', default=[], required=False, help='')
  parser.add_argument('--anti_dataset_type', type=str, nargs='*', default=[], required=False, help='')       
  parser.add_argument('--organism_name', type=str, nargs='*',  default=[], required=False, help='')      
  parser.add_argument('--anti_organism_name', type=str, nargs='*', default=[], required=False, help='') 
  parser.add_argument('--metadata_db_uri', type=str, required=True,  help='metadata db mysql uri, ex: mysql://ensro@localhost:3366/ensembl_genome_metadata')
  parser.add_argument( '--output', type=str, required=True,  help='output file ex: genome_info.json')
  
  args = parser.parse_args()
  with open(args.output, 'w') as json_output:
    for genome in get_genomes(metadata_db_uri=args.metadata_db_uri,  
                        genome_uuid=args.genome_uuid,
                        released_genomes=args.released_genomes,
                        unreleased_genomes=args.unreleased_genomes,
                        organism_group_type=args.organism_group_type,
                        organism_group=args.organism_group,
                        unreleased_datasets=args.unreleased_datasets,
                        released_datasets=args.released_datasets,
                        dataset_source_type=args.dataset_source_type,
                        dataset_type=args.dataset_type,
                        anti_dataset_type=args.anti_dataset_type,
                        organism_name=args.organism_name,
                        anti_organism_name=args.anti_organism_name,  
                        ):
      
      json.dump(genome, json_output)
      json_output.write("\n")
    
if __name__ == "__main__":
  main()
  