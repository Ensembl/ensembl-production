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

"""Parser module for EntrezGene and WikiGene sources."""

from ensembl.production.xrefs.parsers.BaseParser import *

EXPECTED_NUMBER_OF_COLUMNS = 16


class EntrezGeneParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args["source_id"]
        species_id = args["species_id"]
        file       = args["file"]
        xref_dbi   = args["xref_dbi"]
        verbose    = args.get("verbose", False)

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        wiki_source_id = self.get_source_id_for_source_name("WikiGene", xref_dbi)
        if verbose:
            logging.info(f"Wiki source id = {wiki_source_id}")

        file_io = self.get_filehandle(file)
        csv_reader = csv.reader(file_io, delimiter="\t")

        # Check if header is valid
        header = next(csv_reader)
        patterns = [
            r"\A[#]?\s*tax_id",
            "geneid",
            "symbol",
            "locustag",
            "synonyms",
            "dbxrefs",
            "chromosome",
            "map_location",
            "description",
            "type_of_gene",
            "symbol_from_nomenclature_authority",
            "full_name_from_nomenclature_authority",
            "nomenclature_status",
            "other_designations",
            "modification_date",
            "feature_type",
        ]
        if not self.is_file_header_valid(EXPECTED_NUMBER_OF_COLUMNS, patterns, header):
            raise IOError(f"Malformed or unexpected header in EntrezGene file {file}")

        xref_count = 0
        syn_count = 0
        seen = {}

        # Read lines
        for line in csv_reader:
            if not line:
                continue

            tax_id = line[0]
            acc = line[1]
            symbol = line[2]
            synonyms = line[4]
            desc = line[8]

            if tax_id != species_id:
                continue
            if seen.get(acc):
                continue

            xref_id = self.add_xref(
                {
                    "accession": acc,
                    "label": symbol,
                    "description": desc,
                    "source_id": source_id,
                    "species_id": species_id,
                    "info_type": "DEPENDENT",
                },
                xref_dbi,
            )
            self.add_xref(
                {
                    "accession": acc,
                    "label": symbol,
                    "description": desc,
                    "source_id": wiki_source_id,
                    "species_id": species_id,
                    "info_type": "DEPENDENT",
                },
                xref_dbi,
            )

            xref_count += 1

            syns = re.split(r"\|", synonyms)
            for synonym in syns:
                if synonym != "-":
                    self.add_synonym(xref_id, synonym, xref_dbi)
                    syn_count += 1

            seen[acc] = 1

        file_io.close()

        result_message = f"{xref_count} EntrezGene Xrefs and {xref_count} WikiGene Xrefs added with {syn_count} synonyms"

        return 0, result_message
