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

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

EXPECTED_NUMBER_OF_COLUMNS = 4


class HPAParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args["source_id"]
        species_id = args["species_id"]
        file       = args["file"]
        xref_dbi   = args["xref_dbi"]

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        file_io = self.get_filehandle(file)
        csv_reader = csv.reader(file_io, delimiter=",", strict=True)

        # Check if header is valid
        header = next(csv_reader)
        patterns = ["antibody", "antibody_id", "ensembl_peptide_id", "link"]
        if not self.is_file_header_valid(EXPECTED_NUMBER_OF_COLUMNS, patterns, header):
            raise IOError(f"Malformed or unexpected header in HPA file {file}")

        parsed_count = 0

        # Read lines
        for line in csv_reader:
            if not line:
                continue

            antibody_name = line[0]
            antibody_id = line[1]
            ensembl_id = line[2]

            self.add_to_direct_xrefs(
                {
                    "accession": antibody_id,
                    "version": "1",
                    "label": antibody_name,
                    "stable_id": ensembl_id,
                    "ensembl_type": "translation",
                    "source_id": source_id,
                    "species_id": species_id,
                    "info_type": "DIRECT",
                },
                xref_dbi,
            )

            parsed_count += 1

        file_io.close()

        result_message = f"{parsed_count} direct xrefs succesfully parsed"

        return 0, result_message
