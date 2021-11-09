import hashlib
from functools import partial, lru_cache
from typing import Tuple, NamedTuple, List, Optional
from datetime import datetime
from pathlib import Path
from urllib.parse import urljoin

import sqlalchemy as sa
from settings import SETTINGS


FTP_DIRS = (
    (SETTINGS.get('ftp_dir_ens', '/nfs/ensemblftp/PUBLIC/pub'), 'ftp://ftp.ensembl.org/pub'),
    (SETTINGS.get('ftp_dir_eg', '/nfs/ensemblgenomes/ftp/pub'), 'ftp://ftp.ensemblgenomes.org/pub')
)


def blake2bsum(file_path: str, chunk_size: int = 2**19) -> bytes:
    """Returns blake2b binary digest of a file.

    The file is read sequentially in chunks to prevent large files from taking
    too much memory.

    Args:
        file_path: The path of the file on the files system
        chunk_size: The size of the chunks in bytes (default: 524288)
    """
    b2bh = hashlib.blake2b()
    with open(file_path, 'rb') as f:
        for chunk in iter(partial(f.read, chunk_size), b''):
            b2bh.update(chunk)
    return b2bh.digest()


def _ftp_paths(filepath: Path) -> Tuple[str, Optional[Path]]:
    for ftp_root_dir, ftp_root_uri in FTP_DIRS:
        ftp_dir = Path(ftp_root_dir)
        try:
            relative_path = filepath.relative_to(ftp_dir)
            return ftp_root_uri, relative_path
        except ValueError:
            pass
    return '', None


def get_ftp_uri(file_path: str) -> str:
    filepath = Path(file_path).resolve()
    ftp_root_uri, relative_path = _ftp_paths(filepath)
    if relative_path is not None:
        ftp_uri = urljoin(ftp_root_uri, relative_path)
        return ftp_uri
    return 'none'


def remove_none(elem: dict, recursive: bool = False) -> dict:
    if recursive:
        new_dict = {}
        for key, value in elem.items():
            if isinstance(value, dict):
                new_dict[key] = remove_none(value)
            elif value is not None:
                new_dict[key] = value
        return new_dict
    return {k: v for k, v in elem.items() if v is not None}


def substitute_none(elem: dict, recursive: bool = False) -> None:
    for key, value in elem.items():
        if recursive:
            if isinstance(value, dict):
                substitute_none(value)
        if value is None:
            elem[key] = 'NULL'


@lru_cache(maxsize=None)
def _get_engine(metadata_url: str) -> sa.engine.Engine :
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
def get_metadata_from_db(metadata_url: str, species: str, ens_version: int) -> Tuple[List[ENSMetadata], Optional[str]]:
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
            err = f'Multiple records found for {species} (release {ens_version}) on {metadata_url}'
        return ([ENSMetadata(*meta) for meta in metadata], err)
    err = f'No metadata record found for {species} (release {ens_version}) on {metadata_url}'
    return ([], err)
