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

import csv
from typing import Dict, Any, Tuple
from sqlalchemy.engine import Connection

from ensembl.production.xrefs.parsers.HGNCParser import HGNCParser

class VGNCParser(HGNCParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        # Open the VGNC file
        with self.get_filehandle(xref_file) as file_io:
            if file_io.read(1) == '':
                raise IOError(f"VGNC file is empty")
            file_io.seek(0)

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
                raise ValueError(f"Can't find required columns in VGNC file '{xref_file}'")

            count, syn_count = self.process_lines(csv_reader, source_id, species_id, xref_dbi)

        result_message = f"Loaded a total of {count} VGNC xrefs and added {syn_count} synonyms"

        return 0, result_message

    def process_lines(self, csv_reader: csv.DictReader, source_id: int, species_id: int, xref_dbi: Connection) -> Tuple[int, int]:
        count, syn_count = 0, 0

        # Create a hash of all valid taxon_ids for this species
        species_id_to_tax = self.species_id_to_taxonomy(xref_dbi)
        species_id_to_tax.setdefault(species_id, []).append(species_id)

        tax_ids = species_id_to_tax[species_id]
        tax_to_species_id = {tax_id: species_id for tax_id in tax_ids}

        # Read lines
        for line in csv_reader:
            tax_id = int(line["taxon_id"])
            # Skip data for other species
            if not tax_to_species_id.get(tax_id):
                continue

            # Add Ensembl direct xref
            if line["ensembl_gene_id"]:
                xref_id = self.add_xref(
                    {
                        "accession": line["vgnc_id"],
                        "label": line["symbol"],
                        "description": line["name"],
                        "source_id": source_id,
                        "species_id": species_id,
                        "info_type": "DIRECT",
                    },
                    xref_dbi,
                )
                self.add_direct_xref(xref_id, line["ensembl_gene_id"], "gene", "", xref_dbi)
                
                # Add synonyms
                syn_count += self.add_synonyms_for_hgnc(
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
        
        return count, syn_count