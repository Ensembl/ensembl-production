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

from ensembl.production.xrefs.parsers.BaseParser import *


class XenopusJamboreeParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args["source_id"]
        species_id = args["species_id"]
        file       = args["file"]
        xref_dbi   = args["xref_dbi"]

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        count = 0

        file_io = self.get_filehandle(file)
        csv_reader = csv.reader(file_io, delimiter="\t")

        # Read lines
        for line in csv_reader:
            accession = line[0]
            label = line[1]
            desc = line[2]
            stable_id = line[3]

            # If there is a description, trim it a bit
            if desc:
                desc = self.parse_description(desc)

            if label == "unnamed":
                label = accession

            self.add_to_direct_xrefs(
                {
                    "stable_id": stable_id,
                    "ensembl_type": "gene",
                    "accession": accession,
                    "label": label,
                    "description": desc,
                    "source_id": source_id,
                    "species_id": species_id,
                },
                xref_dbi,
            )
            count += 1

        file_io.close()

        result_message = f"{count} XenopusJamboreeParser xrefs succesfully parsed"

        return 0, result_message

    def parse_description(self, description: str) -> str:
        # Remove some provenance information encoded in the description
        description = re.sub(r"\s*\[.*\]", "", description)

        # Remove labels of type 5 of 14 from the description
        description = re.sub(r",\s+\d+\s+of\s+\d+", "", description)

        return description
