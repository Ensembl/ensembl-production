#!/usr/bin/env python
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

'''
Fetch Genome Info from the new metadata api
'''
import json
import argparse
import logging
import re
import graphene
from graphene_sqlalchemy import SQLAlchemyObjectType

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select
from sqlalchemy import update

from ensembl.database import DBConnection
from ensembl.production.metadata.api.models.genome import Genome, GenomeDataset
from ensembl.production.metadata.api.models.organism import Organism, OrganismGroup, OrganismGroupMember
from ensembl.production.metadata.api.models.assembly import Assembly
from ensembl.production.metadata.api.models.dataset import DatasetType, Dataset, DatasetSource

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)


# Define the Enum type
class DatasetStatusEnum(graphene.Enum):
  SUBMITTED = 'Submitted'
  PROCESSING = 'Processing'
  PROCESSED = 'Processed'
  
  
class GenomeFilterInput(graphene.InputObjectType):
  genome_uuid = graphene.List(graphene.String)
  released_genomes = graphene.Boolean(default_value=False)
  unreleased_genomes = graphene.Boolean(default_value=False)
  organism_group_type = graphene.String(default_value='DIVISION')
  division = graphene.List(graphene.String, default=[])
  unreleased_datasets = graphene.Boolean(default_value=False)
  released_datasets = graphene.Boolean(default_value=False)
  dataset_source_type = graphene.List(graphene.String, default=[])
  dataset_type = graphene.List(graphene.String, default=[])
  anti_dataset_type = graphene.List(graphene.String, default=[])
  species = graphene.List(graphene.String, default=[])
  anti_species = graphene.List(graphene.String, default=[])
  biosample_id = graphene.List(graphene.String, default=[])
  anti_biosample_id = graphene.List(graphene.String, default=[])
  dataset_status = graphene.List(graphene.String, default_value=[])
  batch_size = graphene.Int(default_value=50)
  run_all = graphene.Int(default_value=0)


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
    filters = info.context.get('filters')
    dataset_type_filter = filters.get('dataset_type', [])
    # Filter datasets based on dataset_type
    filtered_datasets = (
      info.context['session']
      .query(GenomeDataset)
      .join(Dataset)
      .filter(GenomeDataset.genome_id == self.genome_id)
      .filter(Dataset.dataset_type.has(DatasetType.name.in_(dataset_type_filter)))
      .all()
    )

    return filtered_datasets


class Query(graphene.ObjectType):
  genome_list = graphene.List(GenomeType, filters=GenomeFilterInput())

  def resolve_genome_list(self, info, filters=None):

    info.context['filters'] = filters

    query = GenomeType.get_query(info)

    query = query.join(Genome.organism).join(Organism.organism_group_members).join(
      OrganismGroupMember.organism_group) \
      .outerjoin(Genome.genome_datasets).join(GenomeDataset.dataset).join(Dataset.dataset_source).join(
      Dataset.dataset_type)

    # default filter with organism group type to DIVISION
    query = query.filter(OrganismGroup.type == filters.organism_group_type)
    if filters.run_all :
      filters.division =  [ 'EnsemblBacteria',
                            'EnsemblVertebrates',
                            'EnsemblPlants',
                            'EnsemblProtists',
                            'EnsemblMetazoa',
                            'EnsemblFungi',
                          ]
    if filters:
      
      if filters.genome_uuid:
        query = query.filter(Genome.genome_uuid.in_(filters.genome_uuid))
      
      if filters.division:
        ensembl_divisions = filters.division
        
        if filters.organism_group_type == 'DIVISION':
          pattern = re.compile(r'^(ensembl)?', re.IGNORECASE)
          ensembl_divisions = [ 'Ensembl' + pattern.sub('', d).capitalize() for d in ensembl_divisions if d ]
          
        query = query.filter(OrganismGroup.name.in_(ensembl_divisions))

      if filters.species:
        species = set(filters.species) - set(filters.anti_species)

        if species:
          query = query.filter(Genome.production_name.in_(filters.species))
        else:
          query = query.filter(~Genome.production_name.in_(filters.anti_species))

      elif filters.anti_species:
        query = query.filter(~Genome.production_name.in_(filters.anti_species))

      if filters.biosample_id:

        biosample_id = set(filters.biosample_id) - set(filters.anti_biosample_id)

        if biosample_id:
          query = query.filter(Genome.organism.has(Organism.biosample_id.in_(biosample_id)))
        else:
          query = query.filter(~Genome.organism.has(Organism.biosample_id.in_(filters.anti_biosample_id)))

      elif filters.anti_biosample_id:
        query = query.filter(~Genome.organism.has(Organism.biosample_id.in_(filters.anti_biosample_id)))

      if filters.unreleased_genomes:
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

      if filters.dataset_status:
        query = query.filter(Dataset.status.in_(filters.dataset_status))

      if filters.dataset_source_type:
        query = query.filter(Genome.genome_datasets.any(DatasetSource.type.in_(filters.dataset_source_type)))

      if filters.batch_size:
        query = query.group_by(Genome.genome_id).limit(filters.batch_size)

    for result in query.all():
      yield result


def list_to_string(data: list = []):
  formatted_data = ', '.join([f'"{element}"' for element in data])
  return f'[{formatted_data}]'


def get_genomes(
  metadata_db_uri: graphene.String,
  genome_uuid: graphene.List = [],
  released_genomes: graphene.Boolean = False,
  unreleased_genomes: graphene.Boolean = False,
  organism_group_type: graphene.String = 'DIVISION',
  unreleased_datasets: graphene.Boolean = False,
  released_datasets: graphene.Boolean = False,
  dataset_source_type: graphene.List = [],
  dataset_type: graphene.List = [],
  anti_dataset_type: graphene.List = [],
  species: graphene.List = [],
  anti_species: graphene.List = [],
  biosample_id: graphene.List = [],
  anti_biosample_id: graphene.List = [],
  division: graphene.List = [],
  batch_size: graphene.Int = '50',
  run_all: graphene.Int = 0,
  dataset_status: graphene.String = ['Submitted'],
  update_dataset_status: graphene.String = None,
  query_param: graphene.String = None,

):
  schema = graphene.Schema(query=Query)
  metadata_db = DBConnection(metadata_db_uri)

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

  query = f"""
      {{
        genomeList(filters: {{
        genomeUuid: {list_to_string(genome_uuid)},
        unreleasedGenomes: {'true' if unreleased_genomes else 'false'},
        releasedGenomes: {'true' if released_genomes else 'false'},
        releasedDatasets: {'true' if released_datasets else 'false'},
        unreleasedDatasets: {'true' if unreleased_datasets else 'false'}, 
        datasetSourceType: {list_to_string(dataset_source_type)},
        organismGroupType: "{organism_group_type}",
        division: {list_to_string(division)},
        datasetType: {list_to_string(dataset_type)},
        antiDatasetType: {list_to_string(anti_dataset_type)},
        species : {list_to_string(species)}, 
        antiSpecies : {list_to_string(anti_species)},
        biosampleId : {list_to_string(biosample_id)}, 
        antiBiosampleId : {list_to_string(anti_biosample_id)},
        batchSize : {batch_size},
        runAll : {run_all},
        datasetStatus : {list_to_string(dataset_status)}

        }}) {{

          {query_param}

          }}
        }}
      """

  # fetch genome results
  with metadata_db.session_scope() as session:
    result = schema.execute(query, context_value={'session': session})
    if result.errors is not None:
      raise ValueError(str(result.errors))
    # update dataset status
    if update_dataset_status:
      session.query(Dataset).filter(Dataset.dataset_uuid.in_(
        [dataset['dataset']['datasetUuid'] for genomedataset in result.data['genomeList'] for dataset in
         genomedataset['genomeDatasets']])).update(
        {'status': update_dataset_status}, synchronize_session=False
      )
      session.commit()
    # yield genome results
    for genome in result.data['genomeList']:
      yield genome


def main():
  parser = argparse.ArgumentParser(
    prog='genomeFactory.py',
    description='Fetch Ensembl genome info from new metadata API'
  )

  parser.add_argument('--genome_uuid', type=str, nargs='*', default=[], required=False,
                      help='List of genome UUIDs to filter the query. Default is an empty list.')
  parser.add_argument('--released_genomes', default=False, required=False,
                      help='Include only released genomes in the query. Default is False.')
  parser.add_argument('--unreleased_genomes', default=False, required=False,
                      help='Include only unreleased genomes in the query. Default is False.')
  parser.add_argument('--organism_group_type', type=str, default='DIVISION', required=False,
                      help='Organism group type to filter the query. Default is "DIVISION"')
  parser.add_argument('--division', type=str, nargs='*', default=[], required=False,
                      help='List of organism group names to filter the query. Default is an empty list.')
  parser.add_argument('--unreleased_datasets', default=False, required=False,
                      help='Include only genomes with unreleased datasets in the query. Default is False.')
  parser.add_argument('--released_datasets', default=False, required=False,
                      help='Include only genomes with released datasets in the query. Default is False.')
  parser.add_argument('--dataset_source_type', type=str, nargs='*', default=[], required=False,
                      help='List of dataset source types to filter the query. Default is an empty list.')
  parser.add_argument('--dataset_type', type=str, nargs='*', default=[], required=False,
                      help='List of dataset types to filter the query. Default is an empty list.')
  parser.add_argument('--anti_dataset_type', type=str, nargs='*', default=[], required=False,
                      help='Include genomes which dont have given dataset names. Default is an empty list.')
  parser.add_argument('--species', type=str, nargs='*', default=[], required=False,
                      help='List of Species Production names to filter the query. Default is an empty list.')
  parser.add_argument('--anti_species', type=str, nargs='*', default=[], required=False,
                      help='List of Species Production names to exclude from the query. Default is an empty list.')
  parser.add_argument('--biosample_id', type=str, nargs='*', default=[], required=False,
                      help='List of biosample ids to filter the query. Default is an empty list.')
  parser.add_argument('--anti_biosample_id', type=str, nargs='*', default=[], required=False,
                      help='List of biosample ids to exclude from the query. Default is an empty list.')
  parser.add_argument('--batch_size', type=int, default=50, required=False,
                      help='Number of results to retrieve per batch. Default is 50.')
  parser.add_argument('--run_all', type=int, default=0, required=False,
                      help='Fetch Genomes for all default ensembl division. Default is 0, ex: EnsemblVertebrates|EnsemblPlants|EnsemblBacteria')
  parser.add_argument('--dataset_status', type=str, nargs='*', default=[],
                      choices=['Submitted', 'Processing', 'Processed'], required=False,
                      help='List of dataset statuses to filter the query. Default is an empty list.')
  parser.add_argument('--update_dataset_status', type=str, default='Processing',
                      choices=['Submitted', 'Processing', 'Processed'], required=False,
                      help='Update the status of the selected datasets to the specified value. ')
  parser.add_argument('--metadata_db_uri', type=str, required=True,
                      help='metadata db mysql uri, ex: mysql://ensro@localhost:3366/ensembl_genome_metadata')
  parser.add_argument('--output', type=str, required=True, help='output file ex: genome_info.json')

  args = parser.parse_args()
  with open(args.output, 'w') as json_output:
    for genome in get_genomes(metadata_db_uri=args.metadata_db_uri,
                              genome_uuid=args.genome_uuid,
                              released_genomes=args.released_genomes,
                              unreleased_genomes=args.unreleased_genomes,
                              organism_group_type=args.organism_group_type,
                              division=args.division,
                              unreleased_datasets=args.unreleased_datasets,
                              released_datasets=args.released_datasets,
                              dataset_source_type=args.dataset_source_type,
                              dataset_type=args.dataset_type,
                              anti_dataset_type=args.anti_dataset_type,
                              species=args.species,
                              anti_species=args.anti_species,
                              biosample_id=args.biosample_id,
                              anti_biosample_id=args.anti_biosample_id,
                              batch_size=args.batch_size,
                              run_all=args.run_all,
                              dataset_status=args.dataset_status,
                              update_dataset_status=args.update_dataset_status,
                              query_param="""
                                    genomeUuid
                                    productionName
                                    organism {
                                        commonName
                                        biosampleId
                                        organismGroupMembers{
                                          isReference
                                          organismGroup{
                                            name
                                            type
                                          }
                                      } 
                                    }
                                    genomeDatasets {
                                        dataset {
                                            datasetUuid
                                            name
                                            status
                                            datasetSource {
                                                name
                                                type
                                            }
                                        }
                                    }
                                """
                              ):
      json.dump(genome, json_output)
      json_output.write("\n")


if __name__ == "__main__":
  main()
