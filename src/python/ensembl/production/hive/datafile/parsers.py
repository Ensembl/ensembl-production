import csv
import json
from pathlib import Path
import re
from typing import Dict, List, Optional, TextIO, Generator
from dataclasses import dataclass, asdict
from datetime import datetime
from utils import blake2bsum, get_ftp_uri


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
    date: datetime


@dataclass
class Assembly:
    default: str
    accession: str
    provider_name: str
    genome_id: int


@dataclass
class BaseOptMetadata:
    file_extension: Optional[str]
    assembly: Optional[str]


@dataclass
class BaseFileMetadata:
    file_type: str
    species: str
    ens_release: int


@dataclass
class FileMetadata(BaseFileMetadata):
    file_path: str
    size: int
    last_modified: datetime
    blake2bsum: bytes
    url: FileURL
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


@dataclass
class ManifestRow:
    file_format: str
    species: str
    ens_release: int
    file_name: str
    extras: dict


def get_group(group_name: str, match: Optional[re.Match], default: Optional[str] = None) -> Optional[str]:
    if match:
        try:
            return match.group(group_name)
        except IndexError:
            pass
    return default


class FileParserError(ValueError):
    def __init__(self, message: str, errors: dict) -> None:
        super().__init__(message)
        self.errors = errors


class BaseFileParser:
    def __init__(self, **options) -> None:
        self._options = options

    def get_metadata(self, directory: str, manifest_data: ManifestRow) -> FileMetadata:
        errors = {}
        file_path = Path(directory) / manifest_data.file_name
        try:
            base_metadata = self.base_metadata(manifest_data)
        except ValueError as e:
            errors['base_metadata_err'] = str(e)
        try:
            optional_data = self.optional_metadata(manifest_data)
        except ValueError as e:
            errors['optional_data_err'] = str(e)
        if errors:
            raise FileParserError(f'Cannot parse {file_path}', errors)
        file_stats = file_path.stat()
        last_modified = datetime.fromtimestamp(file_stats.st_mtime).astimezone() #.isoformat()
        b2bsum_chunk_size = self._options.get('b2bsum_chunk_size')
        if b2bsum_chunk_size:
            b2bsum = blake2bsum(file_path, int(b2bsum_chunk_size))
        else:
            b2bsum = blake2bsum(file_path)
        ftp_uri = get_ftp_uri(file_path)
        metadata = FileMetadata(
            file_path=str(file_path),
            size=file_stats.st_size,
            last_modified=last_modified,
            blake2bsum=b2bsum,
            uri=ftp_uri,
            optional_data=optional_data,
            **asdict(base_metadata)
        )
        return metadata

    def base_metadata(self, manifest_data: ManifestRow) -> BaseFileMetadata:
        raise NotImplementedError('Calling abstract method: BaseFileParser.base_metadata')

    def optional_metadata(self, manifest_data: ManifestRow) -> BaseOptMetadata:
        raise NotImplementedError('Calling abstract method: BaseFileParser.optional_metadata')


class FileParser(BaseFileParser):
    def base_metadata(self, manifest_data: ManifestRow) -> BaseFileMetadata:
        match = self.FILENAMES_RE.match(manifest_data.file_name)
        matched_species = get_group("species", match, '')
        species = manifest_data.species or matched_species
        metadata = BaseFileMetadata(
            file_type=manifest_data.file_format.lower(),
            species=species.lower(),
            ens_release=manifest_data.ens_release
        )
        return metadata


class EMBLFileParser(FileParser):
    FILENAMES_RE = re.compile(
        (r'^(?P<species>\w+)\.(?P<assembly>[\w\-\.]+?)\.(5|1)\d{1,2}\.'
        r'\.?(?P<content_type>abinitio|chr|chr_patch_hapl_scaff|nonchromosomal|(chromosome|plasmid|scaffold)\.[\w\-\.]+?|primary_assembly[\w\-\.]*?|(chromosome_)?group\.\w+?)?.*?')
    )
    FILE_EXT_RE = re.compile(
        (r'.*?\.?(?P<file_extension>gff3|gtf|dat)\.?(?P<compression>gz)?'
        r'\.?(?P<sorted>sorted)?\.?(gz)?$')
    )

    def optional_metadata(self, manifest_data: ManifestRow) -> EMBLOptMetadata:
        match = self.FILENAMES_RE.match(manifest_data.file_name)
        matched_assembly = get_group("assembly", match)
        matched_compression = FILE_COMPRESSIONS.get(get_group('compression', match))
        matched_content_type = get_group('content_type', match)
        match = self.FILE_EXT_RE.match(manifest_data.file_name)
        file_extension = get_group("file_extension", match)
        matched_sorting = get_group("sorted", match)
        assembly = manifest_data.extras.get("assembly") or matched_assembly
        compression = manifest_data.extras.get('compression') or matched_compression
        content_type = manifest_data.extras.get('content_type') or matched_content_type
        sorting = manifest_data.extras.get("sorting") or matched_sorting
        optional_data = EMBLOptMetadata(
            compression=compression,
            file_extension=file_extension,
            content_type=content_type,
            sorting=sorting,
            assembly=assembly,
        )
        return optional_data


class FASTAFileParser(FileParser):
    FILENAMES_RE = re.compile(
        (r'^(?P<species>\w+)\.(?P<assembly>[\w\-\.]+?)\.(?P<sequence_type>dna(_sm|_rm)?|cdna|cds|pep|ncrna)\.'
        r'\.?(?P<content_type>abinitio|all|alt|toplevel|nonchromosomal|(chromosome|plasmid|scaffold)\.[\w\-\.]+?|primary_assembly[\w\-\.]*?|(chromosome_)?group\.\w+?)?.*?')
    )
    FILE_EXT_RE = re.compile(r'.*?\.?(?P<file_extension>fa)\.?(?P<compression>gz)?(\.gzi|\.fai)?$')

    def optional_metadata(self, manifest_data: ManifestRow) -> FASTAOptMetadata:
        match = self.FILENAMES_RE.match(manifest_data.file_name)
        matched_assembly = get_group("assembly", match)
        matched_sequence_type = get_group("sequence_type", match)
        matched_content_type = get_group("content_type", match)
        match = self.FILE_EXT_RE.match(manifest_data.file_name)
        file_extension = get_group("file_extension", match)
        matched_compression = FILE_COMPRESSIONS.get(get_group('compression', match), None)
        compression = manifest_data.extras.get("compression") or matched_compression
        content_type = manifest_data.extras.get("content_type") or matched_content_type
        sequence_type = manifest_data.extras.get("sequence_type") or matched_sequence_type
        assembly = manifest_data.extras.get("assembly") or matched_assembly
        optional_data = FASTAOptMetadata(
            compression=compression,
            file_extension=file_extension,
            content_type=content_type,
            sequence_type=sequence_type,
            assembly=assembly,
        )
        return optional_data


class BAMFileParser(FileParser):
    FILENAMES_RE = re.compile(
        r'^(?P<assembly>.+?)(\.(?P<source>[a-zA-Z]{2,}))?\.(?P<origin>[\w\-]+?)(\.\d)?.*?'
    )
    FILE_EXT_RE = re.compile(r'.*?\.(?P<file_extension>(bam(\..{2,})?)|txt)$')

    def optional_metadata(self, manifest_data: ManifestRow) -> BAMOptMetadata:
        match = self.FILENAMES_RE.match(manifest_data.file_name)
        matched_assembly = get_group("assembly", match)
        matched_source = get_group("source", match)
        matched_origin = get_group("origin", match)
        match = self.FILE_EXT_RE.match(manifest_data.file_name)
        file_extension = get_group("file_extension", match)
        assembly = manifest_data.extras.get("assembly") or matched_assembly
        source = manifest_data.extras.get("source") or matched_source
        origin = manifest_data.extras.get("origin") or matched_origin
        optional_data = BAMOptMetadata(
            file_extension=file_extension,
            source=source,
            origin=origin,
            assembly=assembly
        )
        return optional_data


def manifest_rows(manifest_f: TextIO) -> Generator[ManifestRow, None, None]:
    reader = csv.DictReader(manifest_f, restkey='unknown', dialect='excel-tab')
    reader.fieldnames = [clean_name(name) for name in reader.fieldnames]
    for row in reader:
        try:
            extras_str = row['extras']
            extras = load_extras(extras_str)
            yield ManifestRow(
                file_format=clean_name(row['file_format']),
                species=clean_name(row['species']),
                ens_release=int(row['ens_release']),
                file_name=row['file_name'],
                extras=extras
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