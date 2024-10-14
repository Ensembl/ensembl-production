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

"""Mapper module for moving xref data onto appriopriate genes."""

from ensembl.production.xrefs.mappers.BasicMapper import *


class ProcessMoves(BasicMapper):
    def __init__(self, mapper: BasicMapper) -> None:
        self.xref(mapper.xref())
        self.core(mapper.core())
        mapper.set_up_logging()

    def biomart_testing(self, verbose: bool) -> None:
        logging.info("Starting biomart testing")

        xref_dbi = self.xref().connect()

        again = 1
        while again:
            again = 0

            last_type, last_count, last_name = None, None, "DEFAULT"

            query = (
                select(
                    ObjectXrefUORM.ensembl_object_type,
                    SourceUORM.name,
                    func.count(ObjectXrefUORM.object_xref_id).label("count"),
                )
                .where(
                    XrefUORM.xref_id == ObjectXrefUORM.xref_id,
                    SourceUORM.source_id == XrefUORM.source_id,
                    ObjectXrefUORM.ox_status == "DUMP_OUT",
                )
                .group_by(SourceUORM.name, ObjectXrefUORM.ensembl_object_type)
            )
            for row in xref_dbi.execute(query).mappings().all():
                if again:
                    break

                if last_name == row.name:
                    again = 1
                    self.biomart_fix(
                        row.name, last_type, row.ensembl_object_type, xref_dbi
                    )

                last_name = row.name
                last_type = row.ensembl_object_type
                last_count = row.count

        if self.unlinked_entries(verbose, xref_dbi):
            raise ValueError("Problems found before source_defined_move")

        xref_dbi.close()

        self.update_process_status("biomart_test_finished")

    def unlinked_entries(self, verbose: bool, dbi: Connection) -> bool:
        failed = False
        xref_id, count = None, None

        self.update_process_status("tests_started")

        # Get count of unlinked master xrefs
        count = dbi.execute(
            select(func.count(DependentXrefUORM.master_xref_id))
            .outerjoin(XrefUORM, XrefUORM.xref_id == DependentXrefUORM.master_xref_id)
            .where(XrefUORM.xref_id == None)
        ).scalar()

        if count:
            failed = True
            logging.error(f"Problem with {count} master xrefs")

            if verbose:
                query = (
                    select(DependentXrefUORM.master_xref_id.distinct())
                    .outerjoin(
                        XrefUORM, XrefUORM.xref_id == DependentXrefUORM.master_xref_id
                    )
                    .where(XrefUORM.xref_id == None)
                    .limit(10)
                )
                for row in dbi.execute(query).mappings().all():
                    logging.error(f"Problem with master xref {row.master_xref_id}")

        # Get count of unlinked dependent xrefs
        count = dbi.execute(
            select(func.count(DependentXrefUORM.dependent_xref_id))
            .outerjoin(
                XrefUORM, XrefUORM.xref_id == DependentXrefUORM.dependent_xref_id
            )
            .where(XrefUORM.xref_id == None)
        ).scalar()

        if count:
            failed = True
            logging.error(f"Problem with {count} dependent xrefs")

            if verbose:
                query = (
                    select(DependentXrefUORM.dependent_xref_id.distinct())
                    .outerjoin(
                        XrefUORM,
                        XrefUORM.xref_id == DependentXrefUORM.dependent_xref_id,
                    )
                    .where(XrefUORM.xref_id == None)
                    .limit(10)
                )
                for row in dbi.execute(query).mappings().all():
                    logging.error(
                        f"Problem with dependent xref {row.dependent_xref_id}"
                    )

        # Get count of unlinked primary xrefs
        count = dbi.execute(
            select(func.count(PrimaryXrefORM.xref_id))
            .outerjoin(XrefUORM, XrefUORM.xref_id == PrimaryXrefORM.xref_id)
            .where(XrefUORM.xref_id == None)
        ).scalar()

        if count:
            failed = True
            logging.error(f"Problem with {count} primary xrefs")

            if verbose:
                query = (
                    select(PrimaryXrefORM.xref_id.distinct())
                    .outerjoin(XrefUORM, XrefUORM.xref_id == PrimaryXrefORM.xref_id)
                    .where(XrefUORM.xref_id == None)
                    .limit(10)
                )
                for row in dbi.execute(query).mappings().all():
                    logging.error(f"Problem with primary xref {row.xref_id}")

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

        # Get count of unlinked direct xrefs
        for object_type in ["transcript", "translation", "gene"]:
            direct_table = db_tables[object_type]["direct"]
            count = dbi.execute(
                select(func.count(direct_table.general_xref_id))
                .outerjoin(XrefUORM, XrefUORM.xref_id == direct_table.general_xref_id)
                .where(XrefUORM.xref_id == None)
            ).scalar()

            if count:
                failed = True
                logging.error(f"Problem with {count} {object_type} direct xrefs")

                if verbose:
                    query = (
                        select(direct_table.general_xref_id.distinct())
                        .outerjoin(
                            XrefUORM, XrefUORM.xref_id == direct_table.general_xref_id
                        )
                        .where(XrefUORM.xref_id == None)
                        .limit(10)
                    )
                    for row in dbi.execute(query).mappings().all():
                        logging.error(
                            f"Problem with {object_type} direct xref {row.general_xref_id}"
                        )

        # Get count of unlinked synonyms
        count = dbi.execute(
            select(func.count(SynonymORM.xref_id))
            .outerjoin(XrefUORM, XrefUORM.xref_id == SynonymORM.xref_id)
            .where(XrefUORM.xref_id == None)
        ).scalar()

        if count:
            failed = True
            logging.error(f"Problem with {count} synonyms")

            if verbose:
                query = (
                    select(SynonymORM.xref_id.distinct())
                    .outerjoin(XrefUORM, XrefUORM.xref_id == SynonymORM.xref_id)
                    .where(XrefUORM.xref_id == None)
                    .limit(10)
                )
                for row in dbi.execute(query).mappings().all():
                    logging.error(f"Problem with synonym {row.xref_id}")

        # Get count of unlinked identity object xrefs
        count = dbi.execute(
            select(func.count(IdentityXrefUORM.object_xref_id))
            .outerjoin(
                ObjectXrefUORM,
                ObjectXrefUORM.object_xref_id == IdentityXrefUORM.object_xref_id,
            )
            .where(ObjectXrefUORM.object_xref_id == None)
        ).scalar()

        if count:
            failed = True
            logging.error(f"Problem with {count} object xrefs")

            if verbose:
                query = (
                    select(IdentityXrefUORM.object_xref_id.distinct())
                    .outerjoin(
                        ObjectXrefUORM,
                        ObjectXrefUORM.object_xref_id
                        == IdentityXrefUORM.object_xref_id,
                    )
                    .where(ObjectXrefUORM.object_xref_id == None)
                    .limit(10)
                )
                for row in dbi.execute(query).mappings().all():
                    logging.error(f"Problem with object xref {row.object_xref_id}")

        # Get count of unlinked objects
        for object_type in ["transcript", "translation", "gene"]:
            id_column = getattr(GeneTranscriptTranslationORM, f"{object_type}_id")
            stable_id_table = db_tables[object_type]["stable_id"]

            count = dbi.execute(
                select(func.count(id_column))
                .outerjoin(stable_id_table, stable_id_table.internal_id == id_column)
                .where(stable_id_table.internal_id == None, id_column != None)
            ).scalar()

            if count:
                failed = True
                logging.error(f"Problem with {count} {object_type}_ids")

                if verbose:
                    query = (
                        select(id_column.label("object_id").distinct())
                        .outerjoin(
                            stable_id_table, stable_id_table.internal_id == id_column
                        )
                        .where(stable_id_table.internal_id == None, id_column != None)
                        .limit(10)
                    )
                    for row in dbi.execute(query).mappings().all():
                        logging.error(f"Problem with {object_type}_id {row.object_id}")

        if not failed:
            self.update_process_status("tests_finished")
        else:
            self.update_process_status("tests_failed")

        return failed

    def source_defined_move(self, verbose: bool) -> None:
        xref_dbi = self.xref().connect()

        for source in self.get_gene_specific_list(xref_dbi):
            self.biomart_fix(source, "Translation", "Gene", xref_dbi)
            self.biomart_fix(source, "Transcript", "Gene", xref_dbi)

        if self.unlinked_entries(verbose, xref_dbi):
            raise ValueError("Problems found after source_defined_move")

        xref_dbi.close()

        self.update_process_status("source_level_move_finished")

    def get_gene_specific_list(self, dbi: Connection) -> List[str]:
        sources_list = [
            "DBASS3",
            "DBASS5",
            "EntrezGene",
            "miRBase",
            "RFAM",
            "TRNASCAN_SE",
            "RNAMMER",
            "UniGene",
            "Uniprot_gn",
            "WikiGene",
            "MIM_GENE",
            "MIM_MORBID",
            "HGNC",
            "MGI",
            "ZFIN_ID",
            "FlyBaseName_gene",
            "RGD",
            "SGD_GENE",
            "VGNC",
            "wormbase_gseqname",
            "wormbase_locus",
            "Xenbase",
            "GeneCards",
        ]

        used_list = []
        count = None

        # Check that the sources are used in the database considered
        for source in sources_list:
            count = dbi.execute(
                select(func.count(XrefUORM.xref_id)).where(
                    XrefUORM.source_id == SourceUORM.source_id,
                    SourceUORM.name == source,
                )
            ).scalar()

            if count > 0:
                used_list.append(source)

        return used_list

    def process_alt_alleles(self, verbose: bool) -> None:
        logging.info("Processing alt alleles")

        xref_dbi = self.xref().connect()

        alt_to_ref, ref_to_alts = self.get_alt_allele_hashes(xref_dbi)
        gene_specific_list = self.get_gene_specific_list(xref_dbi)

        move_count, del_identity_xref_count, del_object_xref_count = 0, 0, 0

        for gene_id, ref_gene in alt_to_ref.items():
            # Move the xrefs onto the reference Gene
            query = (
                update(ObjectXrefUORM)
                .where(
                    XrefUORM.source_id == SourceUORM.source_id,
                    ObjectXrefUORM.xref_id == XrefUORM.xref_id,
                    ObjectXrefUORM.ensembl_id == gene_id,
                    ObjectXrefUORM.ensembl_object_type == "Gene",
                    ObjectXrefUORM.ox_status == "DUMP_OUT",
                    SourceUORM.name.in_(gene_specific_list),
                )
                .values(ensembl_id=ref_gene)
                .prefix_with("IGNORE")
            )
            row_count = xref_dbi.execute(query).rowcount
            move_count += row_count

            # Delete the related identity and object xrefs
            query = delete(IdentityXrefUORM).where(
                XrefUORM.source_id == SourceUORM.source_id,
                ObjectXrefUORM.object_xref_id == IdentityXrefUORM.object_xref_id,
                ObjectXrefUORM.xref_id == XrefUORM.xref_id,
                ObjectXrefUORM.ensembl_id == gene_id,
                ObjectXrefUORM.ensembl_object_type == "Gene",
                ObjectXrefUORM.ox_status == "DUMP_OUT",
                SourceUORM.name.in_(gene_specific_list),
            )
            row_count = xref_dbi.execute(query).rowcount
            del_identity_xref_count += row_count

            query = delete(ObjectXrefUORM).where(
                XrefUORM.source_id == SourceUORM.source_id,
                ObjectXrefUORM.xref_id == XrefUORM.xref_id,
                ObjectXrefUORM.ensembl_id == gene_id,
                ObjectXrefUORM.ensembl_object_type == "Gene",
                ObjectXrefUORM.ox_status == "DUMP_OUT",
                SourceUORM.name.in_(gene_specific_list),
            )
            row_count = xref_dbi.execute(query).rowcount
            del_object_xref_count += row_count

        logging.info(
            f"Number of rows: moved = {move_count}, identity_xrefs deleted = {del_identity_xref_count}, object_xrefs deleted = {del_object_xref_count}"
        )

        max_object_xref_id = xref_dbi.execute(
            select(func.max(ObjectXrefUORM.object_xref_id))
        ).scalar()
        max_object_xref_id = int(max_object_xref_id)

        if not max_object_xref_id:
            raise LookupError("Problem getting max object_xref_id")

        added_count, ignored = 0, 0

        # Copy the xref data related to the reference gene onto the alt alleles
        for ref_gene, alts in ref_to_alts.items():
            # Get object and identity xref data related to the reference gene
            query = (
                select(ObjectXrefUORM, IdentityXrefUORM)
                .outerjoin(
                    IdentityXrefUORM,
                    IdentityXrefUORM.object_xref_id == ObjectXrefUORM.object_xref_id,
                )
                .where(
                    XrefUORM.source_id == SourceUORM.source_id,
                    ObjectXrefUORM.xref_id == XrefUORM.xref_id,
                    ObjectXrefUORM.ensembl_id == ref_gene,
                    ObjectXrefUORM.ox_status == "DUMP_OUT",
                    ObjectXrefUORM.ensembl_object_type == "Gene",
                    SourceUORM.name.in_(gene_specific_list),
                )
            )
            for row in xref_dbi.execute(query).mappings().all():
                for alt in alts:
                    max_object_xref_id += 1

                    query = insert(ObjectXrefUORM).values(
                        object_xref_id=max_object_xref_id,
                        ensembl_id=alt,
                        ensembl_object_type=row.ensembl_object_type,
                        xref_id=row.xref_id,
                        linkage_annotation=row.linkage_annotation,
                        linkage_type=row.linkage_type,
                        ox_status=row.ox_status,
                        unused_priority=row.unused_priority,
                        master_xref_id=row.master_xref_id,
                    )
                    row_count = xref_dbi.execute(query).rowcount

                    # Only add identity xref if object_xref was added successfully
                    if row_count:
                        added_count += 1

                        query = insert(IdentityXrefUORM).values(
                            object_xref_id=max_object_xref_id,
                            query_identity=row.query_identity,
                            target_identity=row.target_identity,
                            hit_start=row.hit_start,
                            hit_end=row.hit_end,
                            translation_start=row.translation_start,
                            translation_end=row.translation_end,
                            cigar_line=row.cigar_line,
                            score=row.score,
                            evalue=row.evalue,
                        )
                        xref_dbi.execute(query)
                    else:
                        ignored += 1

        logging.info(f"Added {added_count} new mappings and ignored {ignored}")

        if self.unlinked_entries(verbose, xref_dbi):
            raise ValueError("Problems found after process_alt_alleles")

        xref_dbi.close()

        self.update_process_status("alt_alleles_processed")

    def get_alt_allele_hashes(self, dbi: Connection) -> Tuple[Dict[int, int], Dict[int, List[int]]]:
        alt_to_ref, ref_to_alts = {}, {}
        last_alt_allele, ref_gene = 0, None

        query = select(
            AltAlleleUORM.alt_allele_id,
            AltAlleleUORM.gene_id,
            AltAlleleUORM.is_reference,
        ).order_by(AltAlleleUORM.alt_allele_id, AltAlleleUORM.is_reference.desc())
        for row in dbi.execute(query).mappings().all():
            if row.alt_allele_id != last_alt_allele:
                # Use the first non-reference gene if there is no reference gene in an alt_allele
                ref_gene = row.gene_id
            else:
                alt_to_ref[row.gene_id] = ref_gene
                ref_to_alts.setdefault(ref_gene, []).append(row.gene_id)

            last_alt_allele = row.alt_allele_id

        return alt_to_ref, ref_to_alts
