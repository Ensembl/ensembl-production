from sqlalchemy import select
from ensembl.database.dbconnection import DBConnection
from ensembl.production.metadata.model import Genome, GenomeDatabase, Organism, DataRelease, DataReleaseDatabase, Division, Assembly
import logging 


logging.getLogger('sqlalchemy.engine').setLevel(logging.WARNING)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)        


def get_db_session(url ) :
    """Provide the DB session scope with context manager

    Args:
        url (URL): Mysql URI string mysql://user:pass@host:port/database
    """   
    return  DBConnection(url)

                    
def get_all_species_by_division(ens_version: int, eg_version: int, metadata_uri: str, division: list):
    """Fetch species names from ensembl_metadata

    Args:
        ens_version (int): _description_
        eg_version (int): _description_
        metadata_uri (str): _description_
        division (str): _description_
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

def species_factory(metadata_params: dict):    
    """ Get Species Metadata information from ensembl metadata database

    Args:
        species_list (Optional[List[str]]): List of species names
        database_list (Optional[List[str]]): List of database names 
        release_version (int): Ensembl release version 
        eg_version (int): Rapid release version
        core_db_url (URL): Core database mysql url 
        metadata_db_url (URL): metadata database mysql url  
    """    
    db_connection =  get_db_session(metadata_params.metadata_url)
    with db_connection.session_scope() as session:
        meta_query = select(Assembly.assembly_accession.label("assembly_accession"), Assembly.assembly_name,
               Organism.name, Organism.scientific_name, Organism.display_name, Organism.species_taxonomy_id, Organism.strain,
               Genome.genebuild, GenomeDatabase.dbname,GenomeDatabase.type, DataRelease.release_date).select_from(GenomeDatabase) \
         .join(Genome).join(Assembly).join(Organism).join(DataRelease).join(Division) \
        .filter(DataRelease.ensembl_version.in_( metadata_params.release_version) ) \
        .filter(DataRelease.ensembl_genomes_version.in_(metadata_params.rapid_version))
        
              
        if metadata_params.species_names:
            meta_query = meta_query.filter(
                Organism.name.in_(metadata_params.species_names)
            )
        
        if metadata_params.database_names:
            meta_query = meta_query.filter(
                GenomeDatabase.dbname.in_(metadata_params.database_names)
            )
        
        for result in session.execute(meta_query): 
            species_info = dict(result)
            yield species_info
    
def get_genome_info(ens_version: int, eg_version: int, 
                metadata_url: str, dbtype=["core"],  
                species: list=[], division: list=[]):    
    """
    Genome Information for Ensembl Species
    Args:
        ens_version (int): Ensembl Release Version 
        eg_version (int): Ensembl Genomes Release Version
        metadata_uri (str): MetaData Database Mysql Url  
        species_name (str): Species name 
        division (str): Ensembl Division
        dbtype (str): Ensembl Database Type (default: core)

    Yields:
        dict: genome information
            species (str)   : Ensembl species production name ,
            group (str)     : Ensembl Database type,
            genome_id (str) : Ensembl genome ID (combination species id and assembly accession),
            gca (str)       : Assembly Accession,
            level (str)     : Assembly level,
            assembly_default (str) : Assembly Default,
            assembly_ucsc (str) : Asembly UCSC Version name,
            dbname (str)    : Ensembl Database Name,
            version (str)   : Assembly Version,
            division (str)  : Ensembl Division,
            species_id (str): Ensembl Species ID,
                       
        
    """     
    db_connection =  get_db_session(metadata_url)
    with db_connection.session_scope() as session:
        meta_query = select(Organism.name.label("species"), GenomeDatabase.type.label("group"),
                    (Organism.name + '_' + Assembly.assembly_accession).label("genome_id"),        
                    Assembly.assembly_accession.label("gca"),Assembly.assembly_level.label("level"),
                    Assembly.assembly_default, Assembly.assembly_name.label("version"), Assembly.assembly_ucsc,
                    Organism.scientific_name, Organism.display_name, Organism.species_taxonomy_id, Organism.strain,
                    Genome.genebuild, GenomeDatabase.dbname, DataRelease.release_date, Division.name.label("division"), 
                    Organism.organism_id.label("species_id")).select_from(GenomeDatabase) \
                    .join(Genome).join(Assembly).join(Organism).join(DataRelease).join(Division) \
                    .filter(DataRelease.ensembl_version.in_( ens_version) ) \
                    .filter(DataRelease.ensembl_genomes_version.in_(eg_version))
        
        if species:
            meta_query = meta_query.filter(
                GenomeDatabase.type.in_(dbtype)
            )
        if species:
            meta_query = meta_query.filter(
                Organism.name.in_(species)
            )
        
        if division:
            meta_query = meta_query.filter(
                Division.name.in_(division)
            )
            
        for result in session.execute(meta_query): 
            species_info = dict(result)
            yield species_info      
      
            