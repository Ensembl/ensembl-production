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

"""Mapper extension module for species sars_cov_2."""

from ensembl.production.xrefs.mappers.BasicMapper import *


class sars_cov_2(BasicMapper):
    def set_transcript_names(self) -> None:
        logging.info("Assigning transcript names from gene names")

        core_dbi = self.core().connect()

        # Reset transcript display xrefs
        core_dbi.execute(update(TranscriptORM).values(display_xref_id=None))

        # Get the max xref and object_xref IDs
        xref_id = core_dbi.execute(select(func.max(XrefCORM.xref_id))).scalar()
        xref_id = int(xref_id)
        object_xref_id = core_dbi.execute(
            select(func.max(ObjectXrefCORM.object_xref_id))
        ).scalar()
        object_xref_id = int(object_xref_id)

        # Delete transcript name xrefs
        core_dbi.execute(
            delete(XrefCORM).where(
                XrefCORM.xref_id == ObjectXrefCORM.xref_id,
                ObjectXrefCORM.ensembl_object_type == "Transcript",
                ExternalDbORM.external_db_id == XrefCORM.external_db_id,
                ExternalDbORM.db_name.like("%_trans_name"),
            )
        )

        # Get all genes with set display_xref_id
        query = select(
            GeneORM.gene_id,
            ExternalDbORM.db_name,
            XrefCORM.dbprimary_acc,
            XrefCORM.display_label,
            XrefCORM.description,
        ).where(
            GeneORM.display_xref_id == XrefCORM.xref_id,
            XrefCORM.external_db_id == ExternalDbORM.external_db_id,
        )
        for row in core_dbi.execute(query).mappings().all():
            # Get the ID of transcript name external DB
            external_db_id = core_dbi.execute(
                select(ExternalDbORM.external_db_id).where(
                    ExternalDbORM.db_name.like(f"{row.db_name}_trans_name")
                )
            ).scalar()

            if not external_db_id:
                raise LookupError(
                    f"No external_db_id found for '{row.db_name}_trans_name'"
                )

            # Get transcripts related to current gene
            query = (
                select(TranscriptORM.transcript_id)
                .where(TranscriptORM.gene_id == row.gene_id)
                .order_by(TranscriptORM.seq_region_start, TranscriptORM.seq_region_end)
            )
            for transcript_row in core_dbi.execute(query).mappings().all():
                xref_id += 1
                object_xref_id += 1

                info_text = f"via gene {row.dbprimary_acc}"

                # Insert new xref
                core_dbi.execute(
                    insert(XrefCORM)
                    .values(
                        xref_id=xref_id,
                        external_db_id=external_db_id,
                        dbprimary_acc=row.display_label,
                        display_label=row.display_label,
                        version=0,
                        description=row.description,
                        info_type="MISC",
                        info_text=info_text,
                    )
                    .prefix_with("IGNORE")
                )

                # Insert object xref
                core_dbi.execute(
                    insert(ObjectXrefCORM).values(
                        object_xref_id=object_xref_id,
                        ensembl_id=transcript_row.transcript_id,
                        ensembl_object_type="Transcript",
                        xref_id=xref_id,
                    )
                )

                # Set transcript display xref
                core_dbi.execute(
                    update(TranscriptORM)
                    .values(display_xref_id=xref_id)
                    .where(TranscriptORM.transcript_id == transcript_row.transcript_id)
                )

        # Delete object xrefs with no matching xref
        query = (
            select(ObjectXrefCORM.object_xref_id)
            .outerjoin(XrefCORM, XrefCORM.xref_id == ObjectXrefCORM.xref_id)
            .where(XrefCORM.xref_id == None)
        )
        result = core_dbi.execute(query).fetchall()
        object_xref_ids = [row[0] for row in result]

        core_dbi.execute(
            delete(ObjectXrefCORM).where(
                ObjectXrefCORM.object_xref_id.in_(object_xref_ids)
            )
        )

        core_dbi.close()
