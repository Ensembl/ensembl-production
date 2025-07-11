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

"""Parser module for MGI Descriptions."""

import csv
import logging
import re
from typing import Any, Dict, Tuple
from sqlalchemy.engine import Connection

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class MGIDescParser(BaseParser):
    EXPECTED_NUMBER_OF_COLUMNS = 12
    SYNONYM_SPLITTER = re.compile(r"[|]")

    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")
        verbose = args.get("verbose", False)

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        with self.get_filehandle(xref_file) as file_io:
            if file_io.read(1) == '':
                raise IOError("MGI_desc file is empty")
            file_io.seek(0)

            csv_reader = csv.reader(file_io, delimiter="\t", strict=True, quotechar=None, escapechar=None)
            header = next(csv_reader)
            patterns = [
                r"^mgi accession id$",
                r"^chr$",
                r"^cm position$",
                r"^genome coordinate start$",
                r"^genome coordinate end$",
                r"^strand$",
                r"^marker symbol$",
                r"^status$",
                r"^marker name$",
                r"^marker type$",
                r"^feature type$",
                r"^marker synonyms \(pipe-separated\)$",
            ]
            if not self.is_file_header_valid(self.EXPECTED_NUMBER_OF_COLUMNS, patterns, header):
                raise ValueError(f"Malformed or unexpected header in MGI_desc file {xref_file}")

            xref_count, syn_count = self.process_lines(csv_reader, source_id, species_id, xref_dbi, verbose)

        result_message = f"{xref_count} MGI Description Xrefs added\n{syn_count} synonyms added"
        return 0, result_message

    def process_lines(self, csv_reader: csv.reader, source_id: int, species_id: int, xref_dbi: Connection, verbose: bool) -> Tuple[int, int]:
        xref_count = 0
        syn_count = 0

        for line in csv_reader:
            if not line:
                continue

            if len(line) < self.EXPECTED_NUMBER_OF_COLUMNS:
                raise ValueError(f"Line {csv_reader.line_num} of input file has an incorrect number of columns")

            accession = line[0]
            label = line[6]
            marker = line[8]
            synonym_field = line[11]

            xref_id = self.add_xref(
                {
                    "accession": accession,
                    "label": label,
                    "description": marker,
                    "source_id": source_id,
                    "species_id": species_id,
                    "info_type": "MISC",
                },
                xref_dbi,
            )

            if not marker and verbose:
                logging.info(f"{accession} has no description")

            xref_count += 1

            if synonym_field:
                synonyms = self.SYNONYM_SPLITTER.split(synonym_field)
                for synonym in synonyms:
                    self.add_synonym(xref_id, synonym, xref_dbi)
                    syn_count += 1

        return xref_count, syn_count
