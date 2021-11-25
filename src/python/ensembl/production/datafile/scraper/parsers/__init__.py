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
"""Package containing file parsers for DataFile Scraper"""

from typing import Optional, Tuple, Type

from .bam import *
from .embl import *
from .fasta import *
from .base_parser import *


_PARSERS = {
    "embl": EMBLFileParser,
    "genbank": EMBLFileParser,
    "gff3": EMBLFileParser,
    "gtf": EMBLFileParser,
    "fasta": FASTAFileParser,
    "bamcov": BAMFileParser,
}


def get_parser(
    file_format: str, file_path: str
) -> Tuple[Optional[Type[FileParser]], Optional[Result]]:
    ParserClass = _PARSERS.get(file_format)
    if ParserClass is None:
        err = f"Invalid file_format: {file_format} for {file_path}"
        return None, Result(None, [err])
    return ParserClass, None
