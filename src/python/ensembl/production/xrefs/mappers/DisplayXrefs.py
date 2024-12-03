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

"""Mapper module for setting display xrefs in the core DB."""

import logging
import re
from datetime import datetime
from typing import Dict, List, Tuple
from sqlalchemy import select, insert, update, delete, case, desc, func, aliased
from sqlalchemy.engine import Connection
from sqlalchemy.sql import Select

from ensembl.core.models import (
    Gene as GeneORM,
    Transcript as TranscriptORM,
    Translation as TranslationORM,
    Meta as MetaCORM,
    ObjectXref as ObjectXrefCORM,
    Xref as XrefCORM,
    ExternalDb as ExternalDbORM,
    ExternalSynonym as ExternalSynonymORM
)

from ensembl.xrefs.xref_update_db_model import (
    GeneTranscriptTranslation as GeneTranscriptTranslationORM,
    GeneStableId as GeneStableIdORM,
    TranscriptStableId as TranscriptStableIdORM,
    ObjectXref as ObjectXrefUORM,
    Source as SourceUORM,
    Xref as XrefUORM,
    IdentityXref as IdentityXrefUORM,
    DependentXref as DependentXrefUORM,
    DisplayXrefPriority as DisplayXrefPriorityORM,
    GeneDescPriority as GeneDescPriorityORM
)

from ensembl.production.xrefs.mappers.BasicMapper import BasicMapper

class DisplayXrefs(BasicMapper):
    def __init__(self, mapper: BasicMapper) -> None:
        self.xref(mapper.xref())
        self.core(mapper.core())
        self.mapper(mapper)
        mapper.set_up_logging()

    def mapper(self, mapper: BasicMapper = None) -> BasicMapper:
        if mapper:
            self._mapper = mapper

        return self._mapper

    def build_display_xrefs(self) -> None:
        logging.info("Processing display xrefs")

        mapper = self.mapper()

        # Set the display xrefs
        set_transcript_display_xrefs = hasattr(mapper, "set_transcript_names")
        if hasattr(mapper, "set_display_xrefs"):
            mapper.set_display_xrefs()
        else:
            self.set_display_xrefs(set_transcript_display_xrefs)

        # Set transcript names
        if set_transcript_display_xrefs:
            mapper.set_transcript_names()
        else:
            self.set_transcript_names()

        self.update_process_status("display_xrefs_done")

        # Set the gene descriptions
        self.set_gene_descriptions()

        # Set the meta timestamp
        self.set_meta_timestamp()

        self.update_process_status("gene_descriptions_done")

    def set_display_xrefs(self, set_transcript_display_xrefs: bool) -> None:
        logging.info("Setting Transcript and Gene display xrefs")

        # Get the xref offset used when adding the xrefs into the core DB
        xref_offset = int(self.get_meta_value("xref_offset"))
        logging.info(f"Using xref offset of {xref_offset}")

        xref_dbi = self.xref().connect()
        core_dbi = self.core().connect()
        mapper = self.mapper()

        # Reset transcript display xrefs if required
        if set_transcript_display_xrefs:
            core_dbi.execute(
                update(TranscriptORM)
                .values(display_xref_id=None)
                .where(TranscriptORM.biotype != "LRG_gene")
            )

        for object_type in ["Gene", "Transcript"]:
            if object_type == "Transcript" and not set_transcript_display_xrefs:
                continue

            # Get name source priorities and ignore queries
            method = f"{object_type.lower()}_display_xref_sources"
            precedence_list, ignore = getattr(mapper, method)() if hasattr(mapper, method) else getattr(self, method)()

            # Add the priorities into the DB
            logging.info(f"Precedence for {object_type} display xrefs (1- best name)")
            for priority, source_name in enumerate(precedence_list, start=1):
                query = select(SourceUORM.source_id, SourceUORM.name).where(SourceUORM.name.like(source_name))
                for row in xref_dbi.execute(query).mappings().all():
                    xref_dbi.execute(
                        insert(DisplayXrefPriorityORM).values(
                            ensembl_object_type=object_type,
                            source_id=row.source_id,
                            priority=priority,
                        )
                    )
                    logging.info(f"{priority} - {row.name}")

            # Execute ignore queries
            self._apply_ignore(ignore, xref_dbi)

            object_seen = {}
            display_xref_count = 0

            # Build the case statements
            GTTGene = aliased(GeneTranscriptTranslationORM)
            GTTTranscript = aliased(GeneTranscriptTranslationORM)
            GTTTranslation = aliased(GeneTranscriptTranslationORM)
            gene_case_stmt = case(
                [
                    (ObjectXrefUORM.ensembl_object_type == "Gene", GTTGene.gene_id),
                    (ObjectXrefUORM.ensembl_object_type == "Transcript", GTTTranscript.gene_id),
                    (ObjectXrefUORM.ensembl_object_type == "Translation", GTTTranslation.gene_id),
                ],
            ).label("d_gene_id")
            transcript_case_stmt = case(
                [
                    (ObjectXrefUORM.ensembl_object_type == "Gene", GTTGene.transcript_id),
                    (ObjectXrefUORM.ensembl_object_type == "Transcript", GTTTranscript.transcript_id),
                    (ObjectXrefUORM.ensembl_object_type == "Translation", GTTTranslation.transcript_id),
                ],
            ).label("d_transcript_id")

            # Get all relevant xrefs for this object type based on precedence sources
            query = (
                select(
                    gene_case_stmt,
                    transcript_case_stmt,
                    DisplayXrefPriorityORM.priority,
                    XrefUORM.xref_id,
                )
                .join(SourceUORM, SourceUORM.source_id == DisplayXrefPriorityORM.source_id)
                .join(XrefUORM, XrefUORM.source_id == SourceUORM.source_id)
                .join(ObjectXrefUORM, ObjectXrefUORM.xref_id == XrefUORM.xref_id)
                .join(IdentityXrefUORM, IdentityXrefUORM.object_xref_id == ObjectXrefUORM.object_xref_id)
                .outerjoin(GTTGene, GTTGene.gene_id == ObjectXrefUORM.ensembl_id)
                .outerjoin(GTTTranscript, GTTTranscript.transcript_id == ObjectXrefUORM.ensembl_id)
                .outerjoin(GTTTranslation, GTTTranslation.translation_id == ObjectXrefUORM.ensembl_id)
                .where(
                    ObjectXrefUORM.ox_status == "DUMP_OUT",
                    DisplayXrefPriorityORM.ensembl_object_type == object_type,
                )
                .order_by(
                    "d_gene_id",
                    ObjectXrefUORM.ensembl_object_type,
                    DisplayXrefPriorityORM.priority,
                    desc(IdentityXrefUORM.target_identity + IdentityXrefUORM.query_identity),
                    ObjectXrefUORM.unused_priority.desc(),
                    XrefUORM.accession,
                )
            )
            for row in xref_dbi.execute(query).mappings().all():
                object_id = row.d_gene_id if object_type == "Gene" else row.d_transcript_id

                # Update the display xrefs
                if object_id not in object_seen:
                    xref_id = int(row.xref_id)
                    if object_type == "Gene":
                        core_dbi.execute(
                            update(GeneORM)
                            .values(display_xref_id=xref_id + xref_offset)
                            .where(GeneORM.gene_id == object_id, GeneORM.display_xref_id == None)
                        )
                    elif object_type == "Transcript":
                        core_dbi.execute(
                            update(TranscriptORM)
                            .values(display_xref_id=xref_id + xref_offset)
                            .where(TranscriptORM.transcript_id == object_id)
                        )

                    display_xref_count += 1
                    object_seen[object_id] = True

            logging.info(f"Updated {display_xref_count} {object_type} display_xrefs")

        # Reset ignored object xrefs
        xref_dbi.execute(
            update(ObjectXrefUORM)
            .values(ox_status="DUMP_OUT")
            .where(ObjectXrefUORM.ox_status == "NO_DISPLAY")
        )

        # Remove synonyms not linked to display xrefs
        query = (
            select(XrefCORM.xref_id)
            .outerjoin(GeneORM, GeneORM.display_xref_id == XrefCORM.xref_id)
            .where(GeneORM.display_xref_id == None)
        )
        xref_ids = [row[0] for row in core_dbi.execute(query).fetchall()]

        core_dbi.execute(
            delete(ExternalSynonymORM).where(ExternalSynonymORM.xref_id.in_(xref_ids))
        )

        xref_dbi.close()
        core_dbi.close()

    def gene_display_xref_sources(self) -> Tuple[List[str], Dict[str, Select]]:
        sources_list = [
            "VGNC",
            "HGNC",
            "MGI",
            "RGD",
            "ZFIN_ID",
            "Xenbase",
            "RFAM",
            "miRBase",
            "EntrezGene",
            "Uniprot_gn",
        ]
        ignore_queries = {}

        # Ignore EntrezGene labels dependent on predicted RefSeqs
        MasterXref = aliased(XrefUORM)
        DependentXref = aliased(XrefUORM)
        MasterSource = aliased(SourceUORM)
        DependentSource = aliased(SourceUORM)

        query = select(ObjectXrefUORM.object_xref_id.distinct()).where(
            ObjectXrefUORM.xref_id == DependentXrefUORM.dependent_xref_id,
            ObjectXrefUORM.master_xref_id == DependentXrefUORM.master_xref_id,
            DependentXrefUORM.dependent_xref_id == DependentXref.xref_id,
            DependentXrefUORM.master_xref_id == MasterXref.xref_id,
            MasterXref.source_id == MasterSource.source_id,
            DependentXref.source_id == DependentSource.source_id,
            MasterSource.name.like("Refseq%predicted"),
            DependentSource.name.like("EntrezGene"),
            ObjectXrefUORM.ox_status == "DUMP_OUT",
        )
        ignore_queries["EntrezGene"] = query

        # Ignore LOC-prefixed labels
        query = (
            select(ObjectXrefUORM.object_xref_id)
            .join(XrefUORM, XrefUORM.xref_id == ObjectXrefUORM.xref_id)
            .join(SourceUORM, SourceUORM.source_id == XrefUORM.source_id)
            .where(
                ObjectXrefUORM.ox_status == "DUMP_OUT",
                XrefUORM.label.regexp_match("^LOC[[:digit:]]+"),
            )
        )
        ignore_queries["LOC_prefix"] = query

        return sources_list, ignore_queries

    def transcript_display_xref_sources(self) -> Tuple[List[str], Dict[str, Select]]:
        return self.gene_display_xref_sources()

    def _apply_ignore(self, ignore_queries: Dict[str, Select], dbi: Connection) -> None:
        # Set status to NO_DISPLAY for object_xrefs with a display_label that is just numeric
        numeric_label_query = (
            update(ObjectXrefUORM)
            .values(ox_status="NO_DISPLAY")
            .where(
                ObjectXrefUORM.xref_id == XrefUORM.xref_id,
                XrefUORM.source_id == SourceUORM.source_id,
                ObjectXrefUORM.ox_status == "DUMP_OUT",
                XrefUORM.label.regexp_match("^[0-9]+$"),
            )
        )
        dbi.execute(numeric_label_query)

        # Go through ignore queries
        for ignore_type, ignore_query in ignore_queries.items():
            # Set status to NO_DISPLAY for ignore results
            ignore_results = dbi.execute(ignore_query).mappings().all()
            for row in ignore_results:
                dbi.execute(
                    update(ObjectXrefUORM)
                    .values(ox_status="NO_DISPLAY")
                    .where(ObjectXrefUORM.object_xref_id == row.object_xref_id)
                )

    def set_transcript_names(self) -> None:
        logging.info("Assigning transcript names from gene names")

        core_dbi = self.core().connect()

        # Reset transcript display xrefs
        core_dbi.execute(
            update(TranscriptORM)
            .values(display_xref_id=None)
            .where(TranscriptORM.biotype != "LRG_gene")
        )

        # Get the max xref and object_xref IDs
        xref_id = core_dbi.execute(select(func.max(XrefCORM.xref_id))).scalar() or 0
        object_xref_id = core_dbi.execute(select(func.max(ObjectXrefCORM.object_xref_id))).scalar() or 0

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
            ext = 201

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
            transcript_query = (
                select(TranscriptORM.transcript_id)
                .where(TranscriptORM.gene_id == row.gene_id)
                .order_by(TranscriptORM.seq_region_start, TranscriptORM.seq_region_end)
            )
            for transcript_row in core_dbi.execute(transcript_query).mappings().all():
                object_xref_id += 1

                display_label = f"{row.display_label}-{ext}"

                # Check if xref already exists
                insert_xref_id = core_dbi.execute(
                    select(XrefCORM.xref_id).where(
                        XrefCORM.external_db_id == external_db_id,
                        XrefCORM.display_label == display_label,
                        XrefCORM.info_type == "MISC",
                    )
                ).scalar()

                if not insert_xref_id:
                    xref_id += 1
                    info_text = f"via gene {row.dbprimary_acc}"

                    # Insert new xref
                    core_dbi.execute(
                        insert(XrefCORM)
                        .values(
                            xref_id=xref_id,
                            external_db_id=external_db_id,
                            dbprimary_acc=display_label,
                            display_label=display_label,
                            version=0,
                            description=row.description,
                            info_type="MISC",
                            info_text=info_text,
                        )
                        .prefix_with("IGNORE")
                    )

                    insert_xref_id = xref_id

                # Insert object xref
                core_dbi.execute(
                    insert(ObjectXrefCORM).values(
                        object_xref_id=object_xref_id,
                        ensembl_id=transcript_row.transcript_id,
                        ensembl_object_type="Transcript",
                        xref_id=insert_xref_id,
                    )
                )

                # Set transcript display xref
                core_dbi.execute(
                    update(TranscriptORM)
                    .values(display_xref_id=insert_xref_id)
                    .where(TranscriptORM.transcript_id == transcript_row.transcript_id)
                )

                ext += 1

        # Delete object xrefs with no matching xref
        delete_query = (
            select(ObjectXrefCORM.object_xref_id)
            .outerjoin(XrefCORM, XrefCORM.xref_id == ObjectXrefCORM.xref_id)
            .where(XrefCORM.xref_id == None)
        )
        object_xref_ids = [row[0] for row in core_dbi.execute(delete_query).fetchall()]

        core_dbi.execute(
            delete(ObjectXrefCORM).where(
                ObjectXrefCORM.object_xref_id.in_(object_xref_ids)
            )
        )

        core_dbi.close()

    def set_gene_descriptions(self) -> None:
        logging.info("Setting gene descriptions")

        xref_dbi = self.xref().connect()
        core_dbi = self.core().connect()
        mapper = self.mapper()

        # Reset the gene descriptions
        core_dbi.execute(update(GeneORM).values(description=None))

        # Get source ID to external names mappings
        source_id_to_external_name, name_to_source_id = self.get_external_name_mappings(core_dbi, xref_dbi)

        # Get description source priorities and ignore queries
        precedence_list, ignore = (
            mapper.gene_description_sources()
            if hasattr(mapper, "gene_description_sources")
            else self.gene_description_sources()
        )

        # Get description regular expressions
        reg_exps = (
            mapper.gene_description_filter_regexps()
            if hasattr(mapper, "gene_description_filter_regexps")
            else self.gene_description_filter_regexps()
        )

        # Add the description priorities into the DB
        logging.info("Precedence for Gene descriptions (1- best description)")
        for priority, source_name in enumerate(precedence_list, start=1):
            for row in xref_dbi.execute(
                select(SourceUORM.source_id, SourceUORM.name).where(
                    SourceUORM.name.like(source_name)
                )
            ).mappings().all():
                xref_dbi.execute(
                    insert(GeneDescPriorityORM)
                    .values(source_id=row.source_id, priority=priority)
                    .prefix_with("IGNORE")
                )
                logging.info(f"{priority} - {row.name}")

        # Execute ignore queries
        if ignore:
            self._apply_ignore(ignore, xref_dbi)

        no_source_name_in_desc = {}
        if hasattr(mapper, "no_source_label_list"):
            for source_name in mapper.no_source_label_list():
                source_id = name_to_source_id.get(source_name)
                if source_id:
                    logging.info(
                        f"Source '{source_name}' will not have [Source:...] info in description"
                    )
                    no_source_name_in_desc[source_id] = True

        gene_desc_updated = {}

        # Build the case statement
        GTTGene = aliased(GeneTranscriptTranslationORM)
        GTTTranscript = aliased(GeneTranscriptTranslationORM)
        GTTTranslation = aliased(GeneTranscriptTranslationORM)
        gene_case_stmt = case(
            [
                (ObjectXrefUORM.ensembl_object_type == "Gene", GTTGene.gene_id),
                (ObjectXrefUORM.ensembl_object_type == "Transcript", GTTTranscript.gene_id),
                (ObjectXrefUORM.ensembl_object_type == "Translation", GTTTranslation.gene_id),
            ],
        ).label("d_gene_id")

        # Get all relevant xrefs for this object type based on precedence sources
        query = (
            select(
                gene_case_stmt,
                XrefUORM.description,
                SourceUORM.source_id,
                XrefUORM.accession,
                GeneDescPriorityORM.priority,
            )
            .join(SourceUORM, SourceUORM.source_id == GeneDescPriorityORM.source_id)
            .join(XrefUORM, XrefUORM.source_id == SourceUORM.source_id)
            .join(ObjectXrefUORM, ObjectXrefUORM.xref_id == XrefUORM.xref_id)
            .join(IdentityXrefUORM, IdentityXrefUORM.object_xref_id == ObjectXrefUORM.object_xref_id)
            .outerjoin(GTTGene, GTTGene.gene_id == ObjectXrefUORM.ensembl_id)
            .outerjoin(GTTTranscript, GTTTranscript.transcript_id == ObjectXrefUORM.ensembl_id)
            .outerjoin(GTTTranslation, GTTTranslation.translation_id == ObjectXrefUORM.ensembl_id)
            .where(ObjectXrefUORM.ox_status == "DUMP_OUT")
            .order_by(
                "d_gene_id",
                ObjectXrefUORM.ensembl_object_type,
                GeneDescPriorityORM.priority,
                desc(IdentityXrefUORM.target_identity + IdentityXrefUORM.query_identity),
            )
        )
        for row in xref_dbi.execute(query).mappings().all():
            if row.d_gene_id in gene_desc_updated:
                continue

            if row.description:
                # Apply regular expressions to description
                filtered_description = self.filter_by_regexp(row.description, reg_exps)
                if filtered_description:
                    if row.source_id not in no_source_name_in_desc:
                        source_name = source_id_to_external_name.get(row.source_id)
                        filtered_description += f" [Source:{source_name};Acc:{row.accession}]"

                    # Update the gene description
                    core_dbi.execute(
                        update(GeneORM)
                        .values(description=filtered_description)
                        .where(GeneORM.gene_id == row.d_gene_id, GeneORM.description == None)
                    )

                    gene_desc_updated[row.d_gene_id] = True

        logging.info(f"{len(gene_desc_updated)} gene descriptions added")

        # Reset ignored object xrefs
        xref_dbi.execute(
            update(ObjectXrefUORM)
            .values(ox_status="DUMP_OUT")
            .where(ObjectXrefUORM.ox_status == "NO_DISPLAY")
        )

        xref_dbi.close()
        core_dbi.close()

    def get_external_name_mappings(self, core_dbi: Connection, xref_dbi: Connection) -> Tuple[Dict[int, str], Dict[str, int]]:
        # Get external display names
        external_name_to_display_name = {
            row.db_name: row.db_display_name
            for row in core_dbi.execute(
                select(
                    ExternalDbORM.external_db_id,
                    ExternalDbORM.db_name,
                    ExternalDbORM.db_display_name,
                )
            ).mappings().all()
        }

        # Get sources for available xrefs
        source_id_to_external_name, source_name_to_source_id = {}, {}
        query = (
            select(SourceUORM.source_id, SourceUORM.name)
            .where(SourceUORM.source_id == XrefUORM.source_id)
            .group_by(SourceUORM.source_id)
        )
        for row in xref_dbi.execute(query).mappings().all():
            if external_name_to_display_name.get(row.name):
                source_id_to_external_name[row.source_id] = external_name_to_display_name[row.name]
                source_name_to_source_id[row.name] = row.source_id
            elif re.search(r"notransfer$", row.name):
                logging.info(f"Ignoring notransfer source '{row.name}'")
            else:
                raise LookupError(f"Could not find {row.name} in external_db table")

        return source_id_to_external_name, source_name_to_source_id

    def gene_description_sources(self) -> Tuple[List[str], Dict[str, Select]]:
        return self.gene_display_xref_sources()

    def gene_description_filter_regexps(self) -> List[str]:
        regex = [
            r"[0-9A-Z]{10}RIK PROTEIN[ \.]",
            r"\(?[0-9A-Z]{10}RIK PROTEIN\)?[ \.]",
            r"^BA\S+\s+\(NOVEL PROTEIN\)\.?",
            r"^BC\d+\_\d+\.?",
            r"CDNA SEQUENCE\s?,? [A-Z]+\d+[ \.;]",
            r"^CGI\-\d+ PROTEIN\.?\;?",
            r"^CHROMOSOME\s+\d+\s+OPEN\s+READING\s+FRAME\s+\d+\.?.*",
            r"CLONE MGC:\d+[ \.;]",
            r"^\(CLONE REM\d+\) ORF \(FRAGMENT\)\.*",
            r"\(CLONE \S+\)\s+",
            r"^DJ\S+\s+\(NOVEL PROTEIN\)\.?",
            r"^DKFZP[A-Z0-9]+\s+PROTEIN[\.;]?.*",
            r"DNA SEGMENT, CHR.*",
            r"EST [A-Z]+\d+[ \.;]",
            r"EXPRESSED SEQUENCE [A-Z]+\d+[ \.;]",
            r"^FKSG\d+\.?.*",
            r"^FLJ\d+\s+PROTEIN.*",
            r"^HSPC\d+.*",
            r"^HSPC\d+\s+PROTEIN\.?.*",
            r"HYPOTHETICAL PROTEIN,",
            r"HYPOTHETICAL PROTEIN \S+[\.;]",
            r"^\(*HYPOTHETICAL\s+.*",
            r"\(*HYPOTHETICAL\s+.*",
            r"^KIAA\d+\s+GENE\s+PRODUCT\.?.*",
            r"^KIAA\d+\s+PROTEIN\.?.*",
            r"^LOC\d+\s*(PROTEIN)?\.?",
            r" MGC:\s*\d+[ \.;]",
            r"MGC:\s*\d+[ \.;]",
            r"^ORF.*",
            r"^ORF\s*\d+\s+PROTEIN\.*",
            r"^PRED\d+\s+PROTEIN.*",
            r"^PRO\d+\.?.*",
            r"^PRO\d+\s+PROTEIN\.?.*",
            r"^PROTEIN C\d+ORF\d+\.*",
            r"PROTEIN KIAA\d+[ \.].*",
            r"PROTEIN \S+ HOMOLOG\.?",
            r"^Putative uncharacterized protein.*",
            r"R\d{5}_\d[ \.,].*",
            r"RIKEN CDNA [0-9A-Z]{10}[ \.;]",
            r"RIKEN CDNA [0-9A-Z]{10}[ \.]",
            r".*RIKEN FULL-LENGTH ENRICHED LIBRARY.*",
            r".*RIKEN FULL-LENGTH ENRICHED LIBRARY.*PRODUCT:",
            r"^\s*\(\d*\)\s*[ \.]$",
            r"^\s*\(\d*\)\s*[ \.]$",
            r"^\s*\(?FRAGMENT\)?\.?\s*$",
            r"^\s*\(FRAGMENT\)\.?\s*$",
            r"\s*\(?GENE\)?\.?;?",
            r"^\s*\(?GENE\)?\.?;?\s*$",
            r"^\s*\(?GENE\)?\.?\s*$",
            r"SIMILAR TO GENBANK ACCESSION NUMBER\s+\S+",
            r"^SIMILAR TO GENE.*",
            r"^SIMILAR TO HYPOTHETICAL.*",
            r"^SIMILAR TO (KIAA|LOC).*",
            r"SIMILAR TO (KIAA|LOC|RIKEN).*",
            r"^SIMILAR TO PUTATIVE[ \.]",
            r"SIMILAR TO PUTATIVE[ \.]",
            r"^SIMILAR TO\s+$",
            r"SIMILAR TO\s+$",
            r"\s*\(?PRECURSOR\)?\.?;?",
            r"^\s*\(?PROTEIN\)?\.?\s*$",
            r"^\s+\(?\s*$",
            r"^\s*\(\s*\)\s*$",
            r"^UNKNOWN\s+.*",
            r"^WUGSC:H_.*",
            r"^WUGSC:.*\s+PROTEIN\.?.*",
        ]

        return regex

    def filter_by_regexp(self, string: str, regular_expressions: List[str]) -> str:
        for regex in regular_expressions:
            string = re.sub(regex, "", string, flags=re.IGNORECASE)

        return string

    def set_meta_timestamp(self) -> None:
        logging.info("Setting meta timestamp for xrefs")
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        with self.core().connect() as dbi:
            # Delete existing xref timestamp
            dbi.execute(delete(MetaCORM).where(MetaCORM.meta_key == "xref.timestamp"))

            # Insert new xref timestamp
            dbi.execute(
                insert(MetaCORM).values(meta_key="xref.timestamp", meta_value=now)
            )

        logging.info(f"Meta timestamp set to {now}")

    def set_display_xrefs_from_stable_table(self) -> None:
        logging.info("Setting Transcript and Gene display xrefs using stable IDs")

        # Get the xref offset used when adding the xrefs into the core DB
        xref_offset = int(self.get_meta_value("xref_offset"))
        logging.info(f"Using xref offset of {xref_offset}")

        xref_dbi = self.xref().connect()
        core_dbi = self.core().connect()

        # Reset gene and transcript display xrefs
        core_dbi.execute(update(GeneORM).values(display_xref_id=None))
        core_dbi.execute(update(TranscriptORM).values(display_xref_id=None))

        # Remove descriptions with 'Source' field
        core_dbi.execute(
            update(GeneORM)
            .values(description=None)
            .where(GeneORM.description.like("%[Source:%]%"))
        )

        # Get source ID to external names mappings
        source_id_to_external_name, name_to_source_id = self.get_external_name_mappings(core_dbi, xref_dbi)

        gene_count = 0

        # Set gene names and descriptions
        query = select(
            GeneStableIdORM.internal_id,
            GeneStableIdORM.display_xref_id,
            XrefUORM.description,
            XrefUORM.source_id,
            XrefUORM.accession,
        ).where(GeneStableIdORM.display_xref_id == XrefUORM.xref_id)
        for row in xref_dbi.execute(query).mappings().all():
            xref_id = int(row.display_xref_id)

            # Set display xref ID
            core_dbi.execute(
                update(GeneORM)
                .values(display_xref_id=(xref_id + xref_offset))
                .where(GeneORM.gene_id == row.internal_id)
            )

            # Set description
            if row.description:
                description = f"{row.description} [Source:{source_id_to_external_name[row.source_id]};Acc:{row.accession}]"
                core_dbi.execute(
                    update(GeneORM)
                    .values(description=description)
                    .where(GeneORM.gene_id == row.internal_id)
                )

                xref_dbi.execute(
                    update(GeneStableIdORM)
                    .values(desc_set=1)
                    .where(GeneStableIdORM.internal_id == row.internal_id)
                )
                gene_count += 1

        logging.info(f"{gene_count} gene descriptions added")

        # Set transcript names and descriptions
        query = select(
            TranscriptStableIdORM.internal_id, TranscriptStableIdORM.display_xref_id
        )
        for row in xref_dbi.execute(query).mappings().all():
            xref_id = int(row.display_xref_id)

            if xref_id:
                # Set display xref ID
                core_dbi.execute(
                    update(TranscriptORM)
                    .values(display_xref_id=(xref_id + xref_offset))
                    .where(TranscriptORM.transcript_id == row.internal_id)
                )

        # Clean up synonyms linked to xrefs which are not display xrefs
        query = (
            select(ExternalSynonymORM)
            .outerjoin(GeneORM, GeneORM.display_xref_id == XrefCORM.xref_id)
            .where(
                ExternalSynonymORM.xref_id == XrefCORM.xref_id,
                GeneORM.display_xref_id == None,
            )
        )
        for row in core_dbi.execute(query).mappings().all():
            core_dbi.execute(
                delete(ExternalSynonymORM).where(
                    ExternalSynonymORM.xref_id == row.xref_id,
                    ExternalSynonymORM.synonym == row.synonym,
                )
            )

        xref_dbi.close()
        core_dbi.close()
