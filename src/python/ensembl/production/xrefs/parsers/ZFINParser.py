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

"""Parser module for ZFIN source."""

import os
import csv
import re
import unicodedata
from typing import Dict, Any, Tuple
from sqlalchemy import select

from ensembl.xrefs.xref_update_db_model import (
    Source as SourceUORM,
    Xref as XrefUORM,
)

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class ZFINParser(BaseParser):
    REFSEQ_ACC_PATTERN = re.compile(r"^X[PMR]_")

    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        # Get the ZFIN source ids
        direct_src_id = self.get_source_id_for_source_name("ZFIN_ID", xref_dbi, "direct")
        dependent_src_id = self.get_source_id_for_source_name("ZFIN_ID", xref_dbi, "uniprot/refseq")
        description_src_id = self.get_source_id_for_source_name("ZFIN_ID", xref_dbi, "description_only")

        # Get the ZFIN descriptions
        descriptions = {}
        query = select(XrefUORM.accession, XrefUORM.description).where(XrefUORM.source_id == description_src_id)
        for row in xref_dbi.execute(query).mappings().all():
            if row.description:
                descriptions[row.accession] = row.description

        # Get the Uniprot and RefSeq accessions
        swiss = self.get_acc_to_xref_ids("uniprot/swissprot", species_id, xref_dbi)
        refseq = self.get_acc_to_xref_ids("refseq", species_id, xref_dbi)

        file_dir = os.path.dirname(xref_file)
        counts = {"direct": 0, "uniprot": 0, "refseq": 0, "synonyms": 0, "mismatch": 0}

        # Process ZFIN to ensEMBL mappings
        zfin = {}
        with self.get_filehandle(os.path.join(file_dir, "ensembl_1_to_1.txt")) as zfin_io:
            if zfin_io.read(1) == '':
                raise IOError(f"ZFIN Ensembl file is empty")
            zfin_io.seek(0)

            zfin_csv_reader = csv.DictReader(zfin_io, delimiter="\t", strict=True)
            zfin_csv_reader.fieldnames = ["zfin", "so", "label", "ensembl_id"]
            for line in zfin_csv_reader:
                xref_id = self.add_xref(
                    {
                        "accession": line["zfin"],
                        "label": line["label"],
                        "description": descriptions.get(line["zfin"]),
                        "source_id": direct_src_id,
                        "species_id": species_id,
                        "info_type": "DIRECT",
                    },
                    xref_dbi,
                )
                self.add_direct_xref(xref_id, line["ensembl_id"], "gene", "", xref_dbi)

                zfin[line["zfin"]] = True
                counts["direct"] += 1

        # Process ZFIN to Uniprot mappings
        with self.get_filehandle(os.path.join(file_dir, "uniprot.txt")) as swissprot_io:
            if swissprot_io.read(1) == '':
                raise IOError(f"ZFIN Uniprot file is empty")
            swissprot_io.seek(0)

            swissprot_csv_reader = csv.DictReader(swissprot_io, delimiter="\t", strict=True)
            swissprot_csv_reader.fieldnames = ["zfin", "so", "label", "acc"]
            for line in swissprot_csv_reader:
                if swiss.get(line["acc"]) and not zfin.get(line["zfin"]):
                    for xref_id in swiss[line["acc"]]:
                        self.add_dependent_xref(
                            {
                                "master_xref_id": xref_id,
                                "accession": line["zfin"],
                                "label": line["label"],
                                "description": descriptions.get(line["zfin"]),
                                "source_id": dependent_src_id,
                                "species_id": species_id,
                            },
                            xref_dbi,
                        )
                        counts["uniprot"] += 1
                else:
                    counts["mismatch"] += 1

        # Process ZFIN to RefSeq mappings
        with self.get_filehandle(os.path.join(file_dir, "refseq.txt")) as refseq_io:
            if refseq_io.read(1) == '':
                raise IOError(f"ZFIN Refseq file is empty")
            refseq_io.seek(0)

            refseq_csv_reader = csv.DictReader(refseq_io, delimiter="\t", strict=True)
            refseq_csv_reader.fieldnames = ["zfin", "so", "label", "acc"]
            for line in refseq_csv_reader:
                # Ignore mappings to predicted RefSeq
                if self.REFSEQ_ACC_PATTERN.search(line["acc"]):
                    continue

                if refseq.get(line["acc"]) and not zfin.get(line["zfin"]):
                    for xref_id in refseq[line["acc"]]:
                        self.add_dependent_xref(
                            {
                                "master_xref_id": xref_id,
                                "accession": line["zfin"],
                                "label": line["label"],
                                "description": descriptions.get(line["zfin"]),
                                "source_id": dependent_src_id,
                                "species_id": species_id,
                            },
                            xref_dbi,
                        )
                        counts["refseq"] += 1
                else:
                    counts["mismatch"] += 1

        # Get the added ZFINs
        zfin = self.get_acc_to_xref_ids("zfin", species_id, xref_dbi)

        sources = []
        query = select(SourceUORM.source_id).where(SourceUORM.name.like("ZFIN_ID"))
        for row in xref_dbi.execute(query).fetchall():
            sources.append(row[0])

        # Process the synonyms
        with self.get_filehandle(os.path.join(file_dir, "aliases.txt")) as aliases_io:
            if aliases_io.read(1) == '':
                raise IOError(f"ZFIN Aliases file is empty")
            aliases_io.seek(0)

            aliases_csv_reader = csv.DictReader(aliases_io, delimiter="\t", strict=True)
            aliases_csv_reader.fieldnames = ["acc", "cur_name", "cur_symbol", "syn", "so"]
            for line in aliases_csv_reader:
                if zfin.get(line["acc"]):
                    synonym = (
                        unicodedata.normalize("NFKD", line["syn"])
                        .encode("ascii", "namereplace")
                        .decode("ascii")
                    )
                    self.add_to_syn_for_mult_sources(
                        line["acc"], sources, synonym, species_id, xref_dbi
                    )
                    counts["synonyms"] += 1

        result_message = (
            f"{counts['direct']} direct ZFIN xrefs added and\n"
            f"\t{counts['uniprot']} dependent xrefs from UniProt added\n"
            f"\t{counts['refseq']} dependent xrefs from RefSeq added\n"
            f"\t{counts['mismatch']} dependents ignored\n"
            f"\t{counts['synonyms']} synonyms loaded"
        )

        return 0, result_message
