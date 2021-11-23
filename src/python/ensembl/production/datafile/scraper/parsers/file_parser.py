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
"""Base File Parser for DataFile Scraper package"""

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from urllib.parse import urljoin

from ..utils import blake2bsum, make_release


FILE_COMPRESSIONS = {"gz": "gzip"}


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
    file_set_id: Optional[int]
    file_format: str
    release: Release
    assembly: Assembly
    file_size: int
    file_last_modified: str
    blake2bsum: str
    urls: List[FileURL]
    species: Species
    optional_data: BaseOptMetadata


@dataclass
class Result:
    file_metadata: Optional[FileMetadata]
    errors: List[str]


class FileParserError(ValueError):
    def __init__(self, message: str, errors: dict) -> None:
        super().__init__(message)
        self.errors = errors


class BaseFileParser:
    def __init__(self, **options) -> None:
        self._options = options
        self._ftp_dirs = [
            (Path(options.get("ftp_dir_ens", "")).resolve(), options.get("ftp_url_ens")),
            (Path(options.get("ftp_dir_eg", "")).resolve(), options.get("ftp_url_eg")),
        ]

    def parse_metadata(self, metadata: dict) -> Result:
        errors: List[str] = []
        file_path = (Path(metadata["file_dir"]) / metadata["file_name"]).resolve()
        try:
            base_metadata = self.get_base_metadata(metadata)
        except ValueError as e:
            errors.append(f"Error parsing base metadata: {e}")
        try:
            optional_data = self.get_optional_metadata(metadata)
        except ValueError as e:
            errors.append(f"Error parsing optional metadata: {e}")
        if errors:
            errors.insert(0, f"Cannot parse {file_path}")
            return Result(None, errors)
        file_stats = file_path.stat()
        last_modified = (
            datetime.fromtimestamp(file_stats.st_mtime).astimezone().isoformat()
        )
        b2bsum_chunk_size = self._options.get("b2bsum_chunk_size")
        b2bsum = blake2bsum(file_path, b2bsum_chunk_size).hex()
        ftp_uri = self.get_ftp_uri(file_path)
        file_metadata = FileMetadata(
            file_path=str(file_path),
            file_set_id=metadata.get("file_set_id"),
            file_format=metadata["file_format"],
            release=Release(
                *make_release(int(metadata["ens_release"])), date=metadata["release_date"]
            ),
            assembly=Assembly(
                default=metadata["assembly_default"],
                accession=metadata["assembly_accession"],
                provider_name="",
                genome_id=metadata["genome_id"],
            ),
            file_size=file_stats.st_size,
            file_last_modified=last_modified,
            blake2bsum=b2bsum,
            urls=[FileURL(ftp_uri, {})],
            species=Species(
                production_name=base_metadata.species,
                division=metadata["division"],
                taxon_id=metadata["taxon_id"],
                species_taxon_id=metadata["species_taxon_id"],
                classifications=[metadata["division"]],
            ),
            optional_data=optional_data,
        )
        result = Result(file_metadata, errors)
        return result

    def _ftp_paths(self, file_path: Path) -> Tuple[str, Optional[Path]]:
        for ftp_root_dir, ftp_root_uri in self._ftp_dirs:
            try:
                relative_path = file_path.relative_to(ftp_root_dir)
                return ftp_root_uri, relative_path
            except (ValueError, TypeError):
                pass
        return "", None

    def get_ftp_uri(self, file_path: Path) -> str:
        ftp_root_uri, relative_path = self._ftp_paths(file_path)
        if relative_path is not None:
            ftp_uri = urljoin(ftp_root_uri, str(relative_path))
            return ftp_uri
        return "none"

    def get_base_metadata(self, metadata: dict) -> BaseFileMetadata:
        raise NotImplementedError(
            "Calling abstract method: BaseFileParser.get_base_metadata"
        )

    def get_optional_metadata(self, metadata: dict) -> BaseOptMetadata:
        raise NotImplementedError(
            "Calling abstract method: BaseFileParser.get_optional_metadata"
        )


class FileParser(BaseFileParser):
    def get_base_metadata(self, metadata: dict) -> BaseFileMetadata:
        return BaseFileMetadata(
            file_type=metadata["file_format"].lower(),
            species=metadata["species"].lower(),
            ens_release=int(metadata["ens_release"]),
        )
