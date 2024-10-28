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

"""Parser module for miRBase source."""

import re
from typing import Any, Dict, List, Tuple

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class miRBaseParser(BaseParser):
    NAME_PATTERN = re.compile(r"^ID\s+(\S+)\s+", re.MULTILINE)
    ACCESSION_PATTERN = re.compile(r"^AC\s+(\S+);\s+", re.MULTILINE)
    DESCRIPTION_PATTERN = re.compile(r"^DE\s+(.*)", re.MULTILINE)
    SPECIES_NAME_PATTERN = re.compile(r"(.+?)\s+stem(-|\s)loop")

    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        species_name = args.get("species_name")
        file = args.get("file")
        xref_dbi = args.get("xref_dbi")

        if not source_id or not species_id or not file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        # Get the species name(s)
        species_to_names = self.species_id_to_names(xref_dbi)
        if species_name:
            species_to_names.setdefault(species_id, []).append(species_name)
        if not species_to_names.get(species_id):
            return 0, "Skipped. Could not find species ID to name mapping"

        names = species_to_names[species_id]
        name_to_species_id = {name: species_id for name in names}

        xrefs = self.create_xrefs(source_id, file, species_id, name_to_species_id)
        if not xrefs:
            return 0, "No xrefs added"

        self.upload_xref_object_graphs(xrefs, xref_dbi)

        result_message = f"Read {len(xrefs)} xrefs from {file}"
        return 0, result_message

    def create_xrefs(self, source_id: int, file: str, species_id: int, name_to_species_id: Dict[str, int]) -> List[Dict[str, Any]]:
        xrefs = []

        # Read miRBase file
        for section in self.get_file_sections(file, "//\n"):
            entry = "".join(section)
            if not entry:
                continue

            header, sequence = re.split(r"\nSQ", entry, 1)
            species = None

            # Extract sequence
            if sequence:
                seq_lines = sequence.split("\n")[1:] # Remove newlines and drop the information line
                sequence = "".join(seq_lines).upper() # Join into a single string and convert to uppercase
                sequence = re.sub("U", "T", sequence) # Replace Us with Ts
                sequence = re.sub(r"[\d+\s,]", "", sequence) # Remove digits, spaces, and commas

            # Extract name, accession, and description
            name_match = self.NAME_PATTERN.search(header)
            accession_match = self.ACCESSION_PATTERN.search(header)
            description_match = self.DESCRIPTION_PATTERN.search(header)

            if not (accession_match and description_match):
                continue

            name = name_match.group(1)
            accession = accession_match.group(1)
            description = description_match.group(1)

            # Extract species name from description
            species_name_match = self.SPECIES_NAME_PATTERN.search(description)
            species = species_name_match.group(1)
            species = "_".join(species.split()[:-1]).lower()

            # If no species match, skip to next record
            species_id_check = name_to_species_id.get(species)
            if not species_id_check:
                continue

            if species_id == species_id_check:
                xref = {
                    "SEQUENCE_TYPE": "dna",
                    "STATUS": "experimental",
                    "SOURCE_ID": source_id,
                    "ACCESSION": accession,
                    "LABEL": name,
                    "DESCRIPTION": description,
                    "SEQUENCE": sequence,
                    "SPECIES_ID": species_id,
                    "INFO_TYPE": "SEQUENCE_MATCH",
                }
                xrefs.append(xref)

        return xrefs
