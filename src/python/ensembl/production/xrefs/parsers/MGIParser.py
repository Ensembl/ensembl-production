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

"""Parser module for MGI source."""

import csv
from typing import Dict, Any, Tuple, List
from sqlalchemy.engine import Connection

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class MGIParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        with self.get_filehandle(xref_file) as file_io:
            if file_io.read(1) == '':
                raise IOError("MGI file is empty")
            file_io.seek(0)

            csv_reader = csv.reader(file_io, delimiter="\t", strict=True)

            syn_hash = self.get_ext_synonyms("MGI", xref_dbi)
            count, syn_count = self.process_lines(csv_reader, source_id, species_id, xref_dbi, syn_hash)

        result_message = f"{count} direct MGI xrefs added\n{syn_count} synonyms added"
        return 0, result_message

    def process_lines(self, csv_reader: csv.reader, source_id: int, species_id: int, xref_dbi: Connection, syn_hash: Dict[str, List[str]]) -> Tuple[int, int]:
        count = 0
        syn_count = 0

        for line in csv_reader:
            if not line:
                continue

            accession = line[0]
            label = line[1]
            description = line[2]
            ensembl_id = line[5]

            xref_id = self.add_xref(
                {
                    "accession": accession,
                    "version": 0,
                    "label": label,
                    "description": description,
                    "source_id": source_id,
                    "species_id": species_id,
                    "info_type": "DIRECT",
                },
                xref_dbi,
            )
            self.add_direct_xref(xref_id, ensembl_id, "gene", "", xref_dbi)

            synonyms = syn_hash.get(accession)
            if synonyms:
                for synonym in synonyms:
                    self.add_synonym(xref_id, synonym, xref_dbi)
                    syn_count += 1

            count += 1

        return count, syn_count
