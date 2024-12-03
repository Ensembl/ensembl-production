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

"""Parser module for RGD source."""

import csv
import re
from typing import Any, Dict, List, Tuple
from sqlalchemy.engine import Connection

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class RGDParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        direct_source_id = self.get_source_id_for_source_name("RGD", xref_dbi, "direct_xref")

        with self.get_filehandle(xref_file) as file_io:
            if file_io.read(1) == '':
                raise IOError(f"RGD file is empty")
            file_io.seek(0)

            csv_reader = csv.DictReader(filter(lambda row: row[0] != "#", file_io), delimiter="\t")

            dependent_count, ensembl_count, mismatch_count, syn_count = self.process_lines(csv_reader, source_id, direct_source_id, species_id, xref_dbi)

        result_message = (
            f"{dependent_count} xrefs successfully loaded and dependent on refseq\n"
            f"\t{mismatch_count} xrefs added but with NO dependencies\n"
            f"\t{ensembl_count} direct xrefs successfully loaded\n"
            f"\tAdded {syn_count} synonyms, including duplicates"
        )

        return 0, result_message

    def process_lines(self, csv_reader: csv.DictReader, source_id: int, direct_source_id: int, species_id: int, xref_dbi: Connection) -> Tuple[int, int, int, int]:
        dependent_count, ensembl_count, mismatch_count, syn_count = 0, 0, 0, 0

        # Used to assign dbIDs for when RGD Xrefs are dependent on RefSeq xrefs
        preloaded_refseq = self.get_acc_to_xref_ids("refseq", species_id, xref_dbi)

        for line in csv_reader:
            # Don't bother doing anything if we don't have an RGD ID or if the symbol is an Ensembl ID
            if not line["GENE_RGD_ID"] or re.search("ENSRNO", line["SYMBOL"]):
                continue

            genbank_nucleotides = line["GENBANK_NUCLEOTIDE"].split(";")
            done = False

            # The nucleotides are sorted in the file in alphabetical order. Filter them down
            # to a higher quality subset, then add dependent Xrefs where possible
            for nucleotide in self.sort_refseq_accessions(genbank_nucleotides):
                if not done and nucleotide in preloaded_refseq:
                    for master_xref_id in preloaded_refseq[nucleotide]:
                        xref_id = self.add_dependent_xref(
                            {
                                "master_xref_id": master_xref_id,
                                "accession": line["GENE_RGD_ID"],
                                "label": line["SYMBOL"],
                                "description": line["NAME"],
                                "source_id": source_id,
                                "species_id": species_id,
                            },
                            xref_dbi,
                        )
                        dependent_count += 1

                        syn_count += self.process_synonyms(xref_id, line["OLD_SYMBOL"], xref_dbi)
                        done = True

            # Add direct xrefs
            if line["ENSEMBL_ID"]:
                ensembl_ids = line["ENSEMBL_ID"].split(";")
                for ensembl_id in ensembl_ids:
                    xref_id = self.add_xref(
                        {
                            "accession": line["GENE_RGD_ID"],
                            "label": line["SYMBOL"],
                            "description": line["NAME"],
                            "source_id": direct_source_id,
                            "species_id": species_id,
                            "info_type": "DIRECT",
                        },
                        xref_dbi,
                    )
                    self.add_direct_xref(xref_id, ensembl_id, "gene", "", xref_dbi)
                    ensembl_count += 1

                    syn_count += self.process_synonyms(xref_id, line["OLD_SYMBOL"], xref_dbi)
                    done = True

            # If neither direct or dependent, add misc xref
            if not done:
                self.add_xref(
                    {
                        "accession": line["GENE_RGD_ID"],
                        "label": line["SYMBOL"],
                        "description": line["NAME"],
                        "source_id": source_id,
                        "species_id": species_id,
                        "info_type": "MISC",
                    },
                    xref_dbi,
                )
                mismatch_count += 1
        
        return dependent_count, ensembl_count, mismatch_count, syn_count

    def sort_refseq_accessions(self, accessions: List[str]) -> List[str]:
        refseq_priorities = {"NM": 1, "NP": 1, "NR": 1, "XM": 2, "XP": 2, "XR": 2}
        return sorted(
            (acc for acc in accessions if acc[:2] in refseq_priorities),
            key=lambda acc: (refseq_priorities[acc[:2]], acc),
        )

    def process_synonyms(self, xref_id: int, synonym_string: str, dbi: Connection) -> int:
        if not synonym_string or not xref_id:
            return 0

        synonyms = synonym_string.split(";")
        for synonym in synonyms:
            self.add_synonym(xref_id, synonym, dbi)

        return len(synonyms)
