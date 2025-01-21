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

"""Parser module for MIM source."""

import re
import logging
from typing import Any, Dict, List, Optional, Tuple
from sqlalchemy.engine import Connection

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class MIMParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        general_source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")
        verbose = args.get("verbose", False)

        if not general_source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")
    
        old_to_new, removed = {}, {}
        sources = [general_source_id]

        gene_source_id = self.get_source_id_for_source_name("MIM_GENE", xref_dbi)
        morbid_source_id = self.get_source_id_for_source_name("MIM_MORBID", xref_dbi)
        sources.extend([gene_source_id, morbid_source_id])

        TYPE_SINGLE_SOURCES = {
            "*": gene_source_id,
            "": morbid_source_id,
            "#": morbid_source_id,
            "%": morbid_source_id,
        }

        counters = {gene_source_id: 0, morbid_source_id: 0, "removed": 0, "synonyms": 0}

        if verbose:
            logging.info(f"Sources are: {', '.join(map(str, sources))}")

        for section in self.get_file_sections(xref_file, "*RECORD*"):
            record = "".join(section)

            # Extract the TI field from the record
            ti = self.extract_ti(record)
            if not ti:
                raise ValueError("Failed to extract TI field from record")

            # Extract record type, number, and description from the TI field
            record_type, number, long_desc = self.parse_ti(ti)
            if record_type is None:
                raise ValueError("Failed to extract record type and description from TI field")

            # Use the first block of text as description
            fields = re.split(";;", long_desc, flags=re.MULTILINE | re.DOTALL)
            label = f"{fields[0]} [{record_type}{number}]"

            xref_object = {
                "accession": number,
                "label": label,
                "description": long_desc,
                "species_id": species_id,
                "info_type": "UNMAPPED",
            }

            if record_type in TYPE_SINGLE_SOURCES:
                type_source = TYPE_SINGLE_SOURCES[record_type]
                xref_object["source_id"] = type_source
                counters[type_source] += 1
                self.add_xref(xref_object, xref_dbi)
            elif record_type == "+":
                # This type means both gene and phenotype, add both
                xref_object["source_id"] = gene_source_id
                counters[gene_source_id] += 1
                self.add_xref(xref_object, xref_dbi)

                xref_object["source_id"] = morbid_source_id
                counters[morbid_source_id] += 1
                self.add_xref(xref_object, xref_dbi)
            elif record_type == "^":
                self.handle_moved_or_removed_record(number, long_desc, old_to_new, removed, counters)

        self.generate_synonyms_from_moved_entries(old_to_new, removed, sources, species_id, xref_dbi, counters)

        result_message = (
            f"{counters[gene_source_id]} genemap and {counters[morbid_source_id]} phenotype MIM xrefs added\n"
            f"\t{counters['synonyms']} synonyms (defined by MOVED TO) added\n"
            f"\t{counters['removed']} entries removed"
        )

        return 0, result_message

    def extract_ti(self, input_record: str) -> Optional[str]:
        """Extract the TI field from the input record."""
        match = re.search(
            r"[*]FIELD[*]\sTI\n(.+?)\n?(?:[*]FIELD[*]| [*]RECORD[*]| [*]THEEND[*])",
            input_record,
            flags=re.MULTILINE | re.DOTALL,
        )
        return match.group(1) if match else None

    def parse_ti(self, ti: str) -> Tuple[Optional[str], Optional[str], Optional[str]]:
        """Parse the TI field to extract record type, number, and description."""
        ti = re.sub(r"(?:;;\n|\n;;)", ";;", ti, flags=re.MULTILINE | re.DOTALL)
        ti = re.sub(r"\n", "", ti, flags=re.MULTILINE | re.DOTALL)

        match = re.search(r"\A([#%+*^]*)(\d+)\s+(.+)", ti)
        return match.groups() if match else (None, None, None)

    def handle_moved_or_removed_record(self, number: str, long_desc: str, old_to_new: Dict[str, str], removed: Dict[str, int], counters: Dict[str, int]) -> None:
        """Handle records that have been moved or removed."""
        match = re.search(r"MOVED\sTO\s(\d+)", long_desc, flags=re.MULTILINE | re.DOTALL)
        if match:
            new_number = match.group(1)
            if new_number != number:
                old_to_new[number] = new_number
        elif long_desc == "REMOVED FROM DATABASE":
            removed[number] = 1
            counters["removed"] += 1
        else:
            raise IOError(f"Unsupported type of a '^' record: '{long_desc}'")

    def generate_synonyms_from_moved_entries(self, old_to_new: Dict[str, str], removed: Dict[str, int], sources: List[int], species_id: int, xref_dbi: Connection, counters: Dict[str, int]) -> None:
        """Generate synonyms from 'MOVED TO' entries."""
        for old, new in old_to_new.items():
            # Some entries in the MIM database have been moved multiple times
            # Keep traversing the chain of renames until we have reached the end
            while old_to_new.get(new):
                new = old_to_new[new]

            # Check if the entry has been removed from the database
            if not removed.get(new):
                self.add_to_syn_for_mult_sources(new, sources, old, species_id, xref_dbi)
                counters["synonyms"] += 1
