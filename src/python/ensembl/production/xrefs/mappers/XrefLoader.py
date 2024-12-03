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

"""Mapper module for loading xref data into the core DB."""

import logging
import re
from datetime import datetime
from sqlalchemy import select, func, update, delete
from sqlalchemy.dialects.mysql import insert
from sqlalchemy.orm import sessionmaker, aliased, Session
from sqlalchemy.engine import Connection
from sqlalchemy.exc import SQLAlchemyError
from typing import Any, Dict

from ensembl.core.models import (
    Gene as GeneORM,
    ObjectXref as ObjectXrefCORM,
    Xref as XrefCORM,
    ExternalDb as ExternalDbORM,
    UnmappedObject as UnmappedObjectORM,
    Analysis as AnalysisORM,
    OntologyXref as OntologyXrefORM,
    ExternalSynonym as ExternalSynonymORM,
    DependentXref as DependentXrefCORM,
    IdentityXref as IdentityXrefCORM
)

from ensembl.xrefs.xref_update_db_model import (
    ObjectXref as ObjectXrefUORM,
    Source as SourceUORM,
    Xref as XrefUORM,
    IdentityXref as IdentityXrefUORM,
    DependentXref as DependentXrefUORM,
    Synonym as SynonymORM,
    PrimaryXref as PrimaryXrefORM
)

from ensembl.production.xrefs.mappers.BasicMapper import BasicMapper

class XrefLoader(BasicMapper):
    def __init__(self, mapper: BasicMapper) -> None:
        self.xref(mapper.xref())
        self.core(mapper.core())
        mapper.set_up_logging()

    def update(self, species_name: str) -> None:
        logging.info("Loading xrefs into core DB")

        xref_dbi = self.xref().connect()
        core_dbi = self.core().connect()

        # Delete xref data related to projections
        self.delete_projection_data(core_dbi)

        # Get the source IDs of relevant external DBs
        name_to_external_db_id = {}
        source_id_to_external_db_id = {}

        query = select(ExternalDbORM.external_db_id, ExternalDbORM.db_name)
        for row in core_dbi.execute(query).mappings().all():
            name_to_external_db_id[row.db_name] = row.external_db_id

        query = (
            select(SourceUORM.source_id, SourceUORM.name)
            .where(SourceUORM.source_id == XrefUORM.source_id)
            .group_by(SourceUORM.source_id)
        )
        for row in xref_dbi.execute(query).mappings().all():
            if name_to_external_db_id.get(row.name):
                source_id_to_external_db_id[row.source_id] = name_to_external_db_id[row.name]
            elif re.search(r"notransfer$", row.name):
                continue
            else:
                raise LookupError(f"Could not find {row.name} in external_db table in the core DB")

        # Reset dumped field in case module is running again
        xref_dbi.execute(
            update(XrefUORM)
            .values(dumped=None)
            .where(XrefUORM.dumped != "NO_DUMP_ANOTHER_PRIORITY")
        )

        # Delete existing xrefs in core DB (only from relevant sources)
        self.deleted_existing_xrefs(name_to_external_db_id, xref_dbi)

        # Get the offsets for xref and object_xref tables
        xref_offset = core_dbi.execute(select(func.max(XrefCORM.xref_id))).scalar() or 0
        object_xref_offset = core_dbi.execute(select(func.max(ObjectXrefCORM.object_xref_id))).scalar() or 0

        self.add_meta_pair("xref_offset", xref_offset)
        self.add_meta_pair("object_xref_offset", object_xref_offset)

        logging.info(f"DB offsets: xref={xref_offset}, object_xref={object_xref_offset}")

        # Get analysis IDs
        analysis_ids = self.get_analysis(core_dbi)

        # Prepare some queries
        xref_object_query = (
            select(XrefUORM, ObjectXrefUORM)
            .where(
                ObjectXrefUORM.ox_status == "DUMP_OUT",
                ObjectXrefUORM.xref_id == XrefUORM.xref_id,
            )
            .order_by(XrefUORM.xref_id)
        )
        xref_object_identity_query = (
            select(XrefUORM, ObjectXrefUORM, IdentityXrefUORM)
            .where(
                ObjectXrefUORM.ox_status == "DUMP_OUT",
                IdentityXrefUORM.object_xref_id == ObjectXrefUORM.object_xref_id,
                ObjectXrefUORM.xref_id == XrefUORM.xref_id,
            )
            .order_by(XrefUORM.xref_id)
        )

        # Get source info from xref DB
        query = (
            select(
                SourceUORM.source_id,
                SourceUORM.name,
                XrefUORM.info_type,
                func.count(XrefUORM.xref_id).label("count"),
                SourceUORM.priority_description,
                SourceUORM.source_release,
            )
            .where(
                ObjectXrefUORM.xref_id == XrefUORM.xref_id,
                XrefUORM.source_id == SourceUORM.source_id,
                ObjectXrefUORM.ox_status == "DUMP_OUT",
            )
            .group_by(SourceUORM.source_id, SourceUORM.name, XrefUORM.info_type)
        )
        for source_row in xref_dbi.execute(query).mappings().all():
            # We only care about specific sources
            if not name_to_external_db_id.get(source_row.name):
                continue
            logging.info(f"Updating source '{source_row.name}' ({source_row.source_id}) in core")

            where_from = source_row.priority_description
            if where_from:
                where_from = f"Generated via {where_from}"

            external_id = name_to_external_db_id[source_row.name]
            xref_list = []

            Session = sessionmaker(bind=self.core().execution_options(isolation_level="READ COMMITTED"))
            with Session.begin() as session:
                try:
                    if source_row.info_type in ["DIRECT", "INFERRED_PAIR", "MISC"]:
                        count, last_xref_id = 0, 0

                        # Get all direct, inferred pair and misc xrefs from intermediate DB
                        query = xref_object_identity_query.where(
                            XrefUORM.source_id == source_row.source_id,
                            XrefUORM.info_type == source_row.info_type,
                        )
                        for xref_row in xref_dbi.execute(query).mappings().all():
                            xref_id = int(xref_row.xref_id)
                            object_xref_id = int(xref_row.object_xref_id)

                            if last_xref_id != xref_id:
                                xref_list.append(xref_id)
                                count += 1

                                # Add xref into core DB
                                info_text = xref_row.info_text or where_from
                                xref_args = {
                                    "xref_id": xref_id,
                                    "accession": xref_row.accession,
                                    "external_db_id": external_id,
                                    "label": xref_row.label,
                                    "description": xref_row.description,
                                    "version": xref_row.version,
                                    "info_type": xref_row.info_type,
                                    "info_text": info_text,
                                }
                                xref_id = self.add_xref(xref_offset, xref_args, session)
                                last_xref_id = xref_id

                            # Add object xref into core DB
                            object_xref_args = {
                                "object_xref_id": object_xref_id,
                                "ensembl_id": xref_row.ensembl_id,
                                "ensembl_type": xref_row.ensembl_object_type,
                                "xref_id": xref_id + xref_offset,
                                "analysis_id": analysis_ids[xref_row.ensembl_object_type],
                            }
                            object_xref_id = self.add_object_xref(object_xref_offset, object_xref_args, session)

                            # Add identity xref into core DB
                            if xref_row.translation_start:
                                query = (
                                    insert(IdentityXrefCORM)
                                    .values(
                                        object_xref_id=object_xref_id + object_xref_offset,
                                        xref_identity=xref_row.query_identity,
                                        ensembl_identity=xref_row.target_identity,
                                        xref_start=xref_row.hit_start,
                                        xref_end=xref_row.hit_end,
                                        ensembl_start=xref_row.translation_start,
                                        ensembl_end=xref_row.translation_end,
                                        cigar_line=xref_row.cigar_line,
                                        score=xref_row.score,
                                        evalue=xref_row.evalue,
                                    )
                                    .prefix_with("IGNORE")
                                )
                                session.execute(query)

                        logging.info(f"\tLoaded {count} {source_row.info_type} xrefs for '{species_name}'")
                    elif source_row.info_type == "CHECKSUM":
                        count, last_xref_id = 0, 0

                        # Get all checksum xrefs from intermediate DB
                        query = xref_object_query.where(
                            XrefUORM.source_id == source_row.source_id,
                            XrefUORM.info_type == source_row.info_type,
                        )
                        for xref_row in xref_dbi.execute(query).mappings().all():
                            xref_id = int(xref_row.xref_id)
                            object_xref_id = int(xref_row.object_xref_id)

                            if last_xref_id != xref_id:
                                xref_list.append(xref_id)
                                count += 1

                                # Add xref into core DB
                                info_text = xref_row.info_text or where_from
                                xref_args = {
                                    "xref_id": xref_id,
                                    "accession": xref_row.accession,
                                    "external_db_id": external_id,
                                    "label": xref_row.label,
                                    "description": xref_row.description,
                                    "version": xref_row.version,
                                    "info_type": xref_row.info_type,
                                    "info_text": info_text,
                                }
                                xref_id = self.add_xref(xref_offset, xref_args, session)
                                last_xref_id = xref_id

                            # Add object xref into core DB
                            object_xref_args = {
                                "object_xref_id": object_xref_id,
                                "ensembl_id": xref_row.ensembl_id,
                                "ensembl_type": xref_row.ensembl_object_type,
                                "xref_id": xref_id + xref_offset,
                                "analysis_id": analysis_ids["checksum"],
                            }
                            object_xref_id = self.add_object_xref(object_xref_offset, object_xref_args, session)

                        logging.info(f"\tLoaded {count} CHECKSUM xrefs for '{species_name}'")
                    elif source_row.info_type == "DEPENDENT":
                        count, last_xref_id, last_ensembl_id, master_error_count = 0, 0, 0, 0
                        master_problems = []

                        # Get all dependent xrefs from intermediate DB
                        MasterXref = aliased(XrefUORM)
                        query = (
                            select(XrefUORM, ObjectXrefUORM)
                            .where(
                                ObjectXrefUORM.ox_status == "DUMP_OUT",
                                ObjectXrefUORM.xref_id == XrefUORM.xref_id,
                                ObjectXrefUORM.master_xref_id == MasterXref.xref_id,
                                MasterXref.source_id == SourceUORM.source_id,
                                XrefUORM.source_id == source_row.source_id,
                                XrefUORM.info_type == "DEPENDENT",
                            )
                            .order_by(XrefUORM.xref_id, ObjectXrefUORM.ensembl_id, SourceUORM.ordered)
                        )
                        for xref_row in xref_dbi.execute(query).mappings().all():
                            xref_id = int(xref_row.xref_id)
                            object_xref_id = int(xref_row.object_xref_id)

                            if last_xref_id != xref_id:
                                xref_list.append(xref_id)
                                count += 1

                                # Add xref into core DB
                                label = xref_row.label or xref_row.accession
                                info_text = xref_row.info_text or where_from
                                xref_args = {
                                    "xref_id": xref_id,
                                    "accession": xref_row.accession,
                                    "external_db_id": external_id,
                                    "label": label,
                                    "description": xref_row.description,
                                    "version": xref_row.version,
                                    "info_type": xref_row.info_type,
                                    "info_text": info_text,
                                }
                                xref_id = self.add_xref(xref_offset, xref_args, session)

                            if last_xref_id != xref_id or last_ensembl_id != xref_row.ensembl_id:
                                # Add object xref into core DB
                                object_xref_args = {
                                    "object_xref_id": object_xref_id,
                                    "ensembl_id": xref_row.ensembl_id,
                                    "ensembl_type": xref_row.ensembl_object_type,
                                    "xref_id": xref_id + xref_offset,
                                    "analysis_id": analysis_ids[xref_row.ensembl_object_type],
                                }
                                object_xref_id = self.add_object_xref(object_xref_offset, object_xref_args, session)

                                if xref_row.master_xref_id:
                                    # Add dependent xref into core DB
                                    session.execute(
                                        insert(DependentXrefCORM)
                                        .values(
                                            object_xref_id=object_xref_id + object_xref_offset,
                                            master_xref_id=xref_row.master_xref_id + xref_offset,
                                            dependent_xref_id=xref_id + xref_offset,
                                        )
                                        .prefix_with("IGNORE")
                                    )
                                else:
                                    if master_error_count < 10:
                                        master_problems.append(xref_row.accession)
                                    master_error_count += 1

                            last_xref_id = xref_id
                            last_ensembl_id = xref_row.ensembl_id

                        if master_problems:
                            logging.warning(
                                f"For {source_row.name}, there were {master_error_count} problem master xrefs. Examples are: "
                                + ", ".join(master_problems)
                            )

                        logging.info(f"\tLoaded {count} DEPENDENT xrefs for '{species_name}'")
                    elif source_row.info_type == "SEQUENCE_MATCH":
                        count, last_xref_id = 0, 0

                        # Get all direct, inferred pair and misc xrefs from intermediate DB
                        query = xref_object_identity_query.where(
                            XrefUORM.source_id == source_row.source_id,
                            XrefUORM.info_type == source_row.info_type,
                        )
                        for xref_row in xref_dbi.execute(query).mappings().all():
                            xref_id = int(xref_row.xref_id)
                            object_xref_id = int(xref_row.object_xref_id)

                            if last_xref_id != xref_id:
                                xref_list.append(xref_id)
                                count += 1

                                # Add xref into core DB
                                info_text = xref_row.info_text or where_from
                                xref_args = {
                                    "xref_id": xref_id,
                                    "accession": xref_row.accession,
                                    "external_db_id": external_id,
                                    "label": xref_row.label,
                                    "description": xref_row.description,
                                    "version": xref_row.version,
                                    "info_type": xref_row.info_type,
                                    "info_text": info_text,
                                }
                                xref_id = self.add_xref(xref_offset, xref_args, session)
                                last_xref_id = xref_id

                            # Add object xref into core DB
                            object_xref_args = {
                                "object_xref_id": object_xref_id,
                                "ensembl_id": xref_row.ensembl_id,
                                "ensembl_type": xref_row.ensembl_object_type,
                                "xref_id": xref_id + xref_offset,
                                "analysis_id": analysis_ids[xref_row.ensembl_object_type],
                            }
                            object_xref_id = self.add_object_xref(object_xref_offset, object_xref_args, session)

                            # Add identity xref into core DB
                            query = (
                                insert(IdentityXrefCORM)
                                .values(
                                    object_xref_id=object_xref_id + object_xref_offset,
                                    xref_identity=xref_row.query_identity,
                                    ensembl_identity=xref_row.target_identity,
                                    xref_start=xref_row.hit_start,
                                    xref_end=xref_row.hit_end,
                                    ensembl_start=xref_row.translation_start,
                                    ensembl_end=xref_row.translation_end,
                                    cigar_line=xref_row.cigar_line,
                                    score=xref_row.score,
                                    evalue=xref_row.evalue,
                                )
                                .prefix_with("IGNORE")
                            )
                            session.execute(query)

                        logging.info(f"\tLoaded {count} SEQUENCE_MATCH xrefs for '{species_name}'")
                    else:
                        logging.debug(f"\tPROBLEM: what type is {source_row.info_type}")

                    # Transfer synonym data
                    if xref_list:
                        syn_count = 0

                        # Get synonyms
                        query = select(SynonymORM.xref_id, SynonymORM.synonym).where(
                            SynonymORM.xref_id.in_(xref_list)
                        )
                        for syn_row in xref_dbi.execute(query).mappings().all():
                            session.execute(
                                insert(ExternalSynonymORM).values(
                                    xref_id=syn_row.xref_id + xref_offset,
                                    synonym=syn_row.synonym,
                                )
                            )
                            syn_count += 1

                        logging.info(f"\tLoaded {syn_count} synonyms for '{species_name}'")

                        # Set dumped status
                        xref_dbi.execute(
                            update(XrefUORM)
                            .values(dumped="MAPPED")
                            .where(XrefUORM.xref_id.in_(xref_list))
                        )

                    # Update release info
                    if source_row.source_release and source_row.source_release != "1":
                        session.execute(
                            update(ExternalDbORM)
                            .values(db_release=source_row.source_release)
                            .where(ExternalDbORM.external_db_id == external_id)
                        )

                    session.commit()
                except SQLAlchemyError as e:
                    session.rollback()
                    logging.error(f"Failed to load xrefs for source '{source_row.name}': {e}")
                    raise RuntimeError(f"Transaction failed for source '{source_row.name}'")

        # Update the unmapped xrefs
        self.update_unmapped_xrefs(xref_dbi)

        self.update_process_status("core_loaded")

        xref_dbi.close()
        core_dbi.close()

    def delete_projection_data(self, dbi: Connection) -> None:
        # Delete all the projections from the core DB

        dbi.execute(delete(OntologyXrefORM))
        logging.info("Deleted all ontology_xref rows")

        row_count = dbi.execute(
            update(GeneORM)
            .values(display_xref_id=None, description=None)
            .where(
                XrefCORM.xref_id == GeneORM.display_xref_id,
                XrefCORM.info_type == "PROJECTION",
            )
        ).rowcount
        logging.info(
            f"Set display_xref_id and description to NULL in {row_count} gene row(s) related to PROJECTION xrefs"
        )

        counts = {}
        counts["external_synonym"] = dbi.execute(
            delete(ExternalSynonymORM).where(
                XrefCORM.xref_id == ExternalSynonymORM.xref_id,
                XrefCORM.info_type == "PROJECTION",
            )
        ).rowcount
        counts["dependent_xref"] = dbi.execute(
            delete(DependentXrefCORM).where(
                XrefCORM.xref_id == DependentXrefCORM.dependent_xref_id,
                XrefCORM.info_type == "PROJECTION",
            )
        ).rowcount
        counts["object_xref"] = dbi.execute(
            delete(ObjectXrefCORM).where(
                XrefCORM.xref_id == ObjectXrefCORM.xref_id,
                XrefCORM.info_type == "PROJECTION",
            )
        ).rowcount
        counts["xref"] = dbi.execute(
            delete(XrefCORM).where(XrefCORM.info_type == "PROJECTION")
        ).rowcount

        logging.info(
            f"Deleted all PROJECTIONs rows: {counts['external_synonym']} external_synonyms, {counts['dependent_xref']} dependent_xrefs, {counts['object_xref']} object_xrefs, {counts['xref']} xrefs"
        )

    def deleted_existing_xrefs(self, name_to_external_db_id: Dict[str, int], xref_dbi: Connection) -> None:
        # For each external_db to be updated, delete the existing xrefs
        query = (
            select(SourceUORM.name, func.count(XrefUORM.xref_id).label("count"))
            .where(
                XrefUORM.xref_id == ObjectXrefUORM.xref_id,
                XrefUORM.source_id == SourceUORM.source_id,
            )
            .group_by(SourceUORM.name)
        )
        for row in xref_dbi.execute(query).mappings().all():
            name = row.name
            external_db_id = name_to_external_db_id.get(name)
            if not external_db_id:
                continue

            counts = {
                "gene": 0,
                "external_synonym": 0,
                "identity_xref": 0,
                "object_xref": 0,
                "master_dependent_xref": 0,
                "master_object_xref": 0,
                "dependent_xref": 0,
                "xref": 0,
                "unmapped_object": 0,
            }

            logging.info(f"For source '{name}'")

            Session = sessionmaker(bind=self.core().execution_options(isolation_level="READ COMMITTED"))
            with Session.begin() as session:
                try:
                    counts["gene"] = session.execute(
                        update(GeneORM)
                        .values(display_xref_id=None, description=None)
                        .where(
                            GeneORM.display_xref_id == XrefCORM.xref_id,
                            XrefCORM.external_db_id == external_db_id,
                        )
                    ).rowcount
                    logging.info(
                        f"\tSet display_xref_id=NULL and description=NULL for {counts['gene']} gene row(s)"
                    )

                    counts["external_synonym"] = session.execute(
                        delete(ExternalSynonymORM).where(
                            ExternalSynonymORM.xref_id == XrefCORM.xref_id,
                            XrefCORM.external_db_id == external_db_id,
                        )
                    ).rowcount
                    counts["identity_xref"] = session.execute(
                        delete(IdentityXrefCORM).where(
                            IdentityXrefCORM.object_xref_id == ObjectXrefCORM.object_xref_id,
                            ObjectXrefCORM.xref_id == XrefCORM.xref_id,
                            XrefCORM.external_db_id == external_db_id,
                        )
                    ).rowcount
                    counts["object_xref"] = session.execute(
                        delete(ObjectXrefCORM).where(
                            ObjectXrefCORM.xref_id == XrefCORM.xref_id,
                            XrefCORM.external_db_id == external_db_id,
                        )
                    ).rowcount

                    MasterXref = aliased(XrefCORM)
                    DependentXref = aliased(XrefCORM)

                    query = select(
                        ObjectXrefCORM.object_xref_id,
                        DependentXrefCORM.master_xref_id,
                        DependentXrefCORM.dependent_xref_id,
                    ).where(
                        ObjectXrefCORM.object_xref_id == DependentXrefCORM.object_xref_id,
                        MasterXref.xref_id == DependentXrefCORM.master_xref_id,
                        DependentXref.xref_id == DependentXrefCORM.dependent_xref_id,
                        MasterXref.external_db_id == external_db_id,
                    )
                    for sub_row in session.execute(query).mappings().all():
                        counts["master_dependent_xref"] += session.execute(
                            delete(DependentXrefCORM).where(
                                DependentXrefCORM.master_xref_id == sub_row.master_xref_id,
                                DependentXrefCORM.dependent_xref_id == sub_row.dependent_xref_id,
                            )
                        ).rowcount
                        counts["master_object_xref"] += session.execute(
                            delete(ObjectXrefCORM).where(
                                ObjectXrefCORM.object_xref_id == sub_row.object_xref_id
                            )
                        ).rowcount

                    counts["dependent_xref"] = session.execute(
                        delete(DependentXrefCORM).where(
                            DependentXrefCORM.dependent_xref_id == XrefCORM.xref_id,
                            XrefCORM.external_db_id == external_db_id,
                        )
                    ).rowcount
                    counts["xref"] = session.execute(
                        delete(XrefCORM).where(XrefCORM.external_db_id == external_db_id)
                    ).rowcount
                    counts["unmapped_object"] = session.execute(
                        delete(UnmappedObjectORM).where(
                            UnmappedObjectORM.unmapped_object_type == "xref",
                            UnmappedObjectORM.external_db_id == external_db_id,
                        )
                    ).rowcount

                    logging.info(
                        f"\tDeleted rows: {counts['external_synonym']} external_synonyms, {counts['identity_xref']} identity_xrefs, {counts['object_xref']} object_xrefs, {counts['master_dependent_xref']} master dependent_xrefs, {counts['master_object_xref']} master object_xrefs, {counts['dependent_xref']} dependent_xrefs, {counts['xref']} xrefs, {counts['unmapped_object']} unmapped_objects"
                    )

                    session.commit()
                except SQLAlchemyError as e:
                    session.rollback()
                    logging.error(f"Failed to delete rows for source '{name}': {e}")
                    raise RuntimeError(f"Transaction failed for source '{name}'")

    def get_analysis(self, dbi: Connection) -> Dict[str, int]:
        analysis_ids = {}
        type_to_logic_name = {
            "Gene": "xrefexoneratedna",
            "Transcript": "xrefexoneratedna",
            "Translation": "xrefexonerateprotein",
        }

        for object_type, logic_name in type_to_logic_name.items():
            analysis_ids[object_type] = self.get_single_analysis(logic_name, dbi)

        # Add checksum analysis ID
        analysis_ids["checksum"] = self.get_single_analysis("xrefchecksum", dbi)

        return analysis_ids

    def get_single_analysis(self, logic_name: str, dbi: Connection) -> int:
        # Retrieve the analysis ID for the given logic name
        analysis_id = dbi.execute(
            select(AnalysisORM.analysis_id).where(AnalysisORM.logic_name == logic_name)
        ).scalar()

        # If the analysis ID does not exist, create a new analysis entry
        if not analysis_id:
            Session = sessionmaker(self.core())
            with Session.begin() as session:
                now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                analysis_object = AnalysisORM(logic_name=logic_name, created=now)
                session.add(analysis_object)
                session.flush()
                analysis_id = analysis_object.analysis_id

        return analysis_id

    def add_xref(self, offset: int, args: Dict[str, Any], session: Session) -> int:
        xref_id = args["xref_id"]
        accession = args["accession"]
        external_db_id = args["external_db_id"]
        label = args["label"]
        description = args["description"]
        version = args["version"]
        info_type = args["info_type"]
        info_text = args["info_text"]

        # Check if the xref already exists
        new_xref_id = session.execute(
            select(XrefCORM.xref_id).where(
                XrefCORM.dbprimary_acc == accession,
                XrefCORM.external_db_id == external_db_id,
                XrefCORM.info_type == info_type,
                XrefCORM.info_text == info_text,
                XrefCORM.version == version,
            )
        ).scalar()

        # If it doesn't exist, insert it
        if not new_xref_id:
            session.execute(
                insert(XrefCORM).values(
                    xref_id=xref_id + offset,
                    external_db_id=external_db_id,
                    dbprimary_acc=accession,
                    display_label=label,
                    version=version,
                    description=description,
                    info_type=info_type,
                    info_text=info_text,
                )
            )
            return xref_id
        else:
            return int(new_xref_id) - offset

    def add_object_xref(self, offset: int, args: Dict[str, Any], session: Session) -> int:
        object_xref_id = args["object_xref_id"]
        ensembl_id = args["ensembl_id"]
        ensembl_type = args["ensembl_type"]
        xref_id = args["xref_id"]
        analysis_id = args["analysis_id"]

        # Check if the object_xref already exists
        new_object_xref_id = session.execute(
            select(ObjectXrefCORM.object_xref_id).where(
                ObjectXrefCORM.xref_id == xref_id,
                ObjectXrefCORM.ensembl_object_type == ensembl_type,
                ObjectXrefCORM.ensembl_id == ensembl_id,
                ObjectXrefCORM.analysis_id == analysis_id,
            )
        ).scalar()

        # If it doesn't exist, insert it
        if not new_object_xref_id:
            session.execute(
                insert(ObjectXrefCORM).values(
                    object_xref_id=object_xref_id + offset,
                    ensembl_id=ensembl_id,
                    ensembl_object_type=ensembl_type,
                    xref_id=xref_id,
                    analysis_id=analysis_id,
                )
            )
            return object_xref_id
        else:
            return int(new_object_xref_id) - offset

    def update_unmapped_xrefs(self, dbi: Connection) -> None:
        logging.info("Updating unmapped xrefs in xref DB")

        # Direct xrefs
        query = (
            select(XrefUORM.xref_id)
            .outerjoin(ObjectXrefUORM, XrefUORM.xref_id == ObjectXrefUORM.xref_id)
            .where(
                XrefUORM.source_id == SourceUORM.source_id,
                XrefUORM.dumped == None,
                ObjectXrefUORM.ox_status != "FAILED_PRIORITY",
                XrefUORM.info_type == "DIRECT",
            )
        )
        xref_ids = [row.xref_id for row in dbi.execute(query).mappings().all()]
        dbi.execute(
            update(XrefUORM)
            .values(dumped="UNMAPPED_NO_STABLE_ID")
            .where(XrefUORM.xref_id.in_(xref_ids))
        )

        # Misc xrefs
        dbi.execute(
            update(XrefUORM)
            .values(dumped="UNMAPPED_NO_MAPPING")
            .where(
                XrefUORM.source_id == SourceUORM.source_id,
                XrefUORM.dumped == None,
                XrefUORM.info_type == "MISC",
            )
        )

        # Dependent xrefs
        MasterXref = aliased(XrefUORM)
        DependentXref = aliased(XrefUORM)
        query = (
            select(DependentXref.xref_id)
            .outerjoin(
                DependentXrefUORM,
                DependentXrefUORM.dependent_xref_id == DependentXref.xref_id,
            )
            .outerjoin(ObjectXrefUORM, ObjectXrefUORM.xref_id == DependentXref.xref_id)
            .where(
                DependentXref.source_id == SourceUORM.source_id,
                DependentXrefUORM.master_xref_id == MasterXref.xref_id,
                DependentXref.dumped == None,
                ObjectXrefUORM.ox_status != "FAILED_PRIORITY",
                DependentXref.info_type == "DEPENDENT",
            )
        )
        xref_ids = [row.xref_id for row in dbi.execute(query).mappings().all()]
        dbi.execute(
            update(XrefUORM)
            .values(dumped="UNMAPPED_MASTER_FAILED")
            .where(XrefUORM.xref_id.in_(xref_ids))
        )

        # Sequence match
        query = (
            select(XrefUORM.xref_id)
            .outerjoin(ObjectXrefUORM, XrefUORM.xref_id == ObjectXrefUORM.xref_id)
            .outerjoin(
                IdentityXrefUORM,
                IdentityXrefUORM.object_xref_id == ObjectXrefUORM.object_xref_id,
            )
            .where(
                XrefUORM.source_id == SourceUORM.source_id,
                XrefUORM.xref_id == PrimaryXrefORM.xref_id,
                XrefUORM.dumped == None,
                XrefUORM.info_type == "SEQUENCE_MATCH",
            )
        )
        xref_ids = [row.xref_id for row in dbi.execute(query).mappings().all()]
        dbi.execute(
            update(XrefUORM)
            .values(dumped="UNMAPPED_NO_MAPPING")
            .where(XrefUORM.xref_id.in_(xref_ids))
        )

        # Dependents with non-existent masters (none at the time of loading)
        dbi.execute(
            update(XrefUORM)
            .values(dumped="UNMAPPED_NO_MASTER")
            .where(
                XrefUORM.source_id == SourceUORM.source_id,
                XrefUORM.dumped == None,
                XrefUORM.info_type == "DEPENDENT",
            )
        )
