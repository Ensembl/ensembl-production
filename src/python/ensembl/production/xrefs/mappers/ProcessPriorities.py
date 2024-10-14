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

"""Mapper module for processing xref priorities."""

from ensembl.production.xrefs.mappers.BasicMapper import *


class ProcessPriorities(BasicMapper):
    def __init__(self, mapper: BasicMapper) -> None:
        self.xref(mapper.xref())
        self.core(mapper.core())
        mapper.set_up_logging()

    def process(self) -> None:
        logging.info("Processing priorities")

        xref_dbi = self.xref().connect()

        names = self.get_priority_names(xref_dbi)

        for name in names:
            logging.info(f"'{name}' will be processed as priority xrefs")

            # Set to failed all those that have no object xrefs
            query = (
                select(XrefUORM.xref_id)
                .outerjoin(ObjectXrefUORM, ObjectXrefUORM.xref_id == XrefUORM.xref_id)
                .where(
                    XrefUORM.source_id == SourceUORM.source_id,
                    SourceUORM.name == name,
                    ObjectXrefUORM.object_xref_id == None,
                )
            )
            for row in xref_dbi.execute(query).mappings().all():
                self.update_xref_dumped(
                    row.xref_id, "NO_DUMP_ANOTHER_PRIORITY", xref_dbi
                )

        # Now ALL object_xrefs have an identity_xref
        # So we can do a straight join and treat all info_types the same way
        for name in names:
            last_acc, last_name, best_xref_id, last_xref_id, seen = "", "", None, 0, 0
            best_ensembl_id, gone = [], []

            query = (
                select(
                    ObjectXrefUORM.object_xref_id,
                    XrefUORM.accession,
                    XrefUORM.xref_id,
                    (
                        IdentityXrefUORM.query_identity
                        + IdentityXrefUORM.target_identity
                    ).label("identity"),
                    ObjectXrefUORM.ox_status,
                    ObjectXrefUORM.ensembl_object_type,
                    ObjectXrefUORM.ensembl_id,
                    XrefUORM.info_type,
                )
                .where(
                    ObjectXrefUORM.object_xref_id == IdentityXrefUORM.object_xref_id,
                    ObjectXrefUORM.xref_id == XrefUORM.xref_id,
                    XrefUORM.source_id == SourceUORM.source_id,
                    SourceUORM.name == name,
                )
                .order_by(
                    XrefUORM.accession.desc(),
                    SourceUORM.priority,
                    desc("identity"),
                    XrefUORM.xref_id.desc(),
                )
            )
            for row in xref_dbi.execute(query).mappings().all():
                if last_acc == row.accession:
                    if row.xref_id != best_xref_id:
                        # We've already seen this accession before, and this xref_id is not the best one
                        seen = row.xref_id == last_xref_id
                        last_xref_id = row.xref_id

                        # If xref is a sequence_match, we want to copy the alignment identity_xref to prioritised mappings of the same ensembl_id
                        if row.info_type == "SEQUENCE_MATCH":
                            identity_xref_row, object_xref_row = None, None

                            query = select(IdentityXrefUORM).where(
                                IdentityXrefUORM.object_xref_id == row.object_xref_id
                            )
                            result = xref_dbi.execute(query)
                            if result.rowcount > 0:
                                identity_xref_row = result.mappings().all()[0]

                            query = select(ObjectXrefUORM.object_xref_id).where(
                                ObjectXrefUORM.xref_id == best_xref_id,
                                ObjectXrefUORM.ensembl_object_type
                                == row.ensembl_object_type,
                                ObjectXrefUORM.ensembl_id == row.ensembl_id,
                            )
                            result = xref_dbi.execute(query)
                            if result.rowcount > 0:
                                object_xref_row = result.mappings().all()[0]

                            if identity_xref_row and object_xref_row:
                                query = (
                                    update(IdentityXrefUORM)
                                    .where(
                                        IdentityXrefUORM.object_xref_id
                                        == object_xref_row.object_xref_id
                                    )
                                    .values(
                                        query_identity=identity_xref_row.query_identity,
                                        target_identity=identity_xref_row.target_identity,
                                        hit_start=identity_xref_row.hit_start,
                                        hit_end=identity_xref_row.hit_end,
                                        translation_start=identity_xref_row.translation_start,
                                        translation_end=identity_xref_row.translation_end,
                                        cigar_line=identity_xref_row.cigar_line,
                                        score=identity_xref_row.score,
                                        evalue=identity_xref_row.evalue,
                                    )
                                )
                                xref_dbi.execute(query)

                        # If the xref is marked DUMP_OUT, set it to FAILED_PRIORITY
                        if row.ox_status == "DUMP_OUT":
                            xref_dbi.execute(
                                update(ObjectXrefUORM)
                                .where(
                                    ObjectXrefUORM.object_xref_id == row.object_xref_id
                                )
                                .values(ox_status="FAILED_PRIORITY")
                            )

                            # If it is the first time processing this xref_id, also process dependents and update status
                            if not seen:
                                self.update_xref_dumped(
                                    row.xref_id, "NO_DUMP_ANOTHER_PRIORITY", xref_dbi
                                )

                                # Copy synonyms across if they are missing
                                query = select(SynonymORM.synonym).where(
                                    SynonymORM.xref_id == row.xref_id
                                )
                                for synonym_row in (
                                    xref_dbi.execute(query).mappings().all()
                                ):
                                    xref_dbi.execute(
                                        insert(SynonymORM)
                                        .values(
                                            xref_id=best_xref_id,
                                            synonym=synonym_row.synonym,
                                        )
                                        .prefix_with("IGNORE")
                                    )

                                self.process_dependents(
                                    row.xref_id, best_xref_id, xref_dbi
                                )
                        else:
                            # Status is not DUMP_OUT
                            self.update_xref_dumped(
                                row.xref_id, "NO_DUMP_ANOTHER_PRIORITY", xref_dbi
                            )
                    else:
                        # Alignment did not pass, dismiss
                        if row.ox_status == "FAILED_CUTOFF":
                            continue

                        # There might be several mappings for the best priority
                        best_ensembl_id.append(row.ensembl_id)

                    # Best priority failed so another one now found so set dumped
                    if len(gone) > 0:
                        if last_name == row.accession:
                            for x_id in gone:
                                self.update_xref_dumped(
                                    x_id, "NO_DUMP_ANOTHER_PRIORITY", xref_dbi
                                )
                else:
                    # New xref_id
                    if row.ox_status == "DUMP_OUT":
                        last_acc = row.accession
                        best_xref_id = row.xref_id
                        best_ensembl_id = [row.ensembl_id]

                        if len(gone) > 0 and last_name == row.accession:
                            for x_id in gone:
                                self.update_xref_dumped(
                                    x_id, "NO_DUMP_ANOTHER_PRIORITY", xref_dbi
                                )
                            gone = []
                    else:
                        # New xref_id not DUMP_OUT
                        if last_name != row.accession:
                            gone = []

                        gone.append(row.xref_id)
                        last_name = row.accession

        xref_dbi.close()

        self.update_process_status("priorities_flagged")

    def get_priority_names(self, dbi: Connection) -> List[str]:
        names = []
        seen = {}
        last_name = "rubbish"

        query = (
            select(
                SourceUORM.priority_description.label("description"), SourceUORM.name
            )
            .where(SourceUORM.source_id == XrefUORM.source_id)
            .group_by(SourceUORM.priority_description, SourceUORM.name)
            .order_by(SourceUORM.name)
        )
        for row in dbi.execute(query).mappings().all():
            if row.name == last_name and not seen.get(row.name):
                names.append(row.name)
                seen[row.name] = 1
            last_name = row.name

        return names

    def update_xref_dumped(self, xref_id: int, dumped: str, dbi: Connection) -> None:
        dbi.execute(
            update(XrefUORM).where(XrefUORM.xref_id == xref_id).values(dumped=dumped)
        )

    def process_dependents(self, old_master_xref_id: int, new_master_xref_id: int, dbi: Connection) -> None:
        master_xrefs = [old_master_xref_id]
        recursive = 0

        # Create a hash of all possible mappings for this accession
        ensembl_ids = {}
        query = (
            select(
                ObjectXrefUORM.ensembl_object_type.distinct(), ObjectXrefUORM.ensembl_id
            )
            .where(
                ObjectXrefUORM.ox_status != "FAILED_CUTOFF",
                ObjectXrefUORM.xref_id == new_master_xref_id,
            )
            .order_by(ObjectXrefUORM.ensembl_object_type)
        )
        for row in dbi.execute(query).mappings().all():
            ensembl_ids.setdefault(row.ensembl_object_type, []).append(row.ensembl_id)

        old_ensembl_ids = {}
        query = (
            select(
                ObjectXrefUORM.ensembl_object_type.distinct(), ObjectXrefUORM.ensembl_id
            )
            .where(
                ObjectXrefUORM.ox_status != "FAILED_CUTOFF",
                ObjectXrefUORM.xref_id == old_master_xref_id,
            )
            .order_by(ObjectXrefUORM.ensembl_object_type)
        )
        for row in dbi.execute(query).mappings().all():
            old_ensembl_ids.setdefault(row.ensembl_object_type, []).append(
                row.ensembl_id
            )

        # Loop through all dependent xrefs of old master xref, and recurse
        while master_xrefs:
            xref_id = master_xrefs.pop()

            if recursive:
                new_master_xref_id = xref_id

            # Get dependent xrefs, be they gene, transcript or translation
            query = (
                select(
                    DependentXrefUORM.dependent_xref_id.distinct(),
                    DependentXrefUORM.linkage_annotation,
                    DependentXrefUORM.linkage_source_id,
                    ObjectXrefUORM.ensembl_object_type,
                )
                .where(
                    ObjectXrefUORM.xref_id == DependentXrefUORM.dependent_xref_id,
                    ObjectXrefUORM.master_xref_id == DependentXrefUORM.master_xref_id,
                    DependentXrefUORM.master_xref_id == xref_id,
                )
                .order_by(ObjectXrefUORM.ensembl_object_type)
            )
            for row in dbi.execute(query).mappings().all():
                # Remove all mappings to low priority xrefs
                # Then delete any leftover identity xrefs of it
                for ensembl_id in old_ensembl_ids.get(row.ensembl_object_type):
                    self._detach_object_xref(
                        xref_id,
                        row.dependent_xref_id,
                        row.ensembl_object_type,
                        ensembl_id,
                        dbi,
                    )

                # Duplicate each dependent for the new master xref if it is the first in the chain
                if not recursive:
                    dbi.execute(
                        insert(DependentXrefUORM)
                        .values(
                            master_xref_id=new_master_xref_id,
                            dependent_xref_id=row.dependent_xref_id,
                            linkage_annotation=row.linkage_annotation,
                            linkage_source_id=row.linkage_source_id,
                        )
                        .prefix_with("IGNORE")
                    )

                # Loop through all chosen (best) ensembl ids mapped to priority xref, and connect them with object_xrefs
                for ensembl_id in ensembl_ids.get(row.ensembl_object_type):
                    # Add new object_xref for each best_ensembl_id
                    dbi.execute(
                        insert(ObjectXrefUORM)
                        .values(
                            master_xref_id=new_master_xref_id,
                            ensembl_object_type=row.ensembl_object_type,
                            ensembl_id=ensembl_id,
                            linkage_type="DEPENDENT",
                            ox_status="DUMP_OUT",
                            xref_id=row.dependent_xref_id,
                        )
                        .prefix_with("IGNORE")
                    )

                    # Get inserted ID
                    query = select(ObjectXrefUORM.object_xref_id).where(
                        ObjectXrefUORM.master_xref_id == new_master_xref_id,
                        ObjectXrefUORM.ensembl_object_type == row.ensembl_object_type,
                        ObjectXrefUORM.ensembl_id == ensembl_id,
                        ObjectXrefUORM.linkage_type == "DEPENDENT",
                        ObjectXrefUORM.ox_status == "DUMP_OUT",
                        ObjectXrefUORM.xref_id == row.dependent_xref_id,
                    )
                    for object_xref_row in dbi.execute(query).mappings().all():
                        dbi.execute(
                            insert(IdentityXrefUORM)
                            .values(
                                object_xref_id=object_xref_row.object_xref_id,
                                query_identity=100,
                                target_identity=100,
                            )
                            .prefix_with("IGNORE")
                        )

                if row.dependent_xref_id != xref_id:
                    master_xrefs.append(row.dependent_xref_id)

            recursive = 1

    def _detach_object_xref(self, xref_id: int, dependent_xref_id: int, object_type: str, ensembl_id: int, dbi: Connection) -> None:
        # Drop all the identity and go xrefs for the dependents of an xref
        query = (
            select(ObjectXrefUORM.object_xref_id)
            .outerjoin(
                IdentityXrefUORM,
                IdentityXrefUORM.object_xref_id == ObjectXrefUORM.object_xref_id,
            )
            .where(
                ObjectXrefUORM.master_xref_id == xref_id,
                ObjectXrefUORM.ensembl_object_type == object_type,
                ObjectXrefUORM.xref_id == dependent_xref_id,
                ObjectXrefUORM.ensembl_id == ensembl_id,
            )
        )
        result = dbi.execute(query).fetchall()
        object_xref_ids = [row[0] for row in result]

        dbi.execute(
            delete(IdentityXrefUORM).where(
                IdentityXrefUORM.object_xref_id.in_(object_xref_ids)
            )
        )

        # Change status of object_xref to FAILED_PRIORITY for record keeping
        dbi.execute(
            update(ObjectXrefUORM)
            .where(
                ObjectXrefUORM.master_xref_id == xref_id,
                ObjectXrefUORM.ensembl_object_type == object_type,
                ObjectXrefUORM.xref_id == dependent_xref_id,
                ObjectXrefUORM.ox_status == "DUMP_OUT",
                ObjectXrefUORM.ensembl_id == ensembl_id,
            )
            .values(ox_status="FAILED_PRIORITY")
        )

        # Delete the duplicates
        dbi.execute(
            delete(ObjectXrefUORM).where(
                ObjectXrefUORM.master_xref_id == xref_id,
                ObjectXrefUORM.ensembl_object_type == object_type,
                ObjectXrefUORM.xref_id == dependent_xref_id,
                ObjectXrefUORM.ox_status == "DUMP_OUT",
                ObjectXrefUORM.ensembl_id == ensembl_id,
            )
        )
