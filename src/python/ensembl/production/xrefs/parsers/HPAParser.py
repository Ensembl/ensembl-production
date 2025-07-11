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

"""Parser module for HPA source."""

import csv
from typing import Dict, Any, Tuple
from sqlalchemy.engine import Connection

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class HPAParser(BaseParser):
    EXPECTED_NUMBER_OF_COLUMNS = 4

    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        with self.get_filehandle(xref_file) as file_io:
            if file_io.read(1) == '':
                raise IOError("HPA file is empty")
            file_io.seek(0)

            csv_reader = csv.reader(file_io, delimiter=",", strict=True)
            header = next(csv_reader)
            patterns = [r"^antibody$", r"^antibody_id$", r"^ensembl_peptide_id$", r"^link$"]
            if not self.is_file_header_valid(self.EXPECTED_NUMBER_OF_COLUMNS, patterns, header):
                raise ValueError(f"Malformed or unexpected header in HPA file {xref_file}")

            parsed_count = self.process_lines(csv_reader, source_id, species_id, xref_dbi)

        result_message = f"{parsed_count} direct xrefs successfully parsed"
        return 0, result_message

    def process_lines(self, csv_reader: csv.reader, source_id: int, species_id: int, xref_dbi: Connection) -> int:
        parsed_count = 0

        for line in csv_reader:
            if not line:
                continue

            if len(line) < self.EXPECTED_NUMBER_OF_COLUMNS:
                raise ValueError(f"Line {csv_reader.line_num} of input file has an incorrect number of columns")

            antibody_name, antibody_id, ensembl_id = line[:3]

            xref_id = self.add_xref(
                {
                    "accession": antibody_id,
                    "version": "1",
                    "label": antibody_name,
                    "source_id": source_id,
                    "species_id": species_id,
                    "info_type": "DIRECT",
                },
                xref_dbi,
            )
            self.add_direct_xref(xref_id, ensembl_id, "translation", "", xref_dbi)

            parsed_count += 1

        return parsed_count
