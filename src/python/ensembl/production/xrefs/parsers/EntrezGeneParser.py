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

"""Parser module for EntrezGene and WikiGene sources."""

import csv
import logging
import re
from typing import Any, Dict, Tuple
from sqlalchemy.engine import Connection

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class EntrezGeneParser(BaseParser):
    EXPECTED_NUMBER_OF_COLUMNS = 16
    SYNONYM_SPLITTER = re.compile(r"\|")

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
                raise IOError("EntrezGene file is empty")
            file_io.seek(0)

            csv_reader = csv.reader(file_io, delimiter="\t")
            header = next(csv_reader)
            patterns = [
                r"\A[#]?\s*tax_id$",
                r"^geneid$",
                r"^symbol$",
                r"^locustag$",
                r"^synonyms$",
                r"^dbxrefs$",
                r"^chromosome$",
                r"^map_location$",
                r"^description$",
                r"^type_of_gene$",
                r"^symbol_from_nomenclature_authority$",
                r"^full_name_from_nomenclature_authority$",
                r"^nomenclature_status$",
                r"^other_designations$",
                r"^modification_date$",
                r"^feature_type$",
            ]
            if not self.is_file_header_valid(self.EXPECTED_NUMBER_OF_COLUMNS, patterns, header):
                raise ValueError(f"Malformed or unexpected header in EntrezGene file {xref_file}")

            wiki_source_id = self.get_source_id_for_source_name("WikiGene", xref_dbi)
            if verbose:
                logging.info(f"Wiki source id = {wiki_source_id}")

            processed_count, syn_count = self.process_lines(csv_reader, source_id, species_id, wiki_source_id, xref_dbi)

        result_message = f"{processed_count} EntrezGene Xrefs and {processed_count} WikiGene Xrefs added with {syn_count} synonyms"
        return 0, result_message

    def process_lines(self, csv_reader: csv.reader, source_id: int, species_id: int, wiki_source_id: int, xref_dbi: Connection) -> Tuple[int, int]:
        processed_count = 0
        syn_count = 0
        seen = {}

        for line in csv_reader:
            if not line:
                continue

            if len(line) < self.EXPECTED_NUMBER_OF_COLUMNS:
                raise ValueError(f"Line {csv_reader.line_num} of input file has an incorrect number of columns")

            tax_id = int(line[0])
            acc = line[1]
            symbol = line[2]
            synonyms = line[4]
            desc = line[8]

            if tax_id != species_id or acc in seen:
                continue

            xref_id = self.add_xref(
                {
                    "accession": acc,
                    "label": symbol,
                    "description": desc,
                    "source_id": source_id,
                    "species_id": species_id,
                    "info_type": "DEPENDENT",
                },
                xref_dbi,
            )
            self.add_xref(
                {
                    "accession": acc,
                    "label": symbol,
                    "description": desc,
                    "source_id": wiki_source_id,
                    "species_id": species_id,
                    "info_type": "DEPENDENT",
                },
                xref_dbi,
            )

            processed_count += 1

            if synonyms.strip() != "-":
                syns = self.SYNONYM_SPLITTER.split(synonyms)
                for synonym in syns:
                    self.add_synonym(xref_id, synonym, xref_dbi)
                    syn_count += 1

            seen[acc] = True

        return processed_count, syn_count
