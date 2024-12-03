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

"""Mapper module for loading core data into an xref database."""

import logging
from typing import Any, Dict, List, Optional
from sqlalchemy import select, insert, delete
from sqlalchemy.engine import Connection

from ensembl.core.models import (
    Gene as GeneORM,
    Transcript as TranscriptORM,
    Translation as TranslationORM,
    Meta as MetaCORM,
    AltAllele as AltAlleleCORM,
    t_alt_allele_attrib as AltAlleleAttribORM,
    ObjectXref as ObjectXrefCORM,
    Xref as XrefCORM,
    ExternalDb as ExternalDbORM,
    SeqRegionAttrib as SeqRegionAttribORM,
    AttribType as AttribTypeORM
)

from ensembl.xrefs.xref_update_db_model import (
    GeneTranscriptTranslation as GeneTranscriptTranslationORM,
    GeneStableId as GeneStableIdORM,
    TranscriptStableId as TranscriptStableIdORM,
    TranslationStableId as TranslationStableIdORM,
    AltAllele as AltAlleleUORM
)

from ensembl.production.xrefs.mappers.BasicMapper import BasicMapper

class CoreInfo(BasicMapper):
    def __init__(self, mapper: BasicMapper) -> None:
        self.xref(mapper.xref())
        self.core(mapper.core())
        mapper.set_up_logging()

    def get_core_data(self) -> None:
        # Load table gene_transcript_translation
        self.load_gene_transcript_translation()

        # Load tables xxx_stable_id
        self.load_stable_ids()

        self.update_process_status("core_data_loaded")

    def load_gene_transcript_translation(self) -> None:
        with self.xref().connect() as xref_dbi, self.core().connect() as core_dbi:
            query = select(
                TranscriptORM.gene_id,
                TranscriptORM.transcript_id,
                TranslationORM.translation_id,
            ).outerjoin(
                TranslationORM, TranscriptORM.transcript_id == TranslationORM.transcript_id
            )
            for row in core_dbi.execute(query).mappings().all():
                xref_dbi.execute(
                    insert(GeneTranscriptTranslationORM)
                    .values(
                        gene_id=row.gene_id,
                        transcript_id=row.transcript_id,
                        translation_id=row.translation_id,
                    )
                    .prefix_with("IGNORE")
                )

    def load_stable_ids(self) -> None:
        with self.xref().connect() as xref_dbi, self.core().connect() as core_dbi:
            core_tables = {
                "gene": GeneORM,
                "transcript": TranscriptORM,
                "translation": TranslationORM,
            }
            xref_tables = {
                "gene": GeneStableIdORM,
                "transcript": TranscriptStableIdORM,
                "translation": TranslationStableIdORM,
            }

            for table in ["gene", "transcript", "translation"]:
                column = getattr(core_tables[table], f"{table}_id")
                core_query = select(
                    column.label("internal_id"), core_tables[table].stable_id
                )
                if table == "transcript":
                    core_query = core_query.add_columns(TranscriptORM.biotype)

                count = 0
                for row in core_dbi.execute(core_query).mappings().all():
                    xref_query = (
                        insert(xref_tables[table])
                        .values(internal_id=row.internal_id, stable_id=row.stable_id)
                        .prefix_with("IGNORE")
                    )
                    if table == "transcript":
                        xref_query = xref_query.values(biotype=row.biotype)
                    xref_dbi.execute(xref_query)

                    count += 1

                logging.info(f"{count} {table}s loaded from core DB")

    def get_alt_alleles(self) -> None:
        with self.xref().connect() as xref_dbi, self.core().connect() as core_dbi:
            alt_allele_list = self.fetch_all_alt_alleles(core_dbi)

            count = len(alt_allele_list)
            max_alt_id = 0

            if count > 0:
                xref_dbi.execute(delete(AltAlleleUORM))

                alt_added, num_of_genes = 0, 0

                # Iterate through all alt-allele groups, pushing unique alleles into the xref alt allele table
                # Track the reference gene IDs
                for group_id, group_members in alt_allele_list.items():
                    ref_gene = self.rep_gene_id(group_members)

                    # Representative gene not guaranteed, try to find an alternative best fit
                    if not ref_gene:
                        logging.info("Get alternative reference gene")
                        for gene_id in self.get_all_genes(group_members):
                            query = select(AttribTypeORM.code).where(
                                SeqRegionAttribORM.seq_region_id == GeneORM.seq_region_id,
                                AttribTypeORM.attrib_type_id
                                == SeqRegionAttribORM.attrib_type_id,
                                GeneORM.gene_id == gene_id,
                                AttribTypeORM.code == "non_ref",
                            )
                            result = core_dbi.execute(query)
                            if result.rowcount > 0:
                                continue
                            else:
                                ref_gene = gene_id
                                break

                    if not ref_gene:
                        logging.warning(
                            f"Tried very hard but failed to select a representative gene for alt-allele-group {group_id}"
                        )
                        continue

                    others = [member[0] for member in group_members if member[0] != ref_gene]

                    xref_dbi.execute(
                        insert(AltAlleleUORM).values(
                            alt_allele_id=group_id, gene_id=ref_gene, is_reference=1
                        )
                    )
                    num_of_genes += 1
                    alt_added += 1
                    for gene_id in others:
                        xref_dbi.execute(
                            insert(AltAlleleUORM).values(
                                alt_allele_id=group_id, gene_id=gene_id, is_reference=0
                            )
                        )
                        num_of_genes += 1

                    if group_id > max_alt_id:
                        max_alt_id = group_id

                logging.info(f"{alt_added} alleles found containing {num_of_genes} genes")
            else:
                logging.info("No alt alleles found for this species")

            # LRGs added as alt_alleles in the XREF system but never added to core
            count = 0
            old_count, new_count, lrg_count = 0, 0, 0

            query = (
                select(ObjectXrefCORM.ensembl_id, GeneORM.gene_id)
                .where(
                    XrefCORM.xref_id == ObjectXrefCORM.xref_id,
                    ExternalDbORM.external_db_id == XrefCORM.external_db_id,
                    ObjectXrefCORM.ensembl_object_type == "Gene",
                    XrefCORM.display_label == GeneORM.stable_id,
                )
                .filter(ExternalDbORM.db_name.like("Ens_Hs_gene"))
            )
            for row in core_dbi.execute(query).mappings().all():
                # If the core gene is already in an alt_allele set then use that alt_id for the LRG gene only
                # Else use a new one and add both core and LRG
                group_id = self.fetch_group_id_by_gene_id(row.gene_id, core_dbi)
                if group_id:
                    xref_dbi.execute(
                        insert(AltAlleleUORM).values(
                            alt_allele_id=group_id, gene_id=row.ensembl_id, is_reference=0
                        )
                    )
                    old_count += 1
                else:
                    group_id = self.fetch_group_id_by_gene_id(row.ensembl_id, core_dbi)
                    if group_id:
                        xref_dbi.execute(
                            insert(AltAlleleUORM).values(
                                alt_allele_id=group_id,
                                gene_id=row.ensembl_id,
                                is_reference=1,
                            )
                        )
                        lrg_count += 1
                        logging.info(f"LRG peculiarity\t{row.gene_id}\t{row.ensembl_id}")
                    else:
                        max_alt_id += 1
                        xref_dbi.execute(
                            insert(AltAlleleUORM).values(
                                alt_allele_id=max_alt_id,
                                gene_id=row.ensembl_id,
                                is_reference=0,
                            )
                        )
                        xref_dbi.execute(
                            insert(AltAlleleUORM).values(
                                alt_allele_id=max_alt_id,
                                gene_id=row.gene_id,
                                is_reference=1,
                            )
                        )
                        new_count += 1
                count += 1

            if count:
                logging.info(
                    f"Added {count} alt_alleles for the LRGs. {old_count} added to previous alt_alleles and {new_count} new ones"
                )
                logging.info(f"LRG problem count = {lrg_count}")

            self.update_process_status("alt_alleles_added")

    def fetch_all_alt_alleles(self, dbi: Connection) -> Dict[int, List[List[Any]]]:
        group_list = {}
        if self.is_multispecies(dbi):  ##### TO DO: handle multiespecies
            raise NotImplementedError(f"Pipeline cannot handle multispecies DBs yet")

        query = select(AltAlleleCORM.alt_allele_group_id).distinct()

        for row in dbi.execute(query).mappings().all():
            group_members = self.fetch_members_by_group_id(row.alt_allele_group_id, dbi)
            group_list[row.alt_allele_group_id] = group_members

        return group_list

    def fetch_members_by_group_id(self, group_id: int, dbi: Connection) -> List[List[Any]]:
        members = []

        query = (
            select(AltAlleleCORM.alt_allele_id, AltAlleleCORM.gene_id)
            .where(AltAlleleCORM.alt_allele_group_id == group_id)
            .order_by(AltAlleleCORM.alt_allele_id)
        )
        for row in dbi.execute(query).mappings().all():
            # Fetch alt_allele attributes
            attrib_list = {}
            query = select(AltAlleleAttribORM.columns.attrib).where(
                AltAlleleAttribORM.columns.alt_allele_id == row.alt_allele_id
            )
            for attrib_row in dbi.execute(query).mappings().all():
                attrib_list[attrib_row.attrib] = 1

            members.append([row.gene_id, attrib_list])

        return members

    def fetch_group_id_by_gene_id(self, gene_id: int, dbi: Connection) -> Optional[int]:
        query = (
            select(AltAlleleCORM.alt_allele_group_id)
            .where(AltAlleleCORM.gene_id == gene_id)
            .order_by(AltAlleleCORM.alt_allele_group_id)
        )
        group_list = dbi.execute(query).mappings().all()

        if group_list:
            return group_list[0].alt_allele_group_id

        return None

    def is_multispecies(self, dbi: Connection) -> bool:
        result = dbi.execute(
            select(MetaCORM.meta_value).where(
                MetaCORM.meta_key == "species.taxonomy_id"
            )
        )

        return result.rowcount > 1

    def rep_gene_id(self, group: List[List[Any]]) -> Optional[int]:
        for allele in group:
            gene_id = allele[0]
            allele_type = allele[1]

            if allele_type.get("IS_REPRESENTATIVE"):
                return gene_id

        logging.warning(
            "No representative allele currently set for this AltAlleleGroup"
        )
        return None

    def get_all_genes(self, group: List[List[Any]]) -> List[int]:
        return sorted(allele[0] for allele in group)
