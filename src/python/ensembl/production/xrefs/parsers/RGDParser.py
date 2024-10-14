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

from ensembl.production.xrefs.parsers.BaseParser import *


class RGDParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args["source_id"]
        species_id = args["species_id"]
        file       = args["file"]
        xref_dbi   = args["xref_dbi"]

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        direct_source_id = self.get_source_id_for_source_name(
            "RGD", xref_dbi, "direct_xref"
        )

        # Used to assign dbIDs for when RGD Xrefs are dependent on RefSeq xrefs
        preloaded_refseq = self.get_valid_codes("refseq", species_id, xref_dbi)

        rgd_io = self.get_filehandle(file)
        csv_reader = csv.DictReader(
            filter(lambda row: row[0] != "#", rgd_io), delimiter="\t"
        )

        header_found, count, ensembl_count, mismatch, syn_count = 0, 0, 0, 0, 0
        columns = {}

        # Read lines
        for line in csv_reader:
            # Don't bother doing anything if we don't have an RGD ID
            if not line.get("GENE_RGD_ID") or not line["GENE_RGD_ID"]:
                continue

            # Some RGD annotation is directly copied from Ensembl
            if re.search("ENSRNO", line["SYMBOL"]):
                continue

            genbank_nucleotides = []
            if line.get("GENBANK_NUCLEOTIDE"):
                genbank_nucleotides = line["GENBANK_NUCLEOTIDE"].split(";")

            done = 0
            # The nucleotides are sorted in the file in alphabetical order. Filter them down
            # to a higher quality subset, then add dependent Xrefs where possible
            for nucleotide in self.sort_refseq_accessions(genbank_nucleotides):
                if not done and preloaded_refseq.get(nucleotide):
                    for xref in preloaded_refseq[nucleotide]:
                        xref_id = self.add_dependent_xref(
                            {
                                "master_xref_id": xref,
                                "accession": line["GENE_RGD_ID"],
                                "label": line["SYMBOL"],
                                "description": line["NAME"],
                                "source_id": source_id,
                                "species_id": species_id,
                            },
                            xref_dbi,
                        )

                        count += 1
                        syn_count += self.process_synonyms(
                            xref_id, line["OLD_SYMBOL"], xref_dbi
                        )
                        done = 1

            # Add direct xrefs
            if line.get("ENSEMBL_ID"):
                ensembl_ids = line["ENSEMBL_ID"].split(";")

                for id in ensembl_ids:
                    self.add_to_direct_xrefs(
                        {
                            "stable_id": id,
                            "ensembl_type": "gene",
                            "accession": line["GENE_RGD_ID"],
                            "label": line["SYMBOL"],
                            "description": line["NAME"],
                            "source_id": direct_source_id,
                            "species_id": species_id,
                        },
                        xref_dbi,
                    )
                    xref_id = self.get_xref_id(
                        line["GENE_RGD_ID"], direct_source_id, species_id, xref_dbi
                    )

                    ensembl_count += 1
                    syn_count += self.process_synonyms(
                        xref_id, line["OLD_SYMBOL"], xref_dbi
                    )
                    done = 1

            # If neither direct or dependent, add misc xref
            if not done:
                xref_id = self.add_xref(
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
                mismatch += 1

        rgd_io.close()

        result_message = f"{count} xrefs succesfully loaded and dependent on refseq\n"
        result_message += f"\t{mismatch} xrefs added but with NO dependencies\n"
        result_message += f"\t{ensembl_count} direct xrefs successfully loaded\n"
        result_message += f"\tAdded {syn_count} synonyms, including duplicates"

        return 0, result_message

    def sort_refseq_accessions(self, accessions: List[str]) -> List[str]:
        refseq_priorities = {"NM": 1, "NP": 1, "NR": 1, "XM": 2, "XP": 2, "XR": 2}

        accessions = sorted(
            [x for x in accessions if x[:2] in refseq_priorities],
            key=lambda x: (refseq_priorities[x[:2]], x),
        )
        return accessions

    def process_synonyms(self, xref_id: int, synonym_string: str, dbi: Connection) -> int:
        syn_count = 0

        if not synonym_string or not xref_id:
            return syn_count

        synonyms = synonym_string.split(";")
        for synonym in synonyms:
            self.add_synonym(xref_id, synonym, dbi)
            syn_count += 1

        return syn_count
