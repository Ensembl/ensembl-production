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

"""Parser module for MGI Descriptions."""

from ensembl.production.xrefs.parsers.BaseParser import *

EXPECTED_NUMBER_OF_COLUMNS = 12


class MGI_Desc_Parser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args["source_id"]
        species_id = args["species_id"]
        file       = args["file"]
        xref_dbi   = args["xref_dbi"]
        verbose    = args.get("verbose", False)

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        file_io = self.get_filehandle(file)
        csv_reader = csv.reader(
            file_io, delimiter="\t", strict=True, quotechar=None, escapechar=None
        )

        # Check if header is valid
        header = next(csv_reader)
        patterns = [
            "mgi accession id",
            "chr",
            "cm position",
            "genome coordinate start",
            "genome coordinate end",
            "strand",
            "marker symbol",
            "status",
            "marker name",
            "marker type",
            "feature type",
            r"marker\ssynonyms\s\(pipe\-separated\)",
        ]
        if not self.is_file_header_valid(EXPECTED_NUMBER_OF_COLUMNS, patterns, header):
            raise IOError(f"Malformed or unexpected header in MGI_desc file {file}")

        xref_count = 0
        syn_count = 0
        acc_to_xref = {}

        # Read lines
        for line in csv_reader:
            if not line:
                continue

            accession = line[0]
            marker = line[8]

            xref_id = self.add_xref(
                {
                    "accession": accession,
                    "label": line[6],
                    "description": marker,
                    "source_id": source_id,
                    "species_id": species_id,
                    "info_type": "MISC",
                },
                xref_dbi,
            )
            acc_to_xref[accession] = xref_id

            if not marker and verbose:
                logging.info(f"{accession} has no description")

            xref_count += 1

            if acc_to_xref.get(accession):
                synonym_field = line[11]
                if synonym_field:
                    synonyms = re.split(r"[|]", synonym_field)

                    for synonym in synonyms:
                        self.add_synonym(xref_id, synonym, xref_dbi)
                        syn_count += 1

        file_io.close()

        result_message = f"{xref_count} MGI Description Xrefs added\n"
        result_message += f"{syn_count} synonyms added"

        return 0, result_message
