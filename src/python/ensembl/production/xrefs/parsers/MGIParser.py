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

from ensembl.production.xrefs.parsers.BaseParser import *


class MGIParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args["source_id"]
        species_id = args["species_id"]
        file       = args["file"]
        xref_dbi   = args["xref_dbi"]

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        syn_hash = self.get_ext_synonyms("MGI", xref_dbi)

        file_io = self.get_filehandle(file)
        csv_reader = csv.reader(file_io, delimiter="\t", strict=True)

        count = 0
        syn_count = 0

        # Read lines
        for line in csv_reader:
            if not line:
                continue

            accession = line[0]
            ensembl_id = line[5]

            xref_id = self.add_xref(
                {
                    "accession": accession,
                    "version": 0,
                    "label": line[1],
                    "description": line[2],
                    "source_id": source_id,
                    "species_id": species_id,
                    "info_type": "DIRECT",
                },
                xref_dbi,
            )
            self.add_direct_xref(xref_id, ensembl_id, "Gene", "", xref_dbi)

            if syn_hash.get(accession):
                for synonym in syn_hash[accession]:
                    self.add_synonym(xref_id, synonym, xref_dbi)
                    syn_count += 1

            count += 1

        file_io.close()

        result_message = f"{count} direct MGI xrefs added\n"
        result_message += f"{syn_count} synonyms added"

        return 0, result_message
