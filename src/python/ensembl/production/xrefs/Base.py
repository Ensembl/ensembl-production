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
import wget # type: ignore
import threading
import logging
import random

from sqlalchemy import create_engine, select, text
from sqlalchemy.dialects.mysql import insert
from sqlalchemy.engine.url import make_url
from sqlalchemy.engine import Engine, Connection
from sqlalchemy_utils import database_exists, create_database, drop_database
from urllib.parse import urlparse
from ftplib import FTP
from itertools import groupby
from configparser import ConfigParser
from datetime import datetime
from typing import IO, List, Dict, Any, Iterator, Optional

from ensembl.production.xrefs.mappers.BasicMapper import BasicMapper

from ensembl.xrefs.xref_source_db_model import (
    Base as XrefSourceDB,
    Source as SourceSORM
)

from ensembl.xrefs.xref_update_db_model import (
    Base as XrefUpdateDB,
    Source as SourceUORM,
    SourceURL as SourceURLORM,
    Species as SpeciesORM
)

from ensembl.core.models import Meta as MetaCORM

from ensembl.common.Params import Params

class Base(Params):
    """Class to represent the base of xref modules. Inherits the Params class."""

    def __init__(self, params: Optional[Dict[str, Any]] = None, parse_dataflow_json: Optional[bool] = True, testing: bool = False) -> None:
        """
        Initialize the Base class with specific parameters.

        Parameters
        ----------
        params: Optional[Dict[str, Any]]
            Initial parameters for the object. If provided, command-line parameters will not be parsed (default is None).
        parse_dataflow_json: Optional[bool]
            Whether to parse an option called 'dataflow' in the provided options (default is True).
        """
        super().__init__(params, parse_dataflow_json)

        self.set_param("metasearch_url", "http://registry-grpc.ebi.ac.uk:8080/registry/metaSearch")

        # Initialize the logfile for this run (except for the Alignment module)
        module_name = self.__class__.__name__
        if module_name != "Alignment" and not testing:
            current_timestamp = self.get_param("log_timestamp", {"default": datetime.now().strftime("%Y%m%d_%H%M%S"), "type": str})

            log_path = os.path.join(
                self.get_param("base_path", {"required": True}), "logs", current_timestamp
            )
            os.makedirs(log_path, exist_ok=True)

            log_file = os.path.join(
                log_path,
                f"tmp_logfile_{module_name}_{random.randint(0, 5000)}",
            )
            self._log_file = log_file

            console_handler = logging.StreamHandler()
            file_handler = logging.FileHandler(log_file, mode="a")
            console_handler.setLevel(logging.WARNING)
            file_handler.setLevel(logging.DEBUG)

            logging.basicConfig(
                level=logging.DEBUG,
                format="%(asctime)s | %(levelname)s | %(message)s",
                datefmt="%d-%b-%Y %H:%M:%S",
                handlers=[console_handler, file_handler],
            )

    def create_source_db(self, source_url: str, reuse_db_if_present: bool) -> None:
        """Creates the xref source database from model.

        Parameters
        ----------
        source_url: str
            The source database URL with format: [driver]://[user]:[password]@[host]:[port]/[dbname].
        reuse_db_if_present: bool
            If set to True, the existing database will be reused if present.
        """
        url = make_url(source_url)
        engine = create_engine(url, isolation_level="AUTOCOMMIT")

        if reuse_db_if_present and database_exists(engine.url):
            logging.info(f"Database {url.database} already exists and reuse_db_if_present is True. Skipping creation.")
            return

        if database_exists(engine.url):
            logging.info(f"Dropping existing database {url.database}.")
            drop_database(engine.url)
        
        logging.info(f"Creating new database {url.database}.")
        create_database(engine.url)
        XrefSourceDB.metadata.create_all(engine)
        logging.info(f"Database {url.database} created successfully.")

    def download_file(self, file: str, base_path: str, source_name: str, extra_args: Dict[str, Any]) -> str:
        """Downloads an xref file and saves it into the provided space.

        Parameters
        ----------
        file: str
            The URL of the file to download. Acceptable URL schemes: ftp, http, and https.
        base_path: str
            The path to save the downloaded file into.
        source_name: str
            The xref source name.
        extra_args: Dict[str, Any]
            Extra options, including:
            - skip_download_if_file_present: If set to True, file is only downloaded if it does not exist.
            - db: The type of external db for the xref source (only relevant here if equal to 'checksum').
            - release: If set to 'version', then this is a version file download.
            - rel_number: The URL used to retrieve the release number (only for RefSeq).
            - catalog: The URL used to retrieve the release catalog (only for RefSeq).

        Returns
        -------
        str
            The path of the downloaded file.

        Raises
        ------
        LookupError
            If rel_number is provided but no release number was found in URL.
        AttributeError
            If file URL scheme is invalid.
        """
        uri = urlparse(file)
        if not uri.scheme:
            return file

        skip_download_if_file_present = extra_args.get("skip_download_if_file_present", False)
        db = extra_args.get("db")
        release = extra_args.get("release")
        rel_number = extra_args.get("rel_number")
        catalog = extra_args.get("catalog")

        source_name_clean = re.sub(r"\/", "", source_name)
        dest_dir = os.path.join(base_path, "Checksum" if db == "checksum" else source_name_clean)
        os.makedirs(dest_dir, exist_ok=True)

        def download_via_http(file_url: str, dest_path: str) -> None:
            if not os.path.exists(dest_path) or not skip_download_if_file_present:
                if os.path.exists(dest_path):
                    os.remove(dest_path)
                wget.download(file_url, dest_path)
                logging.info(f"{source_name} file downloaded via HTTP: {dest_path}")
            else:
                logging.info(f"{source_name} file already exists, skipping download ({dest_path})")

        # If file is in local ftp, copy from there
        if re.search("ftp.ebi.ac.uk", file):
            local_file = re.sub("https://ftp.ebi.ac.uk/pub/", "/nfs/ftp/public/", file)
            if os.path.exists(local_file):
                file_path = os.path.join(dest_dir, os.path.basename(uri.path))
                if db == "checksum":
                    file_path = os.path.join(dest_dir, f"{source_name_clean}-{os.path.basename(uri.path)}")

                if not (skip_download_if_file_present and os.path.exists(file_path)):
                    shutil.copy(local_file, file_path)

                    # Check if copy was successful
                    if os.path.exists(file_path):
                        logging.info(f"{source_name} file copied from local FTP: {file_path}")
                        return file_path
                else:
                    logging.info(f"{source_name} file already exists, skipping download ({file_path})")

        # Handle Refseq files
        if re.search("RefSeq", source_name) and rel_number and catalog and not release:
            # Get current release number
            release_number = requests.get(rel_number).json()
            if not release_number:
                raise LookupError(f"No release number in {rel_number}")

            # Get list of files in release catalog
            catalog = re.sub(r"\*", str(release_number), catalog)
            refseq_files = requests.get(catalog).text.split("\n")
            files_to_download = []

            for refseq_file in refseq_files:
                if refseq_file:
                    checksum, filename = refseq_file.split("\t")

                    # Only interested in files matching pattern and not non-redundant or wp_protein
                    if fnmatch.fnmatch(filename, os.path.basename(uri.path)) and not re.search("nonredundant_protein|wp_protein", filename):
                        file_path = os.path.join(dest_dir, os.path.basename(filename))
                        if os.path.exists(file_path):
                            if skip_download_if_file_present:
                                logging.info(f"{source_name} file already exists, skipping download ({file_path})")
                                continue
                            os.remove(file_path)

                        file_url = os.path.join(os.path.dirname(file), filename)
                        files_to_download.append({"url": file_url, "path": file_path, "type": source_name})

            self.refseq_multithreading(files_to_download)
        elif uri.scheme == "ftp":
            file_path = self.download_via_ftp(file, dest_dir, db, source_name, skip_download_if_file_present)
        elif uri.scheme in ["http", "https"]:
            # This is the case for the RefSeq release file
            if re.search("RefSeq", source_name) and rel_number and release:
                release_number = requests.get(rel_number).json()
                if not release_number:
                    raise LookupError(f"No release number in {rel_number}")

                file = re.sub(r"\*", str(release_number), file)
                uri = urlparse(file)

            file_path = os.path.join(dest_dir, os.path.basename(uri.path))
            if db == "checksum":
                file_path = os.path.join(dest_dir, f"{source_name_clean}-{os.path.basename(uri.path)}")

            download_via_http(file, file_path)
        else:
            raise AttributeError(f"Invalid URL scheme {uri.scheme}")

        return os.path.dirname(file_path) if re.search("RefSeq", source_name) and not release else file_path

    def download_via_ftp(self, ftp_url: str, dest_path: str, db: str, source_name: str, skip_download: bool) -> str:
        uri = urlparse(ftp_url)

        ftp = FTP(uri.netloc)
        ftp.login("anonymous", "-anonymous@")
        ftp.cwd(os.path.dirname(uri.path))
        remote_files = ftp.nlst()

        source_name_clean = re.sub(r"\/", "", source_name)

        for remote_file in remote_files:
            # Only interested in files matching pattern
            if fnmatch.fnmatch(remote_file, os.path.basename(uri.path)):
                file_path = os.path.join(dest_path, os.path.basename(remote_file))
                if db == "checksum":
                    file_path = os.path.join(dest_path, f"{source_name_clean}-{os.path.basename(remote_file)}")

                if not (skip_download and os.path.exists(file_path)):
                    ftp.retrbinary("RETR " + remote_file, open(file_path, "wb").write)
                    logging.info(f"{source_name} file downloaded via FTP: {file_path}")
                else:
                    logging.info(f"{source_name} file already exists, skipping download ({file_path})")
        ftp.quit()

        return file_path

    def refseq_multithreading(self, files: List[Dict[str, str]]) -> None:
        """Creates multiple threads to download RefSeq files in parallel.

        Parameters
        ----------
        files: List[Dict[str, str]]
            The list of file URLs and paths to download.
        """
        number_of_threads = 20
        chunk_size = len(files) // number_of_threads
        threads = []

        for thread_index in range(number_of_threads):
            array_start = thread_index * chunk_size
            array_end = (
                len(files)
                if thread_index + 1 == number_of_threads
                else (thread_index + 1) * chunk_size
            )

            thread = threading.Thread(
                target=self.download_refseq_files, args=(files, array_start, array_end)
            )
            threads.append(thread)
            threads[thread_index].start()

        for thread in threads:
            thread.join()

    def download_refseq_files(self, files: List[Dict[str, str]], start: int, end: int) -> None:
        """Downloads RefSeq files from a subset of files.

        Parameters
        ----------
        files: List[Dict[str, str]]
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
            file_url = files[index]["url"]
            local_path = files[index]["path"]
            source_name = files[index]["type"]

            for attempt in range(3):
                try:
                    wget.download(file_url, local_path)
                    logging.info(f"{source_name} file downloaded via HTTP: {local_path}")
                    break
                except Exception as e:
                    logging.warning(f"Attempt {attempt + 1} failed to download {file_url}: {e}")
                    if attempt == 2:
                        raise Exception(f"Failed to download file {file_url} after 3 attempts")

    def get_dbi(self, url: str) -> Connection:
        """Returns a DB connection for a provided URL.

        Parameters
        ----------
        url: str
            The database URL to connect to.

        Returns
        -------
        Connection
            An sqlalchemy engine connection.
        """
        engine = self.get_db_engine(url)
        return engine.connect()

    def get_db_engine(self, url: str, isolation_level: str = "AUTOCOMMIT") -> Engine:
        """Returns a DB engine for a provided URL.

        Parameters
        ----------
        url: str
            The database URL to create an engine for.

        Returns
        -------
        Engine
            An sqlalchemy engine.
        """
        connect_url = make_url(url)
        engine = create_engine(connect_url, isolation_level=isolation_level)

        return engine

    def load_checksum(self, path: str, url: str) -> None:
        """Loads the xref checksum files into a provided database.
        This first combines the checksum data from different xref sources into several chunk files before loading into the DB.
        These files are finally combined into one checksum.txt file.

        Parameters
        ----------
        path: str
            The path where the checksum files can be found.
        url: str
            The database URL to load the checksum data into.

        Raises
        ------
        LookupError
            If no source_id is found for a source name.
        """
        checksum_dir = os.path.join(path, "Checksum")
        os.makedirs(checksum_dir, exist_ok=True)

        output_files = []
        threshold = 50000000
        counter = 1
        output_fh = None

        # Connect to db
        url = f"{url}?local_infile=1"
        db_engine = self.get_db_engine(url)
        with db_engine.connect() as dbi:
            # Get all checksum files
            files = [f for f in os.listdir(checksum_dir) if not re.search("checksum", f)]

            # Process each checksum file
            index = 0
            for checksum_file in files:
                # Get the source name and ID
                input_file = os.path.join(checksum_dir, checksum_file)
                source_name = re.search(r"\/([A-Za-z]*)-.*$", input_file).group(1)
                source_id = self.get_source_id_from_name(source_name, dbi)

                if not source_id:
                    raise LookupError(f'No source_id found for source name {source_name}')

                # Open the input file
                with self.get_filehandle(input_file) as input_fh:
                    for line in input_fh:
                        # Open the output file if needed
                        if not output_fh or (counter % threshold) == 0:
                            if output_fh:
                                output_fh.close()

                            index += 1
                            output_file = os.path.join(checksum_dir, f"checksum_{index}.txt")
                            output_files.append(output_file)
                            output_fh = open(output_file, "w")

                        checksum_id, checksum = re.split(r"\s+", line.rstrip())
                        output_fh.write(f"{counter}\t{source_id}\t{checksum_id}\t{checksum}\n")
                        counter += 1

            if output_fh:
                output_fh.close()

            # Load data into the database
            for output_file in output_files:
                dbi.execute(text(f"LOAD DATA LOCAL INFILE '{output_file}' INTO TABLE checksum_xref"))

            # Merge the created files
            if output_files:
                merged_file = os.path.join(checksum_dir, "checksum.txt")
                with open(merged_file, "w") as output_fh:
                    for output_file in output_files:
                        with open(output_file, "r") as input_fh:
                            shutil.copyfileobj(input_fh, output_fh)
                        os.remove(output_file)

    def check_file_exists(self, filename: str) -> str:
        """Checks if a file exists.
        Tries alternative names with .gz and .Z extensions if the original file is not found.

        Parameters
        ----------
        filename: str
            The file to check.

        Returns
        -------
        str
            Original file name if found, otherwise the first alternative name found.
        
        Raises
        ------
        FileNotFoundError
            If no file name was provided.
            If provided file could not be found.
        """
        if not filename:
            raise FileNotFoundError("No file name provided")

        if not os.path.exists(filename):
            alt_filename = re.sub(r"\.(gz|Z)$", "", filename)
            if not os.path.exists(alt_filename):
                alt_filename = filename + ".gz"
                if not os.path.exists(alt_filename):
                    raise FileNotFoundError(
                        f"Could not find either {filename} or {alt_filename}"
                    )
            return alt_filename

        return filename

    def get_filehandle(self, filename: str) -> IO:
        """Opens an appropriate read filehandle for a file based on its type.

        Parameters
        ----------
        filename: str
            The name and path of the file to read.

        Returns
        -------
        IO
            A read filehandle.

        Raises
        ------
        FileNotFoundError
            If no file name was provided.
            If provided file could not be found.
        """
        filename = self.check_file_exists(filename)

        if filename.endswith(('.gz', '.Z')):
            return gzip.open(filename, "rt")
        else:
            return open(filename, "r")

    def get_source_id_from_name(self, source_name: str, dbi: Connection) -> int:
        """Retrieves a source ID from its name from a database.

        Parameters
        ----------
        source_name: str
            The name of the source.
        dbi: Connection
            The database connection to query in.

        Returns
        -------
        int
            The source ID.
        """
        source_id = dbi.execute(
            select(SourceSORM.source_id).where(SourceSORM.name == source_name)
        ).scalar()

        return source_id

    def get_file_sections(self, filename: str, delimiter: str, encoding: str = None) -> Iterator[List[str]]:
        """Reads a provided file by sections, separated by a provided delimiter.
        This function uses 'yield' to provide the file sections one by one.

        Parameters
        ----------
        file: str
            The name and path of the file to read.
        delimiter: str
            The character or string separating the file sections.
        encoding: str
            The encoding of the file (default is None).

        Returns
        -------
        Iterator[List[str]]
            A generator yielding file sections as lists of strings.
        """
        filename = self.check_file_exists(filename)

        def read_file(fh: IO) -> Iterator[List[str]]:
            groups = groupby(fh, key=lambda x: x.lstrip().startswith(delimiter))
            for key, group in groups:
                if not key:
                    yield list(group)

        if filename.endswith(('.gz', '.Z')):
            if encoding:
                with gzip.open(filename, "rt", encoding=encoding, errors="replace") as fh:
                    yield from read_file(fh)
            else:
                with gzip.open(filename, "rt") as fh:
                    yield from read_file(fh)
        else:
            with open(filename, "r") as fh:
                yield from read_file(fh)

    def create_xref_db(self, url: str, config_file: str) -> None:
        """Creates the xref database from model.
        This function always drops the database defined by the provided URL (if it exists) before creating a new one.

        Parameters
        ----------
        url: str
            The database URL with format: [driver]://[user]:[password]@[host]:[port]/[dbname].
        config_file: str
            The name and path of the .ini file that has information about xref sources and species.
        """
        engine = create_engine(url, isolation_level="AUTOCOMMIT")

        # Drop database and create again
        if database_exists(engine.url):
            logging.info(f"Dropping existing database {engine.url.database}.")
            drop_database(engine.url)
        logging.info(f"Creating new database {engine.url.database}.")
        create_database(engine.url)
        XrefUpdateDB.metadata.create_all(engine)
        logging.info(f"Database {engine.url.database} created successfully.")

        with engine.connect() as xref_dbi:
            self.populate_xref_db(xref_dbi, config_file)
            logging.info(f"Database {engine.url.database} populated successfully.")

    def populate_xref_db(self, dbi: Connection, config_file: str) -> None:
        """Populates the xref database with configuration data.

        Parameters
        ----------
        dbi: Connection
            The xref database connection.
        config_file: str
            The name and path of the .ini file that has information about xref sources and species to populate the database with.

        Raises
        ------
        KeyError
            If a source exists in a species section in the configuration file, but has no source section of its own.
        """
        config = ConfigParser()
        config.read(config_file)

        species_sections = {
            name.split(" ", 1)[1]: section for name, section in config.items() if name.startswith("species")
        }
        sources_sections = {
            name.split(" ", 1)[1]: section for name, section in config.items() if name.startswith("source")
        }

        species_sources = {}
        source_ids = {}
        source_parsers = {}

        # Parse species sections
        for species_name, section in species_sections.items():
            taxonomy_ids = section.get("taxonomy_id").split(",")
            sources = section.get("sources")
            aliases = section.get("aliases", species_name)

            species_id = taxonomy_ids[0]

            for tax_id in taxonomy_ids:
                # Add new species
                dbi.execute(
                    insert(SpeciesORM).values(
                        species_id=species_id,
                        taxonomy_id=tax_id,
                        name=species_name,
                        aliases=aliases,
                    )
                )

            species_sources[species_id] = sources

        # Parse source sections
        for source_id, (source_name, section) in enumerate(sorted(sources_sections.items()), start=1):
            source_db_name = section.get("name")
            order = section.get("order")
            priority = section.get("priority")
            priority_description = section.get("prio_descr", "")
            status = section.get("status", "NOIDEA")
            parser = section.get("parser")

            # Add new source
            dbi.execute(
                insert(SourceUORM).values(
                    name=source_db_name,
                    source_release="1",
                    ordered=order,
                    priority=priority,
                    priority_description=priority_description,
                    status=status,
                )
            )

            source_ids[source_name] = source_id
            source_parsers[source_id] = parser

        # Add source_url rows
        for species_id, sources in species_sources.items():
            for source_name in sources.split(","):
                if source_name not in source_ids:
                    raise KeyError(f"No source section found for {source_name} in config file")

                source_id = source_ids[source_name]
                parser = source_parsers[source_id]
                dbi.execute(
                    insert(SourceURLORM).values(
                        source_id=source_id, species_id=species_id, parser=parser
                    )
                )

    def get_source_id(self, dbi: Connection, parser: str, species_id: int, name: str, division_id: int) -> Optional[int]:
        """Retrieves a source ID from its parser, species ID, name or division ID.

        Parameters
        ----------
        dbi: Connection
            The database connection to query in.
        parser: str
            The source parser.
        species_id: int
            The ID of the species related to the source.
        name: str
            The source name.
        division_id: int
            The ID of the division related to the source.

        Returns
        -------
        Optional[int]
            The source ID or None if cannot be found.
        """
        name_pattern = f"%{name}%"
        source_id = None

        # Query by parser, species_id, and name pattern
        query = select(SourceURLORM.source_id).where(
            SourceUORM.source_id == SourceURLORM.source_id,
            SourceURLORM.parser == parser,
            SourceURLORM.species_id == species_id,
            SourceUORM.name.like(name_pattern),
        )
        result = dbi.execute(query)
        if result.rowcount == 1:
            return result.scalar()

        # Query by parser and species_id
        query = select(SourceURLORM.source_id).where(
            SourceUORM.source_id == SourceURLORM.source_id,
            SourceURLORM.parser == parser,
            SourceURLORM.species_id == species_id,
        )
        result = dbi.execute(query)
        if result.rowcount == 1:
            return result.scalar()

        # Query by parser, division_id, and name pattern
        query = select(SourceURLORM.source_id).where(
            SourceUORM.source_id == SourceURLORM.source_id,
            SourceURLORM.parser == parser,
            SourceURLORM.species_id == division_id,
            SourceUORM.name.like(name_pattern),
        )
        result = dbi.execute(query).scalar()
        if result:
            return result

        return None

    def get_taxon_id(self, dbi: Connection) -> int:
        """Retrieves the species.taxonomy_id value from the meta table in a database.

        Parameters
        ----------
        dbi: Connection
            The database connection to query in.

        Returns
        -------
        int
            The taxonomy ID in the database or 1 if not found.
        """
        result = dbi.execute(
            select(MetaCORM.meta_value).where(MetaCORM.meta_key == "species.taxonomy_id")
        )

        taxon_id = result.scalar()
        return int(taxon_id) if taxon_id else 1

    def get_division_id(self, dbi: Connection) -> int:
        """Retrieves the division ID from a database based on the species.division value in the meta table.

        Parameters
        ----------
        dbi: Connection
            The database connection to query in.

        Returns
        -------
        int
            The division ID in the database or 1 if not found.
        """
        result = dbi.execute(
            select(MetaCORM.meta_value).where(MetaCORM.meta_key == "species.division")
        )

        division = result.scalar()
        if division:
            division_taxon = {
                "Ensembl": 7742,
                "EnsemblVertebrates": 7742,
                "Vertebrates": 7742,
                "EnsemblMetazoa": 33208,
                "Metazoa": 33208,
                "Plants": 33090,
                "EnsemblPlants": 33090,
            }
            return division_taxon.get(division, 1)

        return 1

    def get_path(self, base_path: str, species: str, release: int, category: str, file_name: Optional[str] = None) -> str:
        """Creates directories based on provided data and returns the full file path.

        Parameters
        ----------
        base_path: str
            The base file path.
        species: str
            The species name.
        release: int
            The Ensembl release number.
        category: str
            The file category.
        file_name: Optional[str]
            The file name.

        Returns
        -------
        str
            The full file path.
        """
        full_path = os.path.join(base_path, species, str(release), category)
        os.makedirs(full_path, exist_ok=True)

        return os.path.join(full_path, file_name) if file_name else full_path

    def get_db_from_registry(self, species: str, group: str, release: int, registry: str) -> Optional[str]:
        """Looks up a database in the registry and returns its URL.

        Parameters
        ----------
        species: str
            The species name.
        group: str
            The database group (core, ccds, otherfeatures, etc.).
        release: int
            The Ensembl release number.
        registry: str
            The registry URL.

        Returns
        -------
        Optional[str]
            The database URL or None if no database is found.
        """
        # Clean up registry URL if needed
        registry = re.sub(r"^(.*://)?(.*?)(/.*)?$", r"\2", registry)

        metasearch_url = self.get_param("metasearch_url", {"required": True})
        metasearch_body = {
            "name_pattern": f"{species}_{group}%",
            "filters": [{"meta_key": "schema_version", "meta_value": str(release)}],
            "servers": [registry],
        }

        response = requests.post(metasearch_url, json=metasearch_body)
        response.raise_for_status()
        dbs = response.json().get(registry, [])

        if dbs:
            return f"mysql://{dbs[0]}"
        return None

    def get_xref_mapper(self, xref_url: str, species: str, base_path: str, release: int, core_url: Optional[str] = None, registry: Optional[str] = None) -> BasicMapper:
        """Retrieves a mapper object based on species.

        Parameters
        ----------
        xref_url: str
            The xref db connection URL.
        species: str
            The species name.
        base_path: str
            The base file path.
        release: int
            The Ensembl release number.
        core_url: Optional[str]
            The species core db connection URL.
        registry: Optional[str]
            The registry URL.

        Returns
        -------
        BasicMapper
            A mapper object.

        Raises
        ------
        AttributeError
            If neither core_url nor registry is provided.
        """
        # Need either core_url or registry
        if not core_url and not registry:
            raise AttributeError(
                "Method get_xref_mapper: need to provide either a core DB URL or a registry URL"
            )

        # Create needed db connections
        if not core_url:
            core_url = self.get_db_from_registry(species, "core", release, registry)

        core_db = self.get_db_engine(core_url)
        xref_db = self.get_db_engine(xref_url)

        # Extract host and dbname from xref URL
        xref_url_obj = make_url(xref_url)
        host = xref_url_obj.host
        dbname = xref_url_obj.database

        # Locate the fasta files
        cdna_path = self.get_path(base_path, species, release, "ensembl", "transcripts.fa")
        pep_path = self.get_path(base_path, species, release, "ensembl", "peptides.fa")

        # Try to find a species-specific mapper first
        module_name = f"ensembl.production.xrefs.mappers.species.{species}"
        class_name = species
        found = importlib.util.find_spec(module_name)
        if not found:
            module_name = "ensembl.production.xrefs.mappers.BasicMapper"
            class_name = "BasicMapper"

        # Create a mapper object
        module = importlib.import_module(module_name)
        module_class = getattr(module, class_name)
        mapper = module_class()

        mapper.xref(xref_db)
        mapper.add_meta_pair("xref", f"{host}:{dbname}")
        mapper.core(core_db)
        mapper.add_meta_pair("species", f"{host}:{dbname}")
        mapper.dna_file(cdna_path)
        mapper.protein_file(pep_path)
        mapper.log_file(self._log_file)
        mapper.species_dir(os.path.join(base_path, species))

        return mapper
