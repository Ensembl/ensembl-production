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
from graphene_sqlalchemy.converter import convert_sqlalchemy_type
from sqlalchemy import select
from sqlalchemy import JSON
from ensembl.production.metadata.api.models.genome import Genome, GenomeDataset
from ensembl.production.metadata.api.models.organism import Organism, OrganismGroup, OrganismGroupMember
from ensembl.production.metadata.api.models.assembly import Assembly
from ensembl.production.metadata.api.models.dataset import DatasetType, Dataset, DatasetSource, DatasetStatus
from ensembl.production.metadata.api.hive.dataset_factory import DatasetFactory

from ensembl.database import DBConnection

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


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
    
    filter_on = graphene.String()
    @convert_sqlalchemy_type.register(JSON)
    def convert_column_to_string(type, column, registry=None):
        return graphene.String()



class GrapheneDatasetSourceType(SQLAlchemyObjectType):
    class Meta:
        model = DatasetSource


class GrapheneDatasetType(SQLAlchemyObjectType):
    class Meta:
        model = Dataset
    

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
        if dataset_type_filter:
            filtered_datasets = (
                info.context['session']
                .query(GenomeDataset)
                .join(Dataset)
                .filter(GenomeDataset.genome_id == self.genome_id)
                .filter(Dataset.dataset_type.has(DatasetType.name.in_(dataset_type_filter)))
                .all()
            )
            return filtered_datasets
        
        return self.genome_datasets


class GenomeFilterInput(graphene.InputObjectType):
    genome_uuid = graphene.List(graphene.String, default_value=[], required=False)
    released_genomes = graphene.Boolean(default_value=False, required=False)
    unreleased_genomes = graphene.Boolean(default_value=False, required=False)
    division = graphene.List(graphene.String, default=[], required=False)
    unreleased_datasets = graphene.Boolean(default_value=False)
    released_datasets = graphene.Boolean(default_value=False)
    dataset_source_type = graphene.List(graphene.String, default=[], required=False)
    dataset_type = graphene.List(graphene.String, default=[], required=False)
    anti_dataset_type = graphene.List(graphene.String, default=[], required=False)
    species = graphene.List(graphene.String, default=[], required=False)
    anti_species = graphene.List(graphene.String, default=[], required=False)
    biosample_id = graphene.List(graphene.String, default=[], required=False)
    anti_biosample_id = graphene.List(graphene.String, default=[], required=False)
    dataset_status = graphene.List(graphene.String, default_value=["Submitted"], required=False)
    run_all = graphene.Int(default_value=0, required=False)
    batch_size = graphene.Int(default_value=50, required=False)
    organism_group_type = graphene.String(default_value="DIVISION", required=False)
    query_param = graphene.String(default_value="", required=False)
    query = graphene.String(default_value="", required=False)
    
    def __init__(self, **kwargs):
        
        declared_fields = [attrib for attrib in GenomeFilterInput.__dict__.keys() if not attrib.startswith('_')]
        invalid_fields = set(kwargs.keys()) - set(declared_fields)
        if invalid_fields:
            raise ValueError(f"Invalid field(s): {', '.join(invalid_fields)}")
        
        required_fields = [field for field in declared_fields
                           if getattr(GenomeFilterInput, field).kwargs.get('required') and
                           'default_value' not in getattr(GenomeFilterInput, field).kwargs
                           ]
        
        if required_fields:
            raise ValueError(f"Required field(s): {', '.join(required_fields)}")
        
        # set default values
        if kwargs.keys():
            for field in declared_fields:
                default_val = getattr(GenomeFilterInput, field).kwargs.get('default_value', None)
                if field not in kwargs.keys() and default_val:
                    kwargs[field] = default_val
        
        super().__init__(**kwargs)


class BaseQuery(graphene.ObjectType):
    @classmethod
    def add_query_filters(self, query, filters):
        """
        
        Args:
            query (_type_): _description_
            filters (_type_): _description_
        """
        query = query.join(Genome.organism).join(Organism.organism_group_members) \
            .join(OrganismGroupMember.organism_group) \
            .outerjoin(Genome.genome_datasets).join(GenomeDataset.dataset) \
            .join(Dataset.dataset_source).join(Dataset.dataset_type)
        
        # default filter with organism group type to DIVISION
        query = query.filter(OrganismGroup.type == filters.organism_group_type)
        if filters.run_all:
            filters.division = ['EnsemblBacteria',
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
                    ensembl_divisions = ['Ensembl' + pattern.sub('', d).capitalize() for d in ensembl_divisions if d]
                
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
        
        return query


class GenomeQuery(BaseQuery):
    genome_list = graphene.List(GenomeType, filters=GenomeFilterInput())
    
    def resolve_genome_list(self, info, filters=None):
        query = GenomeType.get_query(info)
        info.context['filters'] = filters
        query = GenomeQuery.add_query_filters(query, filters)
        return query


class DatasetQuery(BaseQuery):
    pass


class GenomeFetcher:

    @staticmethod
    def get_query_params():
        return """
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
    
    def get_query(self, filters, query_param):
        return f"""
      {{
          genomeList(filters: {{
          genomeUuid: {self.list_to_string(filters.kwargs.get('genome_uuid', []))},
          unreleasedGenomes: {'true' if filters.kwargs.get('unreleased_genomes', None) else 'false'},
          releasedGenomes: {'true' if filters.kwargs.get('released_genomes', None) else 'false'},
          releasedDatasets: {'true' if filters.kwargs.get('released_datasets', None) else 'false'},
          unreleasedDatasets: {'true' if filters.kwargs.get('unreleased_datasets', None) else 'false'},
          datasetSourceType: {self.list_to_string(filters.kwargs.get('dataset_source_type', []))},
          organismGroupType: "{filters.kwargs.get('organism_group_type', 'DIVISION')}",
          division: {self.list_to_string(filters.kwargs.get('division', []))},
          datasetType: {self.list_to_string(filters.kwargs.get('dataset_type', []))},
          antiDatasetType: {self.list_to_string(filters.kwargs.get('anti_dataset_type', []))},
          species : {self.list_to_string(filters.kwargs.get('species', []))}, 
          antiSpecies : {self.list_to_string(filters.kwargs.get('anti_species', []))},
          biosampleId : {self.list_to_string(filters.kwargs.get('biosample_id', []))},
          antiBiosampleId : {self.list_to_string(filters.kwargs.get('anti_biosample_id', []))},
          batchSize : {filters.kwargs.get('batch_size', 50)},
          runAll : {filters.kwargs.get('run_all', 0)},
          datasetStatus : {self.list_to_string(filters.kwargs.get('dataset_status', ["Submitted"]))}

          }}) {{

          {query_param}

          }}
      }}
    """
    
    @staticmethod
    def list_to_string(data):
        if data is None:
            data = []
        formatted_data = ', '.join([f'"{element}"' for element in data])
        return f'[{formatted_data}]'
    
    def get_genomes(self,
                    metadata_db_uri,
                    query_schema=GenomeQuery,
                    update_dataset_status="",
                    **filters: GenomeFilterInput
                    ):
        
        # validate the params
        logger.info(f'Get Genomes with filters {filters}')
        filters = GenomeFilterInput(**filters)
        query_param = filters.kwargs.get('query_param', "")
        query = filters.kwargs.get('query', "")
        metadata_db = DBConnection(metadata_db_uri)
        dataset_factory = DatasetFactory()


        if not query_param:
            query_param = self.get_query_params()
        
        if not query:
            query = self.get_query(filters, query_param)
        
        # get dynamic query schema, default : GenomeQuery
        schema = graphene.Schema(query=query_schema)
        
        # fetch genome results
        with metadata_db.session_scope() as session:
            result = schema.execute(query, context_value={'session': session})
            if result.errors is not None:
                raise ValueError(str(result.errors))
        
        try:
            with metadata_db.session_scope() as session:
                for genome in result.data.get('genomeList', []):
                    #check if dataset for genome is updated successfully
                    process_genome = False
                    
                    if update_dataset_status:
                        for dataset in genome.get('genomeDatasets', []):
                            _, status = dataset_factory.update_dataset_status(dataset.get('dataset').get('datasetUuid', None), session, update_dataset_status)

                            if update_dataset_status == status:
                                process_genome = True
                                dataset.get('dataset')['status'] = status
                                logger.info(
                                    f"Updated Dataset status for dataset uuid: {dataset.get('dataset')['datasetUuid']} from {update_dataset_status} to {status}  for genome {genome['genomeUuid']}"
                                )
                            else:
                                logger.warn(
                                    f"Cannot update status for dataset uuid: {dataset.get('dataset')['datasetUuid']} {update_dataset_status} to {status}  for genome {genome['genomeUuid']}"
                                )

                        if process_genome:
                            yield genome


                    #NOTE: when update_dataset_status is empty, returns all the genome irrespective to its dependencies and status
                    else:
                        yield genome

        except Exception as e:
            raise ValueError(str(e))
        

def main():
    parser = argparse.ArgumentParser(
        prog='genomeFactory.py',
        description='Fetch Ensembl genome info from the new metadata API'
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
                        choices=['Submitted', 'Processing', 'Processed', 'Released'], required=False,
                        help='List of dataset statuses to filter the query. Default is an empty list.')
    parser.add_argument('--update_dataset_status', default="", required=False, choices=['Submitted', 'Processing', 'Processed', 'Released', ''],
                        help='Update the status of the selected datasets to the specified value. ')
    parser.add_argument('--metadata_db_uri', type=str, required=True,
                        help='metadata db mysql uri, ex: mysql://ensro@localhost:3366/ensembl_genome_metadata')
    parser.add_argument('--output', type=str, required=True, help='output file ex: genome_info.json')
    
    args = parser.parse_args()
    
    meta_details = re.match(r"mysql:\/\/.*:(.*?)@(.*?):\d+\/(.*)", args.metadata_db_uri)
    with open(args.output, 'w') as json_output:
        logger.info(f'Connecting Metadata DB: host:{meta_details.group(2)} , dbname:{meta_details.group(3)}')
        
        genome_fetcher = GenomeFetcher()
        
        logger.info(f'Writing Results to {args.output}')
        
        for genome in genome_fetcher.get_genomes(
                metadata_db_uri=args.metadata_db_uri,
                query_schema=GenomeQuery,
                update_dataset_status=args.update_dataset_status,
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
        
        logger.info(f'Completed !')


if __name__ == "__main__":
    logger.info('Fetching Genome Information From New Metadata Database')
    main()
