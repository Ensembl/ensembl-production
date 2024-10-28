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

"""Parser module for DBASS sources."""

import csv
import re
from typing import Any, Dict, Optional, Tuple
from sqlalchemy.engine import Connection

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class DBASSParser(BaseParser):
    EXPECTED_NUMBER_OF_COLUMNS = 23
    SLASH_PATTERN = re.compile(r"(.*)\s?/\s?(.*)", re.IGNORECASE | re.DOTALL)
    PARENS_PATTERN = re.compile(r"(.*)\s?\((.*)\)", re.IGNORECASE | re.DOTALL)

    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        with self.get_filehandle(xref_file) as file_io:
            if file_io.read(1) == '':
                raise IOError(f"DBASS file is empty")
            file_io.seek(0)

            csv_reader = csv.reader(file_io)
            header = next(csv_reader)
            patterns = [r"^id$", r"^genesymbol$", None, r"^ensemblreference$"]
            if not self.is_file_header_valid(self.EXPECTED_NUMBER_OF_COLUMNS, patterns, header):
                raise ValueError(f"Malformed or unexpected header in DBASS file {xref_file}")

            processed_count, unmapped_count = self.process_lines(csv_reader, source_id, species_id, xref_dbi)

        result_message = f"{processed_count} direct xrefs successfully processed\n"
        result_message += f"Skipped {unmapped_count} unmapped xrefs"
        return 0, result_message

    def process_lines(self, csv_reader: csv.reader, source_id: int, species_id: int, xref_dbi: Connection) -> Tuple[int, int]:
        processed_count = 0
        unmapped_count = 0

        for line in csv_reader:
            if not line:
                continue

            if len(line) < self.EXPECTED_NUMBER_OF_COLUMNS:
                raise ValueError(f"Line {csv_reader.line_num} of input file has an incorrect number of columns")

            dbass_gene_id, dbass_gene_name, dbass_full_name, ensembl_id = line[:4]

            if not ensembl_id.strip():
                unmapped_count += 1
                continue

            first_gene_name, second_gene_name = self.extract_gene_names(dbass_gene_name)
            xref_id = self.add_xref(
                {
                    "accession": dbass_gene_id,
                    "version": "1",
                    "label": first_gene_name,
                    "source_id": source_id,
                    "species_id": species_id,
                    "info_type": "DIRECT",
                },
                xref_dbi,
            )
            self.add_direct_xref(xref_id, ensembl_id, "gene", "", xref_dbi)

            if second_gene_name:
                self.add_synonym(xref_id, second_gene_name, xref_dbi)

            processed_count += 1

        return processed_count, unmapped_count

    def extract_gene_names(self, dbass_gene_name: str) -> Tuple[Optional[str], Optional[str]]:
        match = self.SLASH_PATTERN.search(dbass_gene_name) or self.PARENS_PATTERN.search(dbass_gene_name)
        if match:
            return match.groups()
        return dbass_gene_name, None
