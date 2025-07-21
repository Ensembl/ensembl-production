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

"""Mapper module for running validity checks on xref data."""

import logging
from sqlalchemy import select, func, text

from ensembl.core.models import (
    Gene as GeneORM,
    ObjectXref as ObjectXrefCORM,
    Xref as XrefCORM,
    ExternalDb as ExternalDbORM
)

from ensembl.xrefs.xref_update_db_model import (
    GeneStableId as GeneStableIdORM,
    TranscriptStableId as TranscriptStableIdORM,
    TranslationStableId as TranslationStableIdORM,
    ObjectXref as ObjectXrefUORM,
    Source as SourceUORM,
    Xref as XrefUORM,
    GeneDirectXref as GeneDirectXrefORM,
    TranscriptDirectXref as TranscriptDirectXrefORM,
    TranslationDirectXref as TranslationDirectXrefORM,
    Synonym as SynonymORM
)

from ensembl.production.xrefs.mappers.BasicMapper import BasicMapper

class TestMappings(BasicMapper):
    def __init__(self, mapper: BasicMapper) -> None:
        self.xref(mapper.xref())
        self.core(mapper.core())
        mapper.set_up_logging()

    def direct_stable_id_check(self) -> int:
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

        total_warnings_count = 0

        for object_type, tables in db_tables.items():
            warnings_count = 0
            direct_table = tables["direct"]
            stable_id_table = tables["stable_id"]

            query = (
                select(SourceUORM.name, func.count(XrefUORM.xref_id).label("count"))
                .join(XrefUORM, SourceUORM.source_id == XrefUORM.source_id)
                .join(direct_table, XrefUORM.xref_id == direct_table.general_xref_id)
                .outerjoin(
                    stable_id_table,
                    stable_id_table.stable_id == direct_table.ensembl_stable_id,
                )
                .where(stable_id_table.stable_id == None)
                .group_by(SourceUORM.name)
            )
            for row in xref_dbi.execute(query).mappings().all():
                logging.warning(
                    f"{row.name} has {row.count} invalid stable IDs in {object_type}_direct_xref"
                )
                warnings_count += 1

            total_warnings_count += warnings_count

        xref_dbi.close()

        self.update_process_status("direct_stable_id_check_done")

        return total_warnings_count

    def xrefs_counts_check(self) -> int:
        xref_dbi = self.xref().connect()
        core_dbi = self.core().connect()

        warnings_count = 0
        core_count, xref_count = {}, {}

        # TO DO: sqlalchemy syntax -- can't figure out how to count 2 columns
        xref_query = text(
            'SELECT s.name, COUNT(DISTINCT x.xref_id, ox.ensembl_id) AS count '
            'FROM xref x '
            'JOIN object_xref ox ON ox.xref_id = x.xref_id '
            'JOIN source s ON x.source_id = s.source_id '
            'WHERE ox_status = "DUMP_OUT" '
            'GROUP BY s.name'
        )
        for row in xref_dbi.execute(xref_query).mappings().all():
            xref_count[row.name] = row.count

        query = (
            select(
                ExternalDbORM.db_name,
                func.count(ObjectXrefCORM.object_xref_id).label("count"),
            )
            .join(XrefCORM, XrefCORM.xref_id == ObjectXrefCORM.xref_id)
            .join(ExternalDbORM, XrefCORM.external_db_id == ExternalDbORM.external_db_id)
            .filter((XrefCORM.info_type == None) | (XrefCORM.info_type != "PROJECTION"))
            .group_by(ExternalDbORM.db_name)
        )
        for row in core_dbi.execute(query).mappings().all():
            change = 0
            core_count[row.db_name] = row.count

            if xref_count.get(row.db_name):
                change = ((xref_count[row.db_name] - row.count) / row.count) * 100

                if change > 5:
                    logging.warning(
                        f"{row.db_name} has increased by {change:.2f}%. It was {row.count} in the core DB, while it is {xref_count[row.db_name]} in the xref DB"
                    )
                    warnings_count += 1
                elif change < -5:
                    logging.warning(
                        f"{row.db_name} has decreased by {change:.2f}%. It was {row.count} in the core DB, while it is {xref_count[row.db_name]} in the xref DB"
                    )
                    warnings_count += 1
            else:
                logging.warning(
                    f"{row.db_name} xrefs are not in the xref DB but {row.count} are in the core DB"
                )
                warnings_count += 1

        for name, count in xref_count.items():
            if not core_count.get(name):
                logging.warning(
                    f"{name} has {count} xrefs in the xref DB but none in the core DB"
                )
                warnings_count += 1

        xref_dbi.close()
        core_dbi.close()

        self.update_process_status("xrefs_counts_check_done")

        return warnings_count

    def name_change_check(self, official_name: str = None) -> int:
        if not official_name:
            return 0

        new_name, id_to_stable_id, alias = {}, {}, {}
        warnings_count, total_count = 0, 0

        xref_dbi = self.xref().connect()
        core_dbi = self.core().connect()

        # Query to get new names and stable IDs
        query = (
            select(XrefUORM.label, GeneStableIdORM.internal_id, GeneStableIdORM.stable_id)
            .join(ObjectXrefUORM, XrefUORM.xref_id == ObjectXrefUORM.object_xref_id)
            .join(GeneStableIdORM, GeneStableIdORM.internal_id == ObjectXrefUORM.ensembl_id)
            .join(SourceUORM, XrefUORM.source_id == SourceUORM.source_id)
            .where(
                ObjectXrefUORM.ensembl_object_type == "Gene",
                SourceUORM.name.like(f"{official_name}_%")
            )
        )
        for row in xref_dbi.execute(query).mappings().all():
            new_name[row.internal_id] = row.label
            id_to_stable_id[row.internal_id] = row.stable_id

        # Query to get aliases
        query = (
            select(XrefUORM.label, SynonymORM.synonym)
            .join(SynonymORM, XrefUORM.xref_id == SynonymORM.xref_id)
            .join(SourceUORM, XrefUORM.source_id == SourceUORM.source_id)
            .where(
                (SourceUORM.name.like(f"{official_name}_%")) | (SourceUORM.name.like("EntrezGene"))
            )
        )
        for row in xref_dbi.execute(query).mappings().all():
            alias[row.synonym] = row.label

        # Query to get current display labels
        query = (
            select(XrefCORM.display_label, GeneORM.gene_id)
            .join(GeneORM, XrefCORM.xref_id == GeneORM.display_xref_id)
            .where(GeneORM.biotype == "protein_coding")
        )
        for row in core_dbi.execute(query).mappings().all():
            if new_name.get(row.gene_id):
                total_count += 1

            if new_name.get(row.gene_id) and new_name[row.gene_id] != row.display_label:
                if not alias.get(row.display_label) or alias.get(row.display_label) != new_name[row.gene_id]:
                    logging.warning(
                        f"gene ID ({row.gene_id}) {id_to_stable_id[row.gene_id]} new = {new_name[row.gene_id]} old = {row.display_label}"
                    )
                    warnings_count += 1

        if total_count:
            logging.warning(
                f"{warnings_count} entries with different names out of {total_count} protein coding gene comparisons"
            )

        xref_dbi.close()
        core_dbi.close()

        self.update_process_status("name_change_check_done")

        return warnings_count
