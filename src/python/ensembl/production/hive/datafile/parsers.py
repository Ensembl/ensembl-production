from dataclasses import dataclass
from datetime import datetime
import os
from pathlib import Path
import re
from typing import Dict, List, Tuple, Optional
from urllib.parse import urljoin

from .utils import blake2bsum, make_release, get_group


FILE_COMPRESSIONS = {
    'gz': 'gzip'
}


@dataclass
class FileURL:
    url: str
    headers: Dict[str, str]


@dataclass
class Species:
    production_name: str
    division: str
    taxon_id: int
    species_taxon_id: int
    classifications: List[str]


@dataclass
class Release:
    ens: int
    eg: int
    date: str


@dataclass
class Assembly:
    default: str
    accession: str
    provider_name: str
    genome_id: int


@dataclass
class BaseOptMetadata:
    file_extension: Optional[str]


@dataclass
class BaseFileMetadata:
    file_type: str
    species: str
    ens_release: int


@dataclass
class FileMetadata:
    file_path: str
    file_format: str
    release: Release
    assembly: Assembly
    file_size: int
    file_last_modified: str
    blake2bsum: bytes
    urls: List[FileURL]
    species: Species
    optional_data: BaseOptMetadata


@dataclass
class EMBLOptMetadata(BaseOptMetadata):
    compression: Optional[str]
    content_type: Optional[str]
    sorting: Optional[str]


@dataclass
class BAMOptMetadata(BaseOptMetadata):
    source: Optional[str]
    origin: Optional[str]


@dataclass
class FASTAOptMetadata(BaseOptMetadata):
    compression: Optional[str]
    content_type: Optional[str]
    sequence_type: str


class FileParserError(ValueError):
    def __init__(self, message: str, errors: dict) -> None:
        super().__init__(message)
        self.errors = errors


class BaseFileParser:
    def __init__(self, **options) -> None:
        self._options = options
        self._ftp_dirs = [
            (options.get('ftp_dir_ens'), options.get('ftp_url_ens')),
            (options.get('ftp_dir_eg'), options.get('ftp_url_eg')),
        ]

    def get_metadata(self, metadata: dict) -> FileMetadata:
        errors = {}
        file_path = metadata['file_path']
        try:
            base_metadata = self.get_base_metadata(metadata)
        except ValueError as e:
            errors['base_metadata_err'] = str(e)
        try:
            optional_data = self.get_optional_metadata(metadata)
        except ValueError as e:
            errors['optional_data_err'] = str(e)
        if errors:
            raise FileParserError(f'Cannot parse {file_path}', errors)
        file_stats = os.stat(file_path)
        last_modified = datetime.fromtimestamp(file_stats.st_mtime).astimezone().isoformat()
        b2bsum_chunk_size = self._options.get('b2bsum_chunk_size')
        b2bsum = blake2bsum(file_path, b2bsum_chunk_size)
        ftp_uri = self.get_ftp_uri(file_path)
        file_metadata = FileMetadata(
            file_path=file_path,
            file_format=metadata['file_format'],
            release=Release(
                *make_release(metadata['ens_release']),
                date=metadata['release_date']
            ),
            assembly=Assembly(
                default=metadata['assembly_default'],
                accession=metadata['assembly_accession'],
                provider_name='',
                genome_id=metadata['genome_id']
            ),
            file_size=file_stats.st_size,
            file_last_modified=last_modified,
            blake2bsum=b2bsum,
            urls=[FileURL(ftp_uri, {})],
            species=Species(
                production_name=base_metadata.species,
                division=metadata['division'],
                taxon_id=metadata['taxon_id'],
                species_taxon_id=metadata['species_taxon_id'],
                classifications=[metadata['division']],
            ),
            optional_data=optional_data,
        )
        return file_metadata

    def _ftp_paths(self, file_path: str) -> Tuple[str, Optional[Path]]:
        for ftp_root_dir, ftp_root_uri in self._ftp_dirs:
            try:
                ftp_dir = Path(ftp_root_dir)
                relative_path = Path(file_path).relative_to(ftp_dir)
                return ftp_root_uri, relative_path
            except (ValueError, TypeError):
                pass
        return '', None

    def get_ftp_uri(self, file_path: str) -> str:
        ftp_root_uri, relative_path = self._ftp_paths(file_path)
        if relative_path is not None:
            ftp_uri = urljoin(ftp_root_uri, str(relative_path))
            return ftp_uri
        return 'none'

    def get_base_metadata(self, metadata: dict) -> BaseFileMetadata:
        raise NotImplementedError('Calling abstract method: BaseFileParser.get_base_metadata')

    def get_optional_metadata(self, metadata: dict) -> BaseOptMetadata:
        raise NotImplementedError('Calling abstract method: BaseFileParser.get_optional_metadata')


class FileParser(BaseFileParser):
    def get_base_metadata(self, metadata: dict) -> BaseFileMetadata:
        return BaseFileMetadata(
            file_type=metadata['file_format'].lower(),
            species=metadata['species'].lower(),
            ens_release=int(metadata['ens_release'])
        )


class EMBLFileParser(FileParser):
    FILENAMES_RE = re.compile(
        (r'^(?P<species>\w+)\.(?P<assembly>[\w\-\.]+?)\.(5|1)\d{1,2}\.'
        r'\.?(?P<content_type>abinitio|chr|chr_patch_hapl_scaff|nonchromosomal|(chromosome|plasmid|scaffold)\.[\w\-\.]+?|primary_assembly[\w\-\.]*?|(chromosome_)?group\.\w+?)?.*?')
    )
    FILE_EXT_RE = re.compile(
        (r'.*?\.?(?P<file_extension>gff3|gtf|dat)\.?(?P<compression>gz)?'
        r'\.?(?P<sorted>sorted)?\.?(gz)?$')
    )

    def get_optional_metadata(self, metadata: dict) -> EMBLOptMetadata:
        match = self.FILENAMES_RE.match(metadata['file_path'])
        matched_compression = FILE_COMPRESSIONS.get(get_group('compression', match))
        matched_content_type = get_group('content_type', match)
        match = self.FILE_EXT_RE.match(metadata['file_name'])
        file_extension = get_group("file_extension", match)
        matched_sorting = get_group("sorted", match)
        compression = metadata.get("extras", {}).get('compression') or matched_compression
        content_type = metadata.get("extras", {}).get('content_type') or matched_content_type
        sorting = metadata.get("extras", {}).get("sorting") or matched_sorting
        optional_data = EMBLOptMetadata(
            compression=compression,
            file_extension=file_extension,
            content_type=content_type,
            sorting=sorting,
        )
        return optional_data


class FASTAFileParser(FileParser):
    FILENAMES_RE = re.compile(
        (r'^(?P<species>\w+)\.(?P<assembly>[\w\-\.]+?)\.(?P<sequence_type>dna(_sm|_rm)?|cdna|cds|pep|ncrna)\.'
        r'\.?(?P<content_type>abinitio|all|alt|toplevel|nonchromosomal|(chromosome|plasmid|scaffold)\.[\w\-\.]+?|primary_assembly[\w\-\.]*?|(chromosome_)?group\.\w+?)?.*?')
    )
    FILE_EXT_RE = re.compile(r'.*?\.?(?P<file_extension>fa)\.?(?P<compression>gz)?(\.gzi|\.fai)?$')

    def get_optional_metadata(self, metadata: dict) -> FASTAOptMetadata:
        match = self.FILENAMES_RE.match(metadata['file_path'])
        matched_sequence_type = get_group("sequence_type", match)
        matched_content_type = get_group("content_type", match)
        match = self.FILE_EXT_RE.match(metadata['file_name'])
        file_extension = get_group("file_extension", match)
        matched_compression = FILE_COMPRESSIONS.get(get_group('compression', match), None)
        compression = metadata.get("extras", {}).get("compression") or matched_compression
        content_type = metadata.get("extras", {}).get("content_type") or matched_content_type
        sequence_type = metadata.get("extras", {}).get("sequence_type") or matched_sequence_type
        optional_data = FASTAOptMetadata(
            compression=compression,
            file_extension=file_extension,
            content_type=content_type,
            sequence_type=sequence_type
        )
        return optional_data


class BAMFileParser(FileParser):
    FILENAMES_RE = re.compile(
        r'^(?P<assembly>.+?)(\.(?P<source>[a-zA-Z]{2,}))?\.(?P<origin>[\w\-]+?)(\.\d)?.*?'
    )
    FILE_EXT_RE = re.compile(r'.*?\.(?P<file_extension>(bam(\..{2,})?)|txt)$')

    def get_optional_metadata(self, metadata: dict) -> BAMOptMetadata:
        match = self.FILENAMES_RE.match(metadata['file_name'])
        matched_source = get_group("source", match)
        matched_origin = get_group("origin", match)
        match = self.FILE_EXT_RE.match(metadata['file_name'])
        file_extension = get_group("file_extension", match)
        source = metadata.get("extras", {}).get("source") or matched_source
        origin = metadata.get("extras", {}).get("origin") or matched_origin
        optional_data = BAMOptMetadata(
            file_extension=file_extension,
            source=source,
            origin=origin,
        )
        return optional_data
