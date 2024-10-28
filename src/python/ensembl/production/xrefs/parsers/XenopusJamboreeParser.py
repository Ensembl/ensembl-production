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

"""Parser module for Xenbase source."""

import csv
import re
from typing import Any, Dict, Tuple

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class XenopusJamboreeParser(BaseParser):
    DESC_PROVENANCE_PATTERN = re.compile(r"\s*\[.*\]", re.IGNORECASE | re.DOTALL)
    DESC_LABEL_PATTERN = re.compile(r",\s+\d+\s+of\s+\d+", re.IGNORECASE | re.DOTALL)

    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        count = 0

        with self.get_filehandle(xref_file) as file_io:
            if file_io.read(1) == '':
                raise IOError(f"XenopusJamboree file is empty")
            file_io.seek(0)

            csv_reader = csv.reader(file_io, delimiter="\t")

            # Read lines
            for line in csv_reader:
                accession, label, desc, stable_id = line[:4]

                # If there is a description, trim it a bit
                if desc:
                    desc = self.parse_description(desc)

                if label == "unnamed":
                    label = accession

                xref_id = self.add_xref(
                    {
                        "accession": accession,
                        "label": label,
                        "description": desc,
                        "source_id": source_id,
                        "species_id": species_id,
                        "info_type": "DIRECT",
                    },
                    xref_dbi,
                )
                self.add_direct_xref(xref_id, stable_id, "gene", "", xref_dbi)
                count += 1

        result_message = f"{count} XenopusJamboree xrefs successfully parsed"
        return 0, result_message

    def parse_description(self, description: str) -> str:
        # Remove some provenance information encoded in the description
        description = self.DESC_PROVENANCE_PATTERN.sub("", description)

        # Remove labels of type 5 of 14 from the description
        description = self.DESC_LABEL_PATTERN.sub("", description)

        return description
