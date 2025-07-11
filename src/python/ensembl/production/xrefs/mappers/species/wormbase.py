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

"""Mapper extension module for species wormbase."""

import logging
from typing import List
from sqlalchemy.sql.expression import select, update

from ensembl.core.models import (
    Gene as GeneORM,
    Transcript as TranscriptORM,
    Xref as XrefCORM,
    ExternalDb as ExternalDbORM,
    ObjectXref as ObjectXrefCORM
)

from ensembl.production.xrefs.mappers.BasicMapper import BasicMapper

class wormbase(BasicMapper):
    def set_display_xrefs(self) -> None:
        logging.info(
            "Building Transcript and Gene display_xrefs using WormBase direct xrefs"
        )

        core_dbi = self.core().connect()

        external_dbs, gene_display_xrefs, transcript_display_xrefs = {}, {}, {}

        # Get external_db IDs for the sources we are interested in
        query = select(ExternalDbORM.external_db_id, ExternalDbORM.db_name).where(
            ExternalDbORM.db_name.like("wormbase%")
        )
        for row in core_dbi.execute(query).mappings().all():
            external_dbs[row.db_name] = row.external_db_id

        if not external_dbs.get("wormbase_transcript") or not external_dbs.get(
            "wormbase_locus"
        ):
            logging.debug(
                "Could not find wormbase_transcript and wormbase_locus in external_db table, so doing nothing"
            )

            core_dbi.close()

            return

        # Get genes with wormbase display xrefs
        query = select(ObjectXrefCORM.ensembl_id, XrefCORM.xref_id).where(
            ObjectXrefCORM.xref_id == XrefCORM.xref_id,
            XrefCORM.external_db_id == external_dbs["wormbase_gseqname"],
        )
        for row in core_dbi.execute(query).mappings().all():
            gene_display_xrefs[row.ensembl_id] = row.xref_id

        # Some genes will have a locus name. Overwrite display xrefs for those that do
        query = select(ObjectXrefCORM.ensembl_id, XrefCORM.xref_id).where(
            ObjectXrefCORM.xref_id == XrefCORM.xref_id,
            XrefCORM.external_db_id == external_dbs["wormbase_locus"],
        )
        for row in core_dbi.execute(query).mappings().all():
            gene_display_xrefs[row.ensembl_id] = row.xref_id

        # Get the wormbase_transcript xrefs for the genes
        query = select(ObjectXrefCORM.ensembl_id, XrefCORM.xref_id).where(
            ObjectXrefCORM.xref_id == XrefCORM.xref_id,
            XrefCORM.external_db_id == external_dbs["wormbase_transcript"],
        )
        for row in core_dbi.execute(query).mappings().all():
            transcript_display_xrefs[row.ensembl_id] = row.xref_id

        # Reset gene and transcript display xrefs
        core_dbi.execute(update(GeneORM).values(display_xref_id=None))
        core_dbi.execute(update(TranscriptORM).values(display_xref_id=None))

        # Now update
        for gene_id, xref_id in gene_display_xrefs.items():
            core_dbi.execute(
                update(GeneORM)
                .values(display_xref_id=xref_id)
                .where(GeneORM.gene_id == gene_id)
            )

        for transcript_id, xref_id in gene_display_xrefs.items():
            core_dbi.execute(
                update(TranscriptORM)
                .values(display_xref_id=xref_id)
                .where(TranscriptORM.transcript_id == transcript_id)
            )

        core_dbi.close()

        logging.info("Updated display xrefs in core for genes and transcripts")

    def set_transcript_names(self) -> None:
        return None

    def gene_description_sources(self) -> List[str]:
        sources_list = [
            "RFAM",
            "RNAMMER",
            "TRNASCAN_SE",
            "miRBase",
            "HGNC",
            "IMGT/GENE_DB",
            "Uniprot/SWISSPROT",
            "RefSeq_peptide",
            "Uniprot/SPTREMBL",
        ]

        return sources_list

    def gene_description_filter_regexps(self) -> List[str]:
        regex = [
            r"^(Protein \S+\s*)+$",
            r"^Uncharacterized protein\s*\S+\s*",
            r"^Uncharacterized protein\s*",
            r"^Putative uncharacterized protein\s*\S+\s*",
            r"^Putative uncharacterized protein\s*",
            r"^Hypothetical protein\s*\S+\s*",
        ]

        return regex
