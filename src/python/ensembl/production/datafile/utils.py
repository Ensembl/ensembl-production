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

from datetime import datetime
import csv
from functools import partial, lru_cache
import hashlib
import json
from typing import Tuple, NamedTuple, List, Optional, TextIO, Generator

import sqlalchemy as sa


def blake2bsum(file_path: str, chunk_size: Optional[int] = None) -> bytes:
    """Returns blake2b binary digest of a file.

    The file is read sequentially in chunks to prevent large files from taking
    too much memory.

    Args:
        file_path: The path of the file on the files system
        chunk_size: The size of the chunks in bytes (default: 524288)
    """
    chunk_size_n = chunk_size if chunk_size else 2 ** 19
    b2bh = hashlib.blake2b()
    with open(file_path, "rb") as file:
        for chunk in iter(partial(file.read, chunk_size_n), b""):
            b2bh.update(chunk)
    return b2bh.digest()


@lru_cache(maxsize=None)
def _get_engine(metadata_url: str) -> sa.engine.Engine:
    return sa.create_engine(metadata_url)


class ENSMetadata(NamedTuple):
    species: str
    taxon_id: int
    species_taxon_id: int
    genome_id: int
    assembly_default: str
    assembly_accession: str
    release_date: datetime
    division: str


@lru_cache(maxsize=None)
def get_metadata_from_db(
    metadata_url: str, species: str, ens_version: int
) -> Tuple[List[ENSMetadata], Optional[str]]:
    sql = """
        SELECT
            o.name AS organism_name,
            o.taxonomy_id,
        	o.species_taxonomy_id,
        	g.genome_id,
        	a.assembly_default,
        	a.assembly_accession,
        	r.release_date,
        	d.name AS division
        FROM organism AS o
        JOIN genome AS g ON o.organism_id=g.organism_id
        JOIN assembly AS a ON g.assembly_id=a.assembly_id
        JOIN data_release AS r ON g.data_release_id=r.data_release_id
        JOIN division AS d ON g.division_id=d.division_id
        WHERE o.name = :species
        AND r.ensembl_version = :ens_version
        GROUP BY a.assembly_default, o.name;
    """
    with _get_engine(metadata_url).connect() as conn:
        metadata = conn.execute(
            sa.text(sql), species=species, ens_version=ens_version
        ).fetchall()
    if metadata:
        err = None
        if len(metadata) > 1:
            err = f"Multiple records found for {species} (release {ens_version}) on {metadata_url}"
        return ([ENSMetadata(*meta) for meta in metadata], err)
    err = f"No metadata record found for {species} (release {ens_version}) on {metadata_url}"
    return ([], err)


class ManifestRow(NamedTuple):
    file_format: str
    species: str
    ens_release: int
    file_name: str
    extras: dict


def manifest_rows(manifest_f: TextIO) -> Generator[ManifestRow, None, None]:
    reader = csv.DictReader(manifest_f, restkey="unknown", dialect="excel-tab")
    reader.fieldnames = [clean_name(name) for name in reader.fieldnames]
    for row in reader:
        try:
            extras_str = row["extras"]
            extras = load_extras(extras_str)
            yield ManifestRow(
                file_format=clean_name(row["file_format"]),
                species=clean_name(row["species"]),
                ens_release=int(row["ens_release"]),
                file_name=row["file_name"],
                extras=extras,
            )
        except KeyError as err:
            raise ValueError(f"Missing column: {err}") from err


def clean_name(name: str) -> str:
    return name.strip().lower()


def load_extras(extras_str: str) -> dict:
    if extras_str:
        try:
            return json.loads(extras_str)
        except json.JSONDecodeError as err:
            raise ValueError(f"Invalid JSON format for column 'extras': {err}") from err
    return {}
