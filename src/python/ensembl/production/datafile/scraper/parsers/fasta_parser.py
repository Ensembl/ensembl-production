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
"""FASTA File Parser for DataFile Scraper package"""

from dataclasses import dataclass
import re
from typing import Optional

from .file_parser import BaseOptMetadata, FileParser, FILE_COMPRESSIONS
from ..utils import get_group


@dataclass
class FASTAOptMetadata(BaseOptMetadata):
    compression: Optional[str]
    content_type: Optional[str]
    sequence_type: str


class FASTAFileParser(FileParser):
    FILENAMES_RE = re.compile(
        (
            r"^(?P<species>\w+)\.(?P<assembly>[\w\-\.]+?)\.(?P<sequence_type>dna(_sm|_rm)?|cdna|cds|pep|ncrna)\."
            r"(?P<content_type>abinitio|all|alt|toplevel|nonchromosomal|(chromosome|plasmid|scaffold)\.[\w\-\.]+?|primary_assembly[\w\-\.]*?|(chromosome_)?group\.\w+?)?.*?"
        )
    )
    FILE_EXT_RE = re.compile(
        r".*?\.(?P<file_extension>fa)(\.(?P<compression>gz)?(\.gzi|\.fai)?)?$"
    )

    def get_optional_metadata(self, metadata: dict) -> FASTAOptMetadata:
        match = self.FILENAMES_RE.match(metadata["file_name"])
        matched_sequence_type = get_group("sequence_type", match)
        matched_content_type = get_group("content_type", match)
        match = self.FILE_EXT_RE.match(metadata["file_name"])
        file_extension = get_group("file_extension", match)
        matched_compression = FILE_COMPRESSIONS.get(get_group("compression", match))
        compression = (
            metadata.get("extras", {}).get("compression") or matched_compression
        )
        content_type = (
            metadata.get("extras", {}).get("content_type") or matched_content_type
        )
        sequence_type = (
            metadata.get("extras", {}).get("sequence_type") or matched_sequence_type
        )
        optional_data = FASTAOptMetadata(
            compression=compression,
            file_extension=file_extension,
            content_type=content_type,
            sequence_type=sequence_type,
        )
        return optional_data