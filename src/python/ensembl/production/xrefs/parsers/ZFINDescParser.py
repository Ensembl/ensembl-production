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

"""Parser module for ZFIN Descriptions."""

import csv
import re
from typing import Any, Dict, Tuple

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class ZFINDescParser(BaseParser):
    WITHDRAWN_PATTERN = re.compile(r"^WITHDRAWN:", re.IGNORECASE | re.DOTALL)

    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        count = 0
        withdrawn = 0

        with self.get_filehandle(xref_file) as file_io:
            if file_io.read(1) == '':
                raise IOError(f"ZFINDesc file is empty")
            file_io.seek(0)

            csv_reader = csv.DictReader(file_io, delimiter="\t")
            csv_reader.fieldnames = ["zfin", "desc", "label", "extra1", "extra2"]

            # Read lines
            for line in csv_reader:
                # Skip if WITHDRAWN: this precedes both desc and label
                if self.WITHDRAWN_PATTERN.search(line["label"]):
                    withdrawn += 1
                else:
                    self.add_xref(
                        {
                            "accession": line["zfin"],
                            "label": line["label"],
                            "description": line["desc"],
                            "source_id": source_id,
                            "species_id": species_id,
                            "info_type": "MISC",
                        },
                        xref_dbi,
                    )
                    count += 1

        result_message = f"{count} ZFINDesc xrefs added, {withdrawn} withdrawn entries ignored"
        return 0, result_message
