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
"""Embl (GFF3, GTF) File Parser for DataFile Scraper package."""

from dataclasses import dataclass
import re
from typing import Optional

from ..utils import get_group
from .base import BaseOptMetadata, FileParser, _FILE_COMPRESSIONS_MAP


@dataclass
class EMBLOptMetadata(BaseOptMetadata):
    compression: Optional[str]
    content_type: Optional[str]
    sorting: Optional[str]


class EMBLFileParser(FileParser):
    FILENAMES_RE = re.compile(
        (
            r"^(?P<species>\w+)\.(?P<assembly>[\w\-\.]+?)\.(5|1)\d{1,2}\."
            r"(?P<content_type>abinitio|chr|chr_patch_hapl_scaff|nonchromosomal|(chromosome|plasmid|scaffold)\.[\w\-\.]+?|primary_assembly[\w\-\.]*?|(chromosome_)?group\.\w+?)?.*?"
        )
    )
    FILE_EXT_RE = re.compile(
        (
            r".*?\.(?P<file_extension>gff3|gtf|dat)"
            r"(\.(?P<sorted>sorted))?(\.(?P<compression>gz))?$"
        )
    )

    def get_optional_metadata(self, metadata: dict) -> EMBLOptMetadata:
        match = self.FILENAMES_RE.match(metadata["file_name"])
        matched_content_type = get_group("content_type", match)
        match = self.FILE_EXT_RE.match(metadata["file_name"])
        matched_compression = _FILE_COMPRESSIONS_MAP.get(get_group("compression", match))
        file_extension = get_group("file_extension", match)
        matched_sorting = get_group("sorted", match)
        compression = (
            metadata.get("extras", {}).get("compression") or matched_compression
        )
        content_type = (
            metadata.get("extras", {}).get("content_type") or matched_content_type
        )
        sorting = metadata.get("extras", {}).get("sorting") or matched_sorting
        optional_data = EMBLOptMetadata(
            compression=compression,
            file_extension=file_extension,
            content_type=content_type,
            sorting=sorting,
        )
        return optional_data