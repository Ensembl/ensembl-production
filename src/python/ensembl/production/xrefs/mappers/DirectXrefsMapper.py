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

"""Mapper module for processing direct xref data."""

from ensembl.production.xrefs.mappers.BasicMapper import *


class DirectXrefsMapper(BasicMapper):
    def __init__(self, mapper: BasicMapper) -> None:
        self.xref(mapper.xref())
        self.core(mapper.core())
        mapper.set_up_logging()

    def process(self) -> None:
        xref_dbi = self.xref().connect()

        db_tables = {
            "gene": {"direct": GeneDirectXrefORM, "stable_id": GeneStableIdORM},
            "transcript": {
                "direct": TranscriptDirectXrefORM,
                "stable_id": TranscriptStableIdORM,
            },
            "translation": {
                "direct": TranslationDirectXrefORM,
                "stable_id": TranslationStableIdORM,
            },
        }

        err_count = {}
        object_xref_id = 0

        for table in ["gene", "transcript", "translation"]:
            direct_table = db_tables[table]["direct"]
            stable_id_table = db_tables[table]["stable_id"]

            count, duplicate_direct_count, duplicate_dependent_count = 0, 0, 0

            # Get the direct xrefs
            stable_id_query = (
                select(
                    SourceUORM.name,
                    direct_table.general_xref_id,
                    stable_id_table.internal_id,
                    direct_table.ensembl_stable_id,
                )
                .outerjoin(
                    stable_id_table,
                    stable_id_table.stable_id == direct_table.ensembl_stable_id,
                )
                .where(
                    XrefUORM.xref_id == direct_table.general_xref_id,
                    XrefUORM.source_id == SourceUORM.source_id,
                )
            )
            for row in xref_dbi.execute(stable_id_query).mappings().all():
                dbname = row.name
                xref_id = row.general_xref_id
                internal_id = row.internal_id
                stable_id = row.ensembl_stable_id

                # Check if internal id exists. If not, it is an internal id already or stable_id no longer exists
                if internal_id is None:
                    if re.search(r"^\d+$", stable_id):
                        internal_id = stable_id
                    else:
                        err_count[dbname] = err_count.get(dbname, 0) + 1
                        continue

                object_xref_id += 1
                count += 1
                master_xref_ids = []

                if internal_id == 0:
                    raise LookupError(
                        f"Problem: could not find stable id {stable_id} and got past the first check for {dbname}"
                    )

                # Insert into object xref table
                object_xref_id = self.get_object_xref_id(
                    internal_id, xref_id, table, "DIRECT", xref_dbi
                )
                if object_xref_id:
                    duplicate_direct_count += 1
                    continue
                else:
                    object_xref_id = self.add_object_xref(
                        internal_id, xref_id, table, "DIRECT", xref_dbi
                    )

                # Insert into identity xref table
                xref_dbi.execute(
                    insert(IdentityXrefUORM).values(
                        object_xref_id=object_xref_id,
                        query_identity=100,
                        target_identity=100,
                    )
                )
                master_xref_ids.append(xref_id)

                duplicate_dependent_count += self.process_dependents(
                    {
                        "master_xrefs": master_xref_ids,
                        "dup_count": duplicate_dependent_count,
                        "table": table,
                        "internal_id": internal_id,
                    },
                    xref_dbi,
                )

            if duplicate_direct_count or duplicate_dependent_count:
                logging.info(
                    f"Duplicate entries ignored for {duplicate_direct_count} direct xrefs and  {duplicate_dependent_count} dependent xrefs"
                )

        for key, val in err_count.items():
            logging.warning(
                f"{val} direct xrefs for database {key} could not be added as their stable_ids could not be found"
            )

        xref_dbi.close()

        self.update_process_status("direct_xrefs_parsed")

    def process_dependents(self, args: Dict[str, Any], dbi: Connection) -> int:
        master_xref_ids = args["master_xrefs"]
        duplicate_dep_count = args["dup_count"]
        table = args["table"]
        internal_id = args["internal_id"]

        for master_xref_id in master_xref_ids:
            # Get all dependents related to master xref
            dep_query = select(DependentXrefUORM.dependent_xref_id).where(
                DependentXrefUORM.master_xref_id == master_xref_id
            )
            for dep in dbi.execute(dep_query).mappings().all():
                # Add dependent object xref
                dep_object_xref_id = self.get_object_xref_id(
                    internal_id,
                    dep.dependent_xref_id,
                    table,
                    "DEPENDENT",
                    dbi,
                    master_xref_id,
                )
                if dep_object_xref_id:
                    duplicate_dep_count += 1
                    continue
                else:
                    dep_object_xref_id = self.add_object_xref(
                        internal_id,
                        dep.dependent_xref_id,
                        table,
                        "DEPENDENT",
                        dbi,
                        master_xref_id,
                    )

                # Add identity xref
                dbi.execute(
                    insert(IdentityXrefUORM).values(
                        object_xref_id=dep_object_xref_id,
                        query_identity=100,
                        target_identity=100,
                    )
                )

                # Get the dependent dependents just in case
                master_xref_ids.append(dep.dependent_xref_id)

        return duplicate_dep_count
