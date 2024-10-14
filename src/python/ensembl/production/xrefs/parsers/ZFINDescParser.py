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

from ensembl.production.xrefs.parsers.BaseParser import *


class ZFINDescParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args["source_id"]
        species_id = args["species_id"]
        file       = args["file"]
        xref_dbi   = args["xref_dbi"]

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        count = 0
        withdrawn = 0

        file_io = self.get_filehandle(file)
        csv_reader = csv.DictReader(file_io, delimiter="\t")
        csv_reader.fieldnames = ["zfin", "desc", "label", "extra1", "extra2"]

        # Read lines
        for line in csv_reader:
            # Skip if WITHDRAWN: this precedes both desc and label
            if re.search(r"\A WITHDRAWN:", line["label"]):
                withdrawn += 1
            else:
                xref_id = self.add_xref(
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

        file_io.close()

        result_message = (
            f"{count} ZFINDesc xrefs added, {withdrawn} withdrawn entries ignored"
        )

        return 0, result_message
