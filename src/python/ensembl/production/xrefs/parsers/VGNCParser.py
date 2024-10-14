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

"""Parser module for VGNC source (uses HGNC Parser as parent)."""

from ensembl.production.xrefs.parsers.HGNCParser import *


class VGNCParser(HGNCParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args["source_id"]
        species_id = args["species_id"]
        file       = args["file"]
        xref_dbi   = args["xref_dbi"]

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        # Create a hash of all valid taxon_ids for this species
        species_id_to_tax = self.species_id_to_taxonomy(xref_dbi)
        species_id_to_tax.setdefault(species_id, []).append(species_id)

        tax_ids = species_id_to_tax[species_id]
        tax_to_species_id = {tax_id: species_id for tax_id in tax_ids}

        # Open the vgnc file
        file_io = self.get_filehandle(file)
        csv_reader = csv.DictReader(file_io, delimiter="\t")

        # Check if header has required columns
        required_columns = [
            "taxon_id",
            "ensembl_gene_id",
            "vgnc_id",
            "symbol",
            "name",
            "alias_symbol",
            "prev_symbol",
        ]
        if not set(required_columns).issubset(set(csv_reader.fieldnames)):
            raise IOError(f"Can't find required columns in VGNC file '{file}'")

        # Read lines
        count = 0
        for line in csv_reader:
            # Skip data for other species
            if not tax_to_species_id.get(line["taxon_id"]):
                continue

            # Add ensembl direct xref
            if line["ensembl_gene_id"]:
                self.add_to_direct_xrefs(
                    {
                        "stable_id": line["ensembl_gene_id"],
                        "ensembl_type": "gene",
                        "accession": line["vgnc_id"],
                        "label": line["symbol"],
                        "description": line["name"],
                        "source_id": source_id,
                        "species_id": species_id,
                    },
                    xref_dbi,
                )

                self.add_synonyms_for_hgnc(
                    {
                        "source_id": source_id,
                        "name": line["vgnc_id"],
                        "species_id": species_id,
                        "dead": line["alias_symbol"],
                        "alias": line["prev_symbol"],
                    },
                    xref_dbi,
                )

                count += 1

        file_io.close()

        result_message = f"Loaded a total of {count} VGNC xrefs"

        return 0, result_message
