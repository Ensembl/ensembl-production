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
"""Bamcov File Parser for DataFile Scraper package"""

from dataclasses import dataclass
import re
from typing import Optional

from ..utils import get_group
from .base import BaseOptMetadata, FileParser


@dataclass
class BAMOptMetadata(BaseOptMetadata):
    source: Optional[str]
    origin: Optional[str]


class BAMFileParser(FileParser):
    FILENAMES_RE = re.compile(
        r"^(?P<assembly>.+?)(\.(?P<source>[a-zA-Z]{2,}))?\.(?P<origin>[\w\-]+)(\.\d)?.*?"
    )
    FILE_EXT_RE = re.compile(r".*?\.(?P<file_extension>(bam(\..{2,})?)|txt)$")

    def get_optional_metadata(self, metadata: dict) -> BAMOptMetadata:
        match = self.FILENAMES_RE.match(metadata["file_name"])
        matched_source = get_group("source", match)
        matched_origin = get_group("origin", match)
        match = self.FILE_EXT_RE.match(metadata["file_name"])
        file_extension = get_group("file_extension", match)
        source = metadata.get("extras", {}).get("source") or matched_source
        origin = metadata.get("extras", {}).get("origin") or matched_origin
        optional_data = BAMOptMetadata(
            file_extension=file_extension,
            source=source,
            origin=origin,
        )
        return optional_data
