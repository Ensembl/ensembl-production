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

"""Mapper module for processing paired xrefs."""

from ensembl.production.xrefs.mappers.BasicMapper import *


class ProcessPaired(BasicMapper):
    def __init__(self, mapper: BasicMapper) -> None:
        self.xref(mapper.xref())
        self.core(mapper.core())
        mapper.set_up_logging()

    def process(self) -> None:
        logging.info("Processing paired xrefs")

        xref_dbi = self.xref().connect()

        object_xref_id = None
        change = {
            "translation object xrefs added": 0,
            "translation object xrefs removed": 0,
        }
        RefSeq_pep_translation = {}

        # Get the transcript RefSeq_mRNA% object xrefs, and the paired RefSeq_peptide% accessions as well as the translation id for the transcript
        query = (
            select(
                ObjectXrefUORM.object_xref_id,
                GeneTranscriptTranslationORM.translation_id,
                PairsORM.source_id,
                PairsORM.accession1,
                IdentityXrefUORM.query_identity,
                IdentityXrefUORM.target_identity,
            )
            .join(
                XrefUORM,
                (XrefUORM.xref_id == ObjectXrefUORM.xref_id)
                & (ObjectXrefUORM.ox_status == "DUMP_OUT"),
            )
            .join(
                SourceUORM,
                (SourceUORM.source_id == XrefUORM.source_id)
                & (SourceUORM.name.like("RefSeq_mRNA%")),
            )
            .join(PairsORM, PairsORM.accession2 == XrefUORM.accession)
            .join(
                GeneTranscriptTranslationORM,
                GeneTranscriptTranslationORM.transcript_id == ObjectXrefUORM.ensembl_id,
            )
            .join(
                IdentityXrefUORM,
                IdentityXrefUORM.object_xref_id == ObjectXrefUORM.object_xref_id,
            )
        )
        for row in xref_dbi.execute(query).mappings().all():
            # Check if translation is linked to the paired RefSeq peptide
            if row.translation_id:
                query = (
                    select(ObjectXrefUORM.object_xref_id, ObjectXrefUORM.xref_id)
                    .join(XrefUORM, XrefUORM.xref_id == ObjectXrefUORM.xref_id)
                    .where(
                        ObjectXrefUORM.ox_status.in_(["DUMP_OUT", "FAILED_PRIORITY"]),
                        ObjectXrefUORM.ensembl_object_type == "Translation",
                        ObjectXrefUORM.ensembl_id == row.translation_id,
                        XrefUORM.source_id == row.source_id,
                        XrefUORM.accession == row.accession1,
                    )
                )
                result = xref_dbi.execute(query)
                if result.rowcount > 0:
                    object_xref_row = result.mappings().all()[0]
                    transl_object_xref_id = object_xref_row.object_xref_id
                else:
                    transl_object_xref_id = None

                # If it's already linked we don't have to do anything
                if not transl_object_xref_id:
                    # Get the associated xref ID
                    xref_id = xref_dbi.execute(
                        select(XrefUORM.xref_id).where(
                            XrefUORM.accession == row.accession1,
                            XrefUORM.source_id == row.source_id,
                        )
                    ).scalar()

                    if not xref_id:
                        raise LookupError(
                            f"Xref not found for accession {row.accession1} source_id {row.source_id}"
                        )

                    # Add a new object xref
                    object_xref_id = self.add_object_xref(
                        row.translation_id,
                        xref_id,
                        "Translation",
                        "INFERRED_PAIR",
                        xref_dbi,
                        None,
                        "DUMP_OUT",
                    )

                    # Update info type for xref
                    xref_dbi.execute(
                        update(XrefUORM)
                        .where(XrefUORM.xref_id == xref_id)
                        .values(info_type="INFERRED_PAIR")
                    )

                    # Also insert into identity_xref if needed
                    if row.query_identity and row.target_identity:
                        xref_dbi.execute(
                            insert(IdentityXrefUORM).values(
                                object_xref_id=object_xref_id,
                                query_identity=row.query_identity,
                                target_identity=row.target_identity,
                            )
                        )

                    change["translation object xrefs added"] += 1
                    transl_object_xref_id = object_xref_id

                if transl_object_xref_id:
                    RefSeq_pep_translation.setdefault(row.accession1, []).append(
                        row.translation_id
                    )

        # Go through RefSeq_peptide% object_xrefs
        query = (
            select(
                ObjectXrefUORM.object_xref_id,
                ObjectXrefUORM.ensembl_id,
                XrefUORM.accession,
                GeneTranscriptTranslationORM.transcript_id,
            )
            .join(
                ObjectXrefUORM,
                (
                    ObjectXrefUORM.ensembl_id
                    == GeneTranscriptTranslationORM.translation_id
                )
                & (ObjectXrefUORM.ensembl_object_type == "Translation"),
            )
            .join(
                XrefUORM,
                (XrefUORM.xref_id == ObjectXrefUORM.xref_id)
                & (ObjectXrefUORM.ox_status == "DUMP_OUT")
                & (ObjectXrefUORM.ensembl_object_type == "Translation"),
            )
            .join(
                SourceUORM,
                (SourceUORM.source_id == XrefUORM.source_id)
                & (SourceUORM.name.like("RefSeq_peptide%")),
            )
        )
        for row in xref_dbi.execute(query).mappings().all():
            if RefSeq_pep_translation.get(row.accession):
                found = 0
                for tr_id in RefSeq_pep_translation[row.accession]:
                    if tr_id == row.ensembl_id:
                        found = 1

                if not found:
                    # This translations's transcript is not matched with the paired RefSeq_mRNA%,
                    # change the status to 'MULTI_DELETE'
                    self.update_object_xref_status(
                        row.object_xref_id, "MULTI_DELETE", xref_dbi
                    )

                    # Process all dependent xrefs as well
                    self.process_dependents(
                        row.object_xref_id, row.ensembl_id, row.transcript_id, xref_dbi
                    )

                    change["translation object xrefs removed"] += 1

        for key, val in change.items():
            logging.info(f"{key}:\t{val}")

        xref_dbi.close()

        self.update_process_status("processed_pairs")

    def process_dependents(self, translation_object_xref_id: int, translation_id: int, transcript_id: int, dbi: Connection) -> None:
        master_object_xrefs = []
        new_master_object_xref_id = None
        master_object_xref_ids = {}

        master_object_xrefs.append(translation_object_xref_id)
        master_object_xref_ids[translation_object_xref_id] = 1

        while master_object_xrefs:
            master_object_xref_id = master_object_xrefs.pop()
            dependent_object_xref_id = None

            MasterObjectXref = aliased(ObjectXrefUORM)
            DependentObjectXref = aliased(ObjectXrefUORM)

            MasterXref = aliased(XrefUORM)
            DependentXref = aliased(XrefUORM)

            query = select(DependentObjectXref.object_xref_id.distinct()).where(
                DependentXref.xref_id == DependentXrefUORM.dependent_xref_id,
                MasterXref.xref_id == DependentXrefUORM.master_xref_id,
                DependentXref.xref_id == DependentObjectXref.xref_id,
                MasterXref.xref_id == MasterObjectXref.xref_id,
                MasterObjectXref.object_xref_id == master_object_xref_id,
                DependentObjectXref.master_xref_id == MasterXref.xref_id,
                DependentObjectXref.ensembl_id == translation_id,
                DependentObjectXref.ensembl_object_type == "Translation",
                DependentObjectXref.ox_status == "DUMP_OUT",
            )
            for row in dbi.execute(query).mappings().all():
                self.update_object_xref_status(row.object_xref_id, "MULTI_DELETE", dbi)

                if not master_object_xref_ids.get(row.object_xref_id):
                    master_object_xref_ids[row.object_xref_id] = 1
                    master_object_xrefs.append(row.object_xref_id)

            query = select(DependentObjectXref.object_xref_id.distinct()).where(
                DependentXref.xref_id == DependentXrefUORM.dependent_xref_id,
                MasterXref.xref_id == DependentXrefUORM.master_xref_id,
                DependentXref.xref_id == DependentObjectXref.xref_id,
                MasterXref.xref_id == MasterObjectXref.xref_id,
                MasterObjectXref.object_xref_id == master_object_xref_id,
                DependentObjectXref.master_xref_id == MasterXref.xref_id,
                DependentObjectXref.ensembl_id == transcript_id,
                DependentObjectXref.ensembl_object_type == "Transcript",
                DependentObjectXref.ox_status == "DUMP_OUT",
            )
            for row in dbi.execute(query).mappings().all():
                self.update_object_xref_status(row.object_xref_id, "MULTI_DELETE", dbi)

                if not master_object_xref_ids.get(row.object_xref_id):
                    master_object_xref_ids[row.object_xref_id] = 1
                    master_object_xrefs.append(row.object_xref_id)
