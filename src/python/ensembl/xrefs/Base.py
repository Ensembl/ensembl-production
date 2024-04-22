#  See the NOTICE file distributed with this work for additional information
#  regarding copyright ownership.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

"""Base xref module to include all common functions used by xref modules."""

import re
import os
import shutil
import requests
import fnmatch
import gzip
import importlib
import wget
import threading
import json
import logging
import time
import random
import csv
import subprocess

from sqlalchemy import create_engine, select, insert, update, text, func, and_
from sqlalchemy.engine.url import make_url, URL
from sqlalchemy.engine import Connection
from sqlalchemy.orm import aliased
from sqlalchemy_utils import database_exists, create_database, drop_database
from urllib.parse import urlparse
from ftplib import FTP
from itertools import groupby
from configparser import ConfigParser
from datetime import datetime

from ensembl.databases.xref_source_db_model import Base as XrefSourceDB, Source as SourceSORM, Version as VersionORM, ChecksumXref as ChecksumXrefSORM

from ensembl.databases.xref_update_db_model import Base as XrefUpdateDB, Source as SourceUORM, SourceURL as SourceURLORM, Xref as XrefUORM, \
  PrimaryXref as PrimaryXrefORM, DependentXref as DependentXrefUORM, GeneDirectXref as GeneDirectXrefORM, TranscriptDirectXref as TranscriptDirectXrefORM, \
  TranslationDirectXref as TranslationDirectXrefORM, Synonym as SynonymORM, Pairs as PairsORM, Species as SpeciesORM, \
  SourceMappingMethod as SourceMappingMethodORM, MappingJobs as MappingJobsORM, Mapping as MappingORM

from ensembl.core.models import Meta as MetaCORM, Gene as GeneORM, Transcript as TranscriptORM, Analysis as AnalysisORM, \
  ExonTranscript as ExonTranscriptORM, SupportingFeature as SupportingFeatureORM, DnaAlignFeature as DnaAlignFeatureORM, \
  TranscriptAttrib as TranscriptAttribORM, AttribType as AttribTypeORM, AnalysisDescription as AnalysisDescriptionORM, \
  SeqRegion as SeqRegionORM, SeqRegionAttrib as SeqRegionAttribORM, CoordSystem as CoordSystemORM, Translation as TranslationORM, \
  Exon as ExonORM, Xref as XrefCORM, DependentXref as DependentXrefCORM, ExternalDb as ExternalDbORM, Dna as DnaORM, ObjectXref as ObjectXrefCORM

from ensembl.common.Params import Params

class Base(Params):
  """ Class to represent the base of xref modules. Inherits the Params class.
  """
  def __init__(self, params: dict=None, parse_dataflow_json: bool=True) -> None:
    """ Calls the parent __init__ then sets some specific parameters.

    Parameters
    ----------
    params: dict, optional
        The parameters to start the object with. If defined, command-line parameters won't be parsed (default is None)
    parse_dataflow_json: bool, optional
        Specifies whether to parse an option called 'dataflow' in the provided options (default is True)
    """
    super().__init__(params, parse_dataflow_json)

    self.param('metasearch_url', "http://registry-grpc.ebi.ac.uk:8080/registry/metaSearch")

    # Initialize the logfile for this run
    if self.param('log_timestamp'):
      current_timestamp = self.param('log_timestamp')
    else:
      current_timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

    log_path = os.path.join(self.param_required('base_path'), 'logs', current_timestamp)
    if not os.path.exists(log_path): os.makedirs(log_path, exist_ok = True)

    log_file = os.path.join(log_path, 'tmp_logfile_'+self.__class__.__name__+'_'+str(random.randint(0, 5000)))
    self._log_file = log_file

    console_handler = logging.StreamHandler()
    file_handler = logging.FileHandler(log_file, mode='a')
    console_handler.setLevel(logging.WARNING)
    file_handler.setLevel(logging.DEBUG)

    logging.basicConfig(
      level=logging.DEBUG,
      format='%(asctime)s | %(levelname)s | %(message)s',
      datefmt='%d-%b-%Y %H:%M:%S',
      handlers=[console_handler, file_handler]
    )

  def create_source_db(self, source_url: str, reuse_db_if_present: bool):
    """ Creates the xref source database from model.

    Parameters
    ----------
    source_url: str
        The source database URL with format: [driver]://[user]:[password]@[host]:[port]/[dbname]
    reuse_db_if_present: bool
        If set to False, the database defined by provided URL will be dropped before creating a new one
    """
    url = make_url(source_url)
    engine = create_engine(url, isolation_level="AUTOCOMMIT")

    if url.database and reuse_db_if_present:
      return

    if database_exists(engine.url):
      drop_database(engine.url)
    create_database(engine.url)
    XrefSourceDB.metadata.create_all(engine)

  def download_file(self, file: str, base_path: str, source_name: str, extra_args: dict):
    """ Downloads an xref file and saves into provided space.

    Parameters
    ----------
    file: str
        The URL of the file to download. Acceptable URL schemes: ftp, http, and https
    base_path: str
        The path to save the downloaded file into
    source_name: str
        The xref source name
    extra_args: dict
        Extra options, including:
        - skip_download_if_file_present: If set to True, file is only downloaded if does not exist
        - db: The type of external db for the xref source (only relevent here if equal to 'checksum')
        - release: If set to 'version', then this is a version file download
        - rel_number: The URL used to retrieve the release number (only for RefSeq)
        - catalog: The URL used to retrieve the release catalog (only for RefSeq)

    Returns
    -------
    The path of the downloaded file.

    Raises
    ------
    LookupError
        If rel_number is provided but no release number was found in URL.
    AttributeError
        If file URL scheme is invalid.
    """
    # Create uri object and get scheme
    uri = urlparse(file)
    if not uri.scheme:
      return file

    # Get extra parameters
    skip_download_if_file_present = extra_args.get('skip_download_if_file_present') or False
    db = extra_args.get('db')
    release = extra_args.get('release')
    rel_number = extra_args.get('rel_number')
    catalog = extra_args.get('catalog')

    # Create file download path
    orig_source_name = source_name
    source_name = re.sub(r"\/", "", source_name)
    dest_dir = os.path.join(base_path, source_name)
    if db and db == 'checksum':
      dest_dir = os.path.join(base_path, 'Checksum')
    if not os.path.exists(dest_dir): os.makedirs(dest_dir, exist_ok = True)

    file_path = ""

    # If file is in local ftp, copy from there
    if re.search("ftp.ebi.ac.uk", file):
      # Construct local path
      local_file = file
      local_file = re.sub("https://ftp.ebi.ac.uk/pub/", "/nfs/ftp/public/", local_file)

      # Check if local file exists
      if os.path.exists(local_file):
        file_path = os.path.join(dest_dir, os.path.basename(uri.path))
        if db and db == 'checksum':
          file_path = os.path.join(dest_dir, f'{source_name}-{os.path.basename(uri.path)}')

        logging.info(f'I am here inside local ftp with {orig_source_name}')

        if not (skip_download_if_file_present and os.path.exists(file_path)):
          shutil.copy(local_file, file_path)

          # Check if copy was successful
          if os.path.exists(file_path):
            logging.info(f'{orig_source_name} file copied from local FTP: {file_path}')
            if release:
              return file_path
            return os.path.dirname(file_path)
        else:
          logging.info(f'{orig_source_name} file already exists, skipping download ({file_path})')

    # Handle Refseq files
    if re.search("RefSeq", source_name) and rel_number and catalog and not release:
      # Get current release number
      release_number = requests.get(rel_number).json()
      if not release_number:
        raise LookupError(f'No release number in {rel_number}')

      # Get list of files in release catalog
      catalog = re.sub(r"\*", str(release_number), catalog)
      files_list = requests.get(catalog).text
      refseq_files = files_list.split("\n")
      files_to_download = []

      # Download each refseq file
      for refseq_file in refseq_files:
        if not refseq_file: continue
        checksum, filename = refseq_file.split("\t")

        # Only interested in files matching pattern
        if not fnmatch.fnmatch(filename, os.path.basename(uri.path)): continue
        if re.search("nonredundant_protein", filename) or re.search("wp_protein", filename): continue

        file_path = os.path.join(dest_dir, os.path.basename(filename))
        if os.path.exists(file_path):
          if skip_download_if_file_present:
            logging.info(f'{orig_source_name} file already exists, skipping download ({file_path})')
            continue
          os.remove(file_path)

        file_url = os.path.join(os.path.dirname(file), filename)
        files_to_download.append({'url': file_url, 'path': file_path})
        logging.info(f'{orig_source_name} file downloaded via HTTP: {file_path}')

      self.refseq_multithreading(files_to_download)
    elif uri.scheme == 'ftp':
      ftp = FTP(uri.netloc)
      ftp.login('anonymous', '-anonymous@')
      ftp.cwd(os.path.dirname(uri.path))
      remote_files = ftp.nlst()

      # Download files in ftp server
      for remote_file in remote_files:
        # Only interested in files matching pattern
        if not fnmatch.fnmatch(remote_file, os.path.basename(uri.path)): continue

        remote_file = re.sub(r"\n", "", remote_file)
        file_path = os.path.join(dest_dir, os.path.basename(remote_file))
        if db and db == 'checksum':
          file_path = os.path.join(dest_dir, f'{source_name}-{os.path.basename(remote_file)}')

        if not (skip_download_if_file_present and os.path.exists(file_path)):
          ftp.retrbinary("RETR " + remote_file , open(file_path, 'wb').write)
          logging.info(f'{orig_source_name} file downloaded via FTP: {file_path}')
        else:
          logging.info(f'{orig_source_name} file already exists, skipping download ({file_path})')
        ftp.close()
    elif uri.scheme == 'http' or uri.scheme == 'https':
      # This is the case for the release file
      if re.search("RefSeq", source_name) and rel_number and release:
        # Get current release number
        release_number = requests.get(rel_number).json()
        if not release_number:
          raise LookupError(f'No release number in {rel_number}')

        file = re.sub(r"\*", str(release_number), file)
        uri = urlparse(file)

      file_path = os.path.join(dest_dir, os.path.basename(uri.path))
      if db and db == 'checksum':
        file_path = os.path.join(dest_dir, f'{source_name}-{os.path.basename(uri.path)}')

      if not os.path.exists(file_path) or not skip_download_if_file_present:
        if not skip_download_if_file_present and os.path.exists(file_path):
          os.remove(file_path)
        wget.download(file, file_path)
        logging.info(f'{orig_source_name} file downloaded via HTTP: {file_path}')
      else:
        logging.info(f'{orig_source_name} file already exists, skipping download ({file_path})')
    else:
      raise AttributeError(f'Invalid URL scheme {uri.scheme}')

    if release:
      return file_path
    return os.path.dirname(file_path)

  def refseq_multithreading(self, files):
    """ Creates multiple threads to download RefSeq files in parallel.

    Parameters
    ----------
    files: list
        The list of file URLs and paths to download.
    """
    number_of_threads = 20
    chunk_size = int(len(files) / number_of_threads)
    threads = []

    for thread_index in range(number_of_threads):
      array_start = thread_index * chunk_size
      array_end = len(files) if thread_index+1 == number_of_threads else (thread_index+1) * chunk_size

      thread = threading.Thread(target=self.download_refseq_files, args=(files, array_start, array_end))
      threads.append(thread)
      threads[thread_index].start()

    for thread in threads:
      thread.join()

  def download_refseq_files(self, files, start: int, end: int):
    """ Downloads RefSeq files from a subset of files.

    Parameters
    ----------
    files: list
        The list of file URLs and paths to download.
    start: int
        The start index of the files list.
    end: int
        The end index of the files list.

    Raises
    ------
    Exception
        If file download fails all attempts.
    """
    for index in range(start, end):
      failed = 0
      file_url = files[index]['url']
      local_path = files[index]['path']

      for retry in range(0,3):
        try:
          wget.download(file_url, local_path)
        except:
          failed += 1
          continue
        break

      if failed > 0:
        raise Exception(f'Failed to download file {file_url}')

  def get_dbi(self, url: str):
    """ Returns a DB connection for a provided URL.

    Parameters
    ----------
    url: str
        The database URL to connect to

    Returns
    -------
    An sqlalchemy engine connection.
    """
    connect_url = make_url(url)
    engine = create_engine(connect_url, isolation_level="AUTOCOMMIT")

    return engine.connect()

  def get_db_engine(self, url: str):
    """ Returns a DB engine for a provided URL.

    Parameters
    ----------
    url: str
        The database URL to create an engine for

    Returns
    -------
    An sqlalchemy engine.
    """
    connect_url = make_url(url)
    engine = create_engine(connect_url, isolation_level="AUTOCOMMIT")

    return engine

  def load_checksum(self, path: str, url: str):
    """ Loads the xref checksum files into a provided database.
    This first combines the checksum data from different xref sources into 1 file called checksum.txt before loading into the DB.

    Parameters
    ----------
    path: str
        The path where the checksum files can be found
    url: str
        The database URL to load the checksum data into
    """
    checksum_dir = os.path.join(path, 'Checksum')
    if not os.path.exists(checksum_dir): os.makedirs(checksum_dir, exist_ok = True)

    # Connect to db
    url = url + "?local_infile=1"
    db_engine = self.get_db_engine(url)
    with db_engine.connect() as dbi:
      counter = 1
      source_id = 1

      # Open the checksum output file
      files = os.listdir(checksum_dir)
      checksum_file = os.path.join(checksum_dir, 'checksum.txt')
      with open(checksum_file, 'w') as output_fh:
        # Go through all available checksum files
        for file in files:
          if re.search("checksum", file): continue

          input_file = os.path.join(checksum_dir, file)
          match = re.search(r"\/([A-Za-z]*)-.*$", input_file)
          source_name = match.group(1)
          source_id = self.get_source_id_from_name(dbi, source_name)

          input_fh = self.get_filehandle(input_file)
          for line in input_fh:
            line = line.rstrip()
            (id, checksum) = re.split(r"\s+", line)

            counter += 1
            output = [str(counter), str(source_id), id, checksum]
            output_str = "\t".join(output)
            output_fh.write(f'{output_str}\n')

          input_fh.close()

      query = f'load data local infile \'{checksum_file}\' into table checksum_xref'
      dbi.execute(text(query))

  def get_filehandle(self, filename: str):
    """ Opens an appropriate read filehandle for a file based on its type.

    Parameters
    ----------
    filename: str
        The name and path of the file to read

    Returns
    -------
    A read filehandle.

    Raises
    ------
    FileNotFoundError
        If no file name was provided.
        If provided file could not be found.
    """
    if not filename or filename == '':
      raise FileNotFoundError('No file name')

    alt_filename = filename
    alt_filename = re.sub(r"\.(gz|Z)$", "", alt_filename)
    if alt_filename == filename:
      alt_filename = alt_filename + ".gz"

    if not os.path.exists(filename):
      if not os.path.exists(alt_filename):
        raise FileNotFoundError(f'Could not find either {filename} or {alt_filename}')
      filename = alt_filename

    if re.search(r"\.(gz|Z)$", filename):
      fh = gzip.open(filename, 'rt')
    else:
      fh = open(filename, 'r')

    return fh

  def get_source_id_from_name(self, dbi, source_name: str):
    """ Retrieves a source ID from its name from a database.

    Parameters
    ----------
    dbi: db connection
        The database connection to query in
    source_name: str
        The name of the source

    Returns
    -------
    The source ID.
    """
    query = select(SourceSORM.source_id).where(SourceSORM.name==source_name)
    source_id = dbi.execute(query).scalar()

    return source_id

  def get_file_sections(self, file: str, delimiter: str):
    """ Reads a provided file by sections, separated by a provided delimiter.
    This function uses 'yield' to provide the file sections one by one.

    Parameters
    ----------
    file: str
        The name and path of the file to read
    delimiter: str
        The character or string separating the file sections

    Returns
    -------
    A yield of file sections.
    """
    if re.search(r"\.(gz|Z)$", file):
      with gzip.open(file, 'rt') as fh:
        groups = groupby(fh, key=lambda x: x.lstrip().startswith(delimiter))
        for key,group in groups:
          yield list(group)
    else:
      with open(file, 'r') as fh:
        groups = groupby(fh, key=lambda x: x.lstrip().startswith(delimiter))
        for key,group in groups:
          yield list(group)

  def create_xref_db(self, url: str, config_file: str, preparse:bool):
    """ Creates the xref database from model.
    This function always drops the database defined by the provided URL (if it exists) before creating a new one.

    Parameters
    ----------
    url: str
        The database URL with format: [driver]://[user]:[password]@[host]:[port]/[dbname]
    config_file: str
        The name and path of the .ini file that has information about xref sources and species
    preparse: bool
        Specifies whether source preparsing will be done or not
    """
    engine = create_engine(url, isolation_level="AUTOCOMMIT")

    # Drop database and create again
    if database_exists(engine.url):
      drop_database(engine.url)
    create_database(engine.url)
    XrefUpdateDB.metadata.create_all(engine)

    xref_dbi = engine.connect()
    self.populate_xref_db(xref_dbi, config_file, preparse)

  def populate_xref_db(self, dbi, config_file:str, preparse:bool):
    """ Populates the xref database with configuration data.

    Parameters
    ----------
    dbi: db connection
        The xref database connection
    config_file: str
        The name and path of the .ini file that has information about xref sources and species to populate the database with
    preparse: bool
        Specifies whether source preparsing will be done or not (needed to decide if to use old parsers)

    Raises
    ------
    KeyError
        If a source exists in a species section in the configuration file, but has no source section of its own.
    """
    source_ids = {}
    source_parsers = {}
    species_sources = {}

    config = ConfigParser()
    config.read(config_file)

    species_sections, sources_sections = {}, {}

    for section_name in config.sections():
      section = config[section_name]
      (keyword, name) = re.split(r"\s+", section_name)

      if keyword == 'source':
        sources_sections[name] = section
      elif keyword == 'species':
        species_sections[name] = section

    # Parse species sections
    for species_name, section in species_sections.items():
      taxonomy_ids = section.get('taxonomy_id').split(",")
      sources = section.get('sources')
      aliases = section.get('aliases', species_name)

      species_id = taxonomy_ids[0]

      for tax_id in taxonomy_ids:
        # Add new species
        query = insert(SpeciesORM).values(species_id=species_id, taxonomy_id=tax_id, name=species_name, aliases=aliases)
        dbi.execute(query)

      species_sources[species_id] = sources

    source_id = 0
    # Parse source sections
    for source_name, section in sorted(sources_sections.items()):
      source_id += 1
      source_name = section.get('name')
      order = section.get('order')
      priority = section.get('priority')
      priority_description = section.get('prio_descr', '')
      status = section.get('status', 'NOIDEA')

      old_parser = section.get('old_parser')
      if old_parser and not preparse:
        parser = old_parser
      else:
        parser = section.get('parser')

      # Add new source
      query = insert(SourceUORM).values(name=source_name, source_release='1', ordered=order, priority=priority, priority_description=priority_description, status=status)
      dbi.execute(query)

      source_ids[source_name] = source_id
      source_parsers[source_id] = parser

    # Add source url rows
    for species_id, sources in species_sources.items():
      source_names = sources.split(",")

      for source_name in source_names:
        if not source_ids.get(source_name):
          raise KeyError(f'No source section found for {source_name} in config file')

        source_id = source_ids[source_name]
        parser = source_parsers[source_id]
        query = insert(SourceURLORM).values(source_id=source_id, species_id=species_id, parser=parser)
        dbi.execute(query)

  def get_source_id(self, dbi, parser: str, species_id: int, name: str, division_id: int):
    """ Retrieves a source ID from its parser, species ID, name or division ID.

    Parameters
    ----------
    dbi: db connection
        The database connection to query in
    parser: str
        The source parser
    species_id: int
        The ID of the species related to the source
    name: str
        The source name
    division_id: int
        The ID of the division related to the source

    Returns
    -------
    The source ID.
    """
    name = "%"+name+"%"
    source_id = None

    query = select(SourceURLORM.source_id).where(SourceUORM.source_id==SourceURLORM.source_id, SourceURLORM.parser==parser, SourceURLORM.species_id==species_id)
    result = dbi.execute(query)
    if result.rowcount == 1:
      source_id = result.scalar()

    query = select(SourceURLORM.source_id).where(SourceUORM.source_id==SourceURLORM.source_id, SourceURLORM.parser==parser, SourceURLORM.species_id==species_id).filter(SourceUORM.name.like(name))
    result = dbi.execute(query)
    if result.rowcount == 1:
      source_id = result.scalar()

    if not source_id:
      query = select(SourceURLORM.source_id).where(SourceUORM.source_id==SourceURLORM.source_id, SourceURLORM.parser==parser, SourceURLORM.species_id==division_id).filter(SourceUORM.name.like(name))
      result = dbi.execute(query).first()
      if result:
        source_id = result[0]

    return source_id

  def get_taxon_id(self, dbi):
    """ Retrieves the species.taxonomy_id value of the meta table in a database.

    Parameters
    ----------
    dbi: db connection
        The database connection to query in

    Returns
    -------
    The taxonomy ID in the database or 1 if not found.
    """
    query = select(MetaCORM.meta_value).where(MetaCORM.meta_key=='species.taxonomy_id')
    result = dbi.execute(query)
    if result.rowcount > 0:
      return result.scalar()

    return 1

  def get_division_id(self, dbi):
    """ Retrives the division ID from a database based on the species.division value of the meta table.

    Parameters
    ----------
    dbi: db connection
        The database connection to query in

    Returns
    -------
    The division ID in the database or 1 if not found
    """
    query = select(MetaCORM.meta_value).where(MetaCORM.meta_key=='species.division')
    result = dbi.execute(query)

    if result.rowcount > 0:
      division = result.scalar()

      division_taxon = {
        'Ensembl'            : 7742,
        'EnsemblVertebrates' : 7742,
        'Vertebrates'        : 7742,
        'EnsemblMetazoa'     : 33208,
        'Metazoa'            : 33208,
        'Plants'             : 33090,
        'EnsemblPlants'      : 33090,
      }

      division_id = division_taxon.get(division)
      if division_id:
        return division_id

    return 1

  def get_path(self, base_path: str, species: str, release: int, category: str, file_name: str=None):
    """ Creates directories based on provided data.

    Parameters
    ----------
    base_path: str
        The base file path
    species: str
        The species name
    release: int
        The ensEMBL release number
    category: str
        The file category
    file_name: str, optional
        The file name

    Returns
    -------
    A file path.
    """
    full_path = os.path.join(base_path, species, release, category)
    if not os.path.exists(full_path):
      os.makedirs(full_path, exist_ok = True)

    if file_name:
      return os.path.join(full_path, file_name)
    else:
      return full_path

  def get_db_from_registry(self, species: str, group: str, release: int, registry: str):
    """ Looks up a db in the registry and returns an sqlaclehmy angine for it.

    Parameters
    ----------
    species: str
        The species name
    group: str
        The db group (core, ccds, otherfeatures, etc...)
    release: int
        The ensEMBL release number
    registry: str
        The registry url

    Returns
    -------
    A db engine or 0 if no db is found.
    """
    # Fix registry url, if needed
    match = re.search(r"^(.*)://(.*)", registry)
    if match: registry = match.group(2)
    match = re.search(r"(.*)/(.*)", registry)
    if match: registry = match.group(1)

    metasearch_url  = self.param_required('metasearch_url')
    metasearch_body = {
      "name_pattern":f'{species}_{group}%',
      "filters":[
        {
          "meta_key":"schema_version",
          "meta_value":release
        },
      ],
      "servers":[registry]
    }

    dbs = requests.post(metasearch_url, json=metasearch_body).json()
    dbs = dbs[registry]

    if len(dbs) > 0:
      db_url = 'mysql://' + dbs[0]
      return db_url
    else:
      return 0

  # def get_spark_session(self, data_type):
  #   if data_type == 'mysql':
  #     spark = SparkSession.builder.appName('SparkByExamples.com').config("spark.jars", "mysql-connector-java-8.0.13.jar").getOrCreate()
  #     return spark
  #   else:
  #     raise Exception(f'Spark data type {data_type} not supported yet')

  # def get_spark_reader(self, spark_session, data_type, data_url):
  #   if data_type == 'mysql':
  #     reader = spark_session.read.format("jdbc").option("driver", "com.mysql.cj.jdbc.Driver").option("url", f'jdbc:{data_url}')
  #     return reader
  #   else:
  #     raise Exception(f'Spark data type {data_type} not supported yet')

  def get_xref_mapper(self, xref_url: str, species: str, base_path: str, release: int, core_url: str=None, registry: str=None):
    """ Retrives a mapper object based on species.

    Parameters
    ----------
    xref_url: str
        The xref db connection url
    species: str
        The species name
    base_path: str
        The base file path
    release: int
        The ensEMBL release number
    core_db: str, optional
        The species core db connection url
    registry: str, optional
        The registry url

    Returns
    -------
    A mapper object
    """
    # Need either core_db or registry
    if not core_url and not registry:
      raise AttributeError(f'Method get_xref_mapper: need to provide either a core DB URL or a registry URL')

    # Create needed db connections
    if not core_url:
      core_url = self.get_db_from_registry(species, 'core', release, registry)

    core_db = self.get_db_engine(core_url)
    xref_db = self.get_db_engine(xref_url)

    # Extract host and dbname from xref url
    xref_url_obj = make_url(xref_url)
    host = xref_url_obj.host
    dbname = xref_url_obj.database

    # Locate the fasta files
    cdna_path = self.get_path(base_path, species, release, 'ensembl', 'transcripts.fa');
    pep_path = self.get_path(base_path, species, release, 'ensembl', 'peptides.fa');

    # Try to find a species-specific mapper first
    module_name = f'ensembl.xrefs.mapper.{species}'
    class_name = species
    found = importlib.find_loader(module_name)
    if not found:
      module_name = 'ensembl.xrefs.mapper.BasicMapper'
      class_name = 'BasicMapper'

    # Create a mapper object
    module = importlib.import_module(module_name)
    module_class = getattr(module, class_name)
    mapper = module_class()

    mapper.xref(xref_db)
    mapper.add_meta_pair('xref', f'{host}:{dbname}')
    mapper.core(core_db)
    mapper.add_meta_pair('species', f'{host}:{dbname}')
    mapper.dna_file(cdna_path)
    mapper.protein_file(pep_path)
    mapper.log_file(self._log_file)

    return mapper


