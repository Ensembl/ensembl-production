import os
from enum import Enum
import logging 
from sqlalchemy import select
from typing import List, Optional, Union
from pydantic import BaseModel, root_validator, validator, constr, AnyUrl
from ensembl.database.dbconnection import DBConnection
from ensembl.production.metadata.model import Genome, GenomeDatabase, Organism, DataRelease, DataReleaseDatabase, Division, Assembly

logging.getLogger('sqlalchemy.engine').setLevel(logging.WARNING)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)     


def get_db_session(url) :
  """Provide the DB session scope with context manager

  Args:
      url (URL): Mysql URI string mysql://user:pass@host:port/database

  Returns:
      context: dbconnection with session scope
  """  
  return  DBConnection(url)

class Flow(str, Enum):
  all_species_flow = 1
  core_flow = 2
  chromosome_flow = 3 # TODO: need to fetch the core db to get karyotype, expecying metadata-api will provide this info  
  variation = 4
  compara_flow = 5 
  regulation_flow = 6
  otherfeatures_flow = 7
     
class EnsemblDivisions(str, Enum):
 EnsemblVertebrates = 'vertebrates'
 EnsemblProtists    = 'protists'       
 EnsemblFungi       = 'fungi'              
 EnsemblMetazoa     = 'metazoa'           
 EnsemblPlants      = 'plants'         
 EnsemblBacteria    = 'bacteria' 
 
class DBType(str, Enum):
  core          = 'core'
  funcgen       = 'funcgen'
  variation     = 'variation'
  otherfeatures = 'otherfeatures'
  rnaseq        = 'rnaseq'
  cdna          = 'cdna'
class ProductionParams(BaseModel):
  ens_version: Union[List[str], str] = os.environ.get('ENS_VERSION')
  eg_version:  Union[List[str], str] = os.environ.get('EG_VERSION')
  species:   Optional[Union[List[str], str]] = []  
  taxons:    Optional[Union[List[str], str]] = []   
  division:  Optional[Union[List[EnsemblDivisions], EnsemblDivisions]] = []
  run_all:   constr(regex='[01]') = 0
  antispecies: Optional[Union[List[str], str]] = []  
  antitaxons : Optional[Union[List[str], str]] = []  
  dbname     : Optional[Union[List[str], str]] = [] 
  group      : Optional[Union[List[DBType], DBType]] = []
  meta_filters: Optional[dict] = {}
  metadata_db_url: AnyUrl
  nextflow: constr(regex='[01]') = 0
  dataflow: constr(regex='[1234567]') =  2
  
  @validator('metadata_db_url')
  def metadata_url(cls, value):
    return str(value)
  
  @validator('run_all', 'dataflow', 'nextflow')
  def str_to_int(cls, value):
    return int(value)
 
  @validator('division', 'group')
  def enum_to_str(cls, value):
    if  isinstance(value, str):
      return [value.value]   
    return [ div.name for div in value  ]
   
  @root_validator
  def check_valid_list(cls, values):
    return  {k: [v] if isinstance(v, str) and k != 'metadata_db_url' else v for k, v in values.items()}



class SpeciesFactory(ProductionParams):
  """_summary_

  Args:
      ProductionParams (_type_): _description_
  """ 
   
  def __init__(self, *args, **kwargs):
    # Perform some custom initialization logic here
    super().__init__(*args, **kwargs)
    
  def core_flow(self):
    print(self.species)
    return 1
    



                    
def get_all_species_by_division(ens_version: int, eg_version: int, metadata_uri: str, division: list):
  """Fetch species names from ensembl_metadata

  Args:
      ens_version (int): ensembl release version
      eg_version (int): ensemblgenomes release version 
      metadata_uri (str): mysql uri for metadata database
      division (str): ensembl divisions
  """
  #, Organism.scientific_name, Organism.display_name, GenomeDatabase.dbname, GenomeDatabase.type,
  db_connection =  get_db_session(metadata_uri)
  with db_connection.session_scope() as session:
      meta_query = select(
              Organism.name, Division.name ).select_from(Genome) \
        .join(Organism).join(DataRelease).join(Division) \
      .filter(DataRelease.ensembl_version.in_(ens_version)) \
      .filter(DataRelease.ensembl_genomes_version.in_(eg_version)) \
      .filter(Division.name.in_(division))
      
      #prepare species info {'EnsemblVertebrates: []'}
      species_info = { d : [] for d in division }
      for result in session.execute(meta_query): 
          info = dict(result)
          species_info[info['name_1']].append(info['name'])
      
      return species_info


