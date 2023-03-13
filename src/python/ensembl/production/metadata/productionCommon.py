import os
from enum import Enum
import logging 
from functools import reduce
from sqlalchemy import select, or_
from sqlalchemy.orm import Session
from typing import List, Optional, Union
from pydantic import BaseModel, root_validator, validator, constr, AnyUrl, DirectoryPath
from ensembl.database.dbconnection import DBConnection
from collections import defaultdict
from ensembl.core.models import Meta
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
  ens_version: Union[List[str], str] = os.environ.get('ENS_VERSION', [])
  eg_version:  Union[List[str], str] = os.environ.get('EG_VERSION', [])
  species:   Optional[Union[List[str], str]] = []  
  taxons:    Optional[Union[List[str], str]] = []   
  division:  Optional[Union[List[EnsemblDivisions], EnsemblDivisions]] = []
  run_all:   constr(regex='[01]') = 0
  antispecies: Optional[Union[List[str], str]] = []  
  antitaxons : Optional[Union[List[str], str]] = []  
  dbname     : Optional[Union[List[str], str]] = [] 
  group      : Optional[Union[List[DBType], DBType]] = ['core']
  meta_filters: Optional[dict] = {}
  metadata_db_url: Optional[AnyUrl] = os.environ.get('METADATA_DB_URL', '')
  nextflow: constr(regex='[01]') = 0
  dataflow: constr(regex='[1234567]') =  2
  base_path: Optional[DirectoryPath]
  coredb_url: Optional[AnyUrl] = os.environ.get('CORE_DB_URL')
  class Config:
    arbitrary_types_allowed = True

  
  @validator('metadata_db_url')
  def metadata_url(cls, value):
    return str(value)
  
  @validator('run_all', 'dataflow', 'nextflow')
  def str_to_int(cls, value):
    return int(value)
 
  @validator('division', 'group')
  def enum_to_str(cls, value):
    if  isinstance(value, str):
      return [value.name]   
    return [ div.name for div in value  ] 
  
  @root_validator
  def check_valid_list(cls, values):
    return  {k: [v] if isinstance(v, str) and k != 'metadata_db_url' else v for k, v in values.items()}
  
class RRParams(BaseModel):
  base_path: DirectoryPath
  coredb_url: Optional[AnyUrl] = os.environ.get('CORE_DB_URL')
  class Config:
    arbitrary_types_allowed = True
  
class BaseFactory():
  def __init__(self,**kwargs):
    params = ProductionParams(**kwargs)
    self.__dict__.update(params.dict())
    self._dbs = defaultdict(lambda: defaultdict(dict))
    self._compara_dbs = {}
    self._all_species = []
  
  @staticmethod
  def get_db_session(url:str):
    return DBConnection(url)
      
  @staticmethod
  def base_query(columns=['*']):
    meta_query = select(columns=columns).select_from(GenomeDatabase) \
        .join(Genome).join(Assembly).join(Organism).join(DataRelease).join(Division) 
    return meta_query

  def _base_filter(self, columns=[]):
    #TODO filter of the results based on dbname, species, antispecies, taxon etc similar to production speciesfactory
    #implementation for species, group, dbnames and division
    
    columns = [Assembly.assembly_accession.label("assembly_accession"), Assembly.assembly_name.label("assembly_name"), Division.name.label("division"),
               Organism.name.label('species'), GenomeDatabase.dbname.label('dbname'),GenomeDatabase.type.label('group')] if not len(columns) else columns
    
    #get base query  
    query = self.base_query(columns)
    
    if len(self.ens_version)==0 and len(self.eg_version)==0 :
      raise ValueError('ENS and EG versions missing,  provied them during initiation or export them as enviroment variables : ENS_VERSION=110; EG_VERSION=57')
    
    #apply the filter 
    if self.ens_version:
      query = query.filter(DataRelease.ensembl_version.in_( self.ens_version))
        
    if self.eg_version:     
      query = query.filter(DataRelease.ensembl_genomes_version.in_(self.eg_version))    
      
    if self.division:
      query = query.filter(Division.name.in_(self.division))       

    if self.group:
      query = query.filter(GenomeDatabase.type.in_(self.group))
      
    if self.dbname and not self.run_all:
      query = query.filter(GenomeDatabase.dbname.in_(self.dbname))
      
    if self.species and not self.run_all:
      query = query.filter(or_(Organism.name.in_(self.species), GenomeDatabase.dbname.in_(self.dbname) ))
    
    #filter antispecies and antitaxon
    query = query.filter(Organism.name.notin_(self.antispecies))
    return query
  
  def execute_query(self, query, url):
    #connect to  database
    db_connection = self.get_db_session(url)   
    with db_connection.session_scope() as session: 
     for result in session.execute(query).fetchall():
        yield result
        
class DBFactory(BaseFactory):
  """ Get Database Metadata information from ensembl metadata database

  Args:
      species (Optional[List[str]]): List of species names
      antispecies (Optional[List[str]]): List of species names not to include in the result
      dbname (Optional[List[str]]): List of database names
      group (Optional[List[str]]): List of database types ex: (core, variation, cdna, otherfeatures)
      division (Optional[List[str]]): List of Ensembl Divisions ex: (vertebrates, plants, metazoa, fungi, bacteria)
      ens_version (int): Ensembl release version  
      eg_version (int): Rapid release version 
      metadata_db_url (URL): metadata database mysql url  
      meta_filters (dict): A hashref with key-value pairs that are matched against meta_key and meta_value from the meta table.  
  """
  def __init__(self, **kwargs):
    super().__init__(**kwargs)
    
  def all_dbs_flow(self):
    pass 
    
class SpeciesFactory(DBFactory):
  """ Get Species Metadata information from ensembl metadata database

  Args:
      species (Optional[List[str]]): List of species names
      antispecies (Optional[List[str]]): List of species names not to include in the result
      dbname (Optional[List[str]]): List of database names
      group (Optional[List[str]]): List of database types ex: (core, variation, cdna, otherfeatures)
      division (Optional[List[str]]): List of Ensembl Divisions ex: (vertebrates, plants, metazoa, fungi, bacteria)
      ens_version (int): Ensembl release version  
      eg_version (int): Rapid release version 
      metadata_db_url (URL): metadata database mysql url  
      meta_filters (dict): A hashref with key-value pairs that are matched against meta_key and meta_value from the meta table.
      
  """ 
  def core_flow(self):
    columns = [Organism.name.label('species'), GenomeDatabase.dbname.label('dbname'),GenomeDatabase.type.label('group')]
    query = self._base_filter(columns)
    values = self.execute_query(query, self.metadata_db_url)
    
    if self.nextflow: #TODO write to the dataflow_2.json as standard flows for nexflow processor 
      return
    
    return values 
  
  def compara_flow(self):
    #TODO
    return {}   
  def variation_flow(self):
    #TODO
    return {}
  def regulation_flow(self):
    #TODO
    return {}
  
class RRDatafiles(SpeciesFactory):
  """ Get Species Datafiles From FTP Directory
  Args:
      species (Optional[List[str]]): List of species names
      dbname (Optional[List[str]]): List of database names
      group (Optional[List[str]]): List of database types ex: (core, variation, cdna, otherfeatures)
      division (Optional[List[str]]): List of Ensembl Divisions ex: (vertebrates, plants, metazoa, fungi, bacteria)
      ens_version (int): Ensembl release version  
      eg_version (int): Rapid release version 
      metadata_db_url (URL): metadata database mysql url  
      meta_filters (dict): A hashref with key-value pairs that are matched against meta_key and meta_value from the meta table.   
  """ 
  
  def _get_annotations_source_info(self, species:str, dbname: str, coredb_url: str, meta_keys=[
                                              'species.annotation_source',
                                              'species.display_name',                               
                                              'genebuild.last_geneset_update',
                                              'genebuild.initial_release_date']): 
    """
      Fetch Meta key annotation_source information from species core db 
      Args:
          dbname (str): Ensembl Metadata database name
          coredb_url (str): Mysql url for species core database
          meta_keys (list): List of metakeys 
          
      Returns:
          dictionary: annotation source information
    """     
    coredb_url_conn_str = os.path.join(coredb_url, dbname)   
    db_connection =  self.get_db_session(coredb_url_conn_str)
    with db_connection.session_scope() as session:
      
      #get species id to support collection dbs
      species_query = select(Meta.species_id).filter(Meta.meta_value == species).filter(Meta.meta_key == 'species.production_name')
      species_id    = dict(session.execute(species_query).one())['species_id'] 
      
      core_query = select(Meta.meta_key, Meta.meta_value).filter(Meta.meta_key.in_(meta_keys)).filter(Meta.species_id==species_id)
      
      result =  dict(session.execute(core_query).all())
      
      return result 
  
  @staticmethod      
  def update_datafile(result,keys, value):
    current = result
    for key in keys[:-1]:
        current = current.setdefault(key, {})

    if keys[-1] in current:
        current[keys[-1]].append(value)
    else:
        current.setdefault(keys[-1], []).append(value)
    return result  
      
  def _generate_datafiles(self, base_path:str, species_name:str):
    species_datafile = {}
    for dirpath, dirnames, filenames in os.walk(base_path):
      for datafile in filenames:
        source_dir = "".join(dirpath.split(f"/{species_name}")[1:]).split('/')[1:] 
        self.update_datafile(species_datafile, source_dir, os.path.join(base_path, datafile))
           
    return {species_name: species_datafile}
  
  @staticmethod
  def set_annot_source(**kargs):
    kargs['species.display_name'] = "_".join(kargs.get('species.display_name','').split(' ')[0:2]) #Zootoca vivipara (Common lizard) - GCA_011800845.1  
    kargs['genebuild.initial_release_date'] = kargs.get('genebuild.initial_release_date','').replace('-','_') if kargs.get('genebuild.initial_release_date', None) else ''
    kargs['genebuild.last_geneset_update'] = kargs.get('genebuild.last_geneset_update', '').replace('-','_') if kargs.get('genebuild.initial_release_date', None) else ''
    kargs['species.annotation_source']  = 'ensembl' if kargs.get('species.annotation_source', '') == '' else kargs.get('species.annotation_source', '')
    return kargs
  
  def get_species_datafiles(self, species:str=None, dbname:str=None, base_path:DirectoryPath=None, 
                            coredb_url:str=None, ens_version:int=None)->dict:
      
    try:
      species     = "".join(self.species[:1]) if species is None else species
      base_path   = self.base_path   if base_path is None else base_path
      coredb_url  = self.coredb_url  if coredb_url is None else coredb_url
      ens_version = self.ens_version if ens_version is None else ens_version
      
      #construct dbname from species name if dname is not provided, this works for rr-species only  
      dbname      = f"{species}_core_{ens_version}_1" if dbname is None else dbname
      species_annot_info = self._get_annotations_source_info(species, dbname, coredb_url)
      species_annot_info = self.set_annot_source(**species_annot_info)
      
      #check base path contain species directory
      base_path = os.path.join(base_path, "species")
      if not os.path.exists(base_path):
        raise ValueError("No species dir in the provided base_path: {base_path}")
      species_datafile = self._generate_datafiles(base_path,  species_annot_info['species.display_name'])
      return species_datafile
      
    except Exception as e:
      raise ValueError(str(e))
    
  def get_datafiles(self, coredb_url:str=None, base_path:str=None):
    
    try:
      
      base_path   = self.base_path if base_path is None else base_path
      coredb_url  = self.coredb_url if coredb_url is None else coredb_url
            
      #fetch all species form speciesfactory coreflow 
      for dataflow in self.core_flow():
        dataflow_info = dict(dataflow)
        species_datafile = self.get_species_datafiles(species=dataflow_info['species'], dbname=dataflow_info['dbname'], 
                                  coredb_url=coredb_url, base_path=base_path
                                  )
       
        yield (species_datafile) 
    except Exception as e:
      raise ValueError(str(e))
    
    return ()

#nextflow check pipeline used this function remove it after removing the dependencies                    
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

