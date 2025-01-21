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

"""Mapper module for processing sequence matched xref data."""

import os
import re
import logging
from sqlalchemy import select, insert, update, func
from sqlalchemy.engine import Connection

from ensembl.xrefs.xref_update_db_model import (
    TranscriptStableId as TranscriptStableIdORM,
    ObjectXref as ObjectXrefUORM,
    Source as SourceUORM,
    Xref as XrefUORM,
    IdentityXref as IdentityXrefUORM,
    DependentXref as DependentXrefUORM,
    Mapping as MappingORM,
    MappingJobs as MappingJobsORM,
)

from ensembl.production.xrefs.mappers.BasicMapper import BasicMapper

class ProcessMappings(BasicMapper):
    def __init__(self, mapper: BasicMapper) -> None:
        self.xref(mapper.xref())
        self.core(mapper.core())
        mapper.set_up_logging()

    def process_mappings(self) -> None:
        xref_dbi = self.xref().connect()

        query_cutoff, target_cutoff = {}, {}

        # Get cutoffs per mapping job
        mapping_query = select(
            MappingORM.job_id,
            MappingORM.percent_query_cutoff,
            MappingORM.percent_target_cutoff,
        )
        for mapping in xref_dbi.execute(mapping_query).mappings().all():
            query_cutoff[mapping.job_id] = mapping.percent_query_cutoff
            target_cutoff[mapping.job_id] = mapping.percent_target_cutoff

        already_processed_count, processed_count, error_count, empty_count = 0, 0, 0, 0

        # Go through mapping jobs
        mapping_query = select(
            MappingJobsORM.root_dir,
            MappingJobsORM.map_file,
            MappingJobsORM.status,
            MappingJobsORM.out_file,
            MappingJobsORM.err_file,
            MappingJobsORM.array_number,
            MappingJobsORM.job_id,
        )
        for mapping_job in xref_dbi.execute(mapping_query).mappings().all():
            root_dir = mapping_job.root_dir or ""

            err_file = os.path.join(root_dir, mapping_job.err_file)
            out_file = os.path.join(root_dir, mapping_job.out_file)
            map_file = os.path.join(root_dir, mapping_job.map_file)

            update_status = None

            if mapping_job.status == "SUCCESS":
                already_processed_count += 1
                continue

            if os.path.exists(err_file) and os.path.getsize(err_file) > 0:
                error_count += 1

                # Display errors on STDERR
                logging.warning(f"Problem {err_file} is non zero")
                try:
                    with open(err_file) as fh:
                        for line in fh:
                            logging.warning(f"#{line}")
                except Exception as e:
                    logging.debug(
                        f"No error file exists {err_file}???\n Resubmit this job. Error: {e}"
                    )

                if mapping_job.status == "SUBMITTED":
                    update_status = "FAILED"
            else:
                # Process the mapping file
                if os.path.exists(map_file):
                    count = self.process_map_file(
                        map_file,
                        query_cutoff[mapping_job.job_id],
                        target_cutoff[mapping_job.job_id],
                        mapping_job.job_id,
                        mapping_job.array_number,
                        xref_dbi,
                    )
                    if count > 0:
                        processed_count += 1
                        update_status = "SUCCESS"
                    elif count == 0:
                        processed_count += 1
                        empty_count += 1
                        update_status = "SUCCESS"
                    else:
                        error_count += 1
                        update_status = "FAILED"
                else:
                    error_count += 1
                    logging.debug(
                        f"Could not open map file {map_file}???\n Resubmit this job"
                    )
                    update_status = "FAILED"

            # Update mapping job status
            if update_status:
                xref_dbi.execute(
                    update(MappingJobsORM)
                    .where(
                        MappingJobsORM.job_id == mapping_job.job_id,
                        MappingJobsORM.array_number == mapping_job.array_number,
                    )
                    .values(status=update_status)
                )

        logging.info(
            f"Already processed = {already_processed_count}, processed = {processed_count}, errors = {error_count}, empty = {empty_count}"
        )

        xref_dbi.close()

        if not error_count:
            self.update_process_status("mapping_processed")

    def process_map_file(self, map_file: str, query_cutoff: int, target_cutoff: int, job_id: int, array_number: int, dbi: Connection) -> int:
        ensembl_type = "Translation"
        if re.search("dna_", map_file):
            ensembl_type = "Transcript"

        # Get max object xref id
        object_xref_id = dbi.execute(
            select(func.max(ObjectXrefUORM.object_xref_id))
        ).scalar() or 0

        total_lines, last_query_id = 0, 0
        best_match_found = False
        best_identity, best_score = 0, 0
        first = True

        mRNA_biotypes = {
            "protein_coding": 1,
            "TR_C_gene": 1,
            "IG_V_gene": 1,
            "nonsense_mediated_decay": 1,
            "polymorphic_pseudogene": 1,
        }

        try:
            with open(map_file) as mh:
                for line in mh:
                    load_object_xref = False
                    total_lines += 1

                    (
                        label,
                        query_id,
                        target_id,
                        identity,
                        query_length,
                        target_length,
                        query_start,
                        query_end,
                        target_start,
                        target_end,
                        cigar_line,
                        score,
                    ) = line.strip().split(":")

                    # Fix variable types (for integer comparisons)
                    identity = int(identity)
                    score = int(score)
                    query_length = int(query_length)
                    target_length = int(target_length)
                    query_start = int(query_start)
                    target_start = int(target_start)

                    if last_query_id != query_id:
                        best_match_found = False
                        best_score = 0
                        best_identity = 0
                    else:
                        # Ignore mappings with worse identity or score if we already found a good mapping
                        if (
                            (identity < best_identity or score < best_score)
                            and best_match_found
                        ):
                            continue

                    if ensembl_type == "Translation":
                        load_object_xref = True
                    else:
                        # Check if source name is RefSeq_ncRNA or RefSeq_mRNA
                        # If yes check biotype, if ok store object xref
                        source_name = dbi.execute(
                            select(SourceUORM.name)
                            .join(XrefUORM, XrefUORM.source_id == SourceUORM.source_id)
                            .where(XrefUORM.xref_id == query_id)
                        ).scalar()

                        if source_name and (
                            re.search(r"^RefSeq_(m|nc)RNA", source_name)
                            or re.search(r"^miRBase", source_name)
                            or re.search(r"^RFAM", source_name)
                        ):
                            # Make sure mRNA xrefs are matched to protein_coding biotype only
                            biotype = dbi.execute(
                                select(TranscriptStableIdORM.biotype).where(
                                    TranscriptStableIdORM.internal_id == target_id
                                )
                            ).scalar()

                            if re.search(r"^RefSeq_mRNA", source_name) and mRNA_biotypes.get(
                                biotype
                            ):
                                load_object_xref = True
                            if re.search(
                                r"^RefSeq_ncRNA", source_name
                            ) and not mRNA_biotypes.get(biotype):
                                load_object_xref = True
                            if (
                                re.search(r"^miRBase", source_name)
                                or re.search(r"^RFAM", source_name)
                            ) and re.search("RNA", biotype):
                                load_object_xref = True
                        else:
                            load_object_xref = True

                    last_query_id = query_id

                    # Check if found a better match
                    if score > best_score or identity > best_identity:
                        best_score = score
                        best_identity = identity

                    if not load_object_xref:
                        continue
                    else:
                        best_match_found = True

                    if not score:
                        self.update_object_xref_end(job_id, array_number, object_xref_id, dbi)
                        raise ValueError(f"No score on line. Possible file corruption\n{line}")

                    # Calculate percentage identities
                    query_identity = int(100 * identity / query_length)
                    target_identity = int(100 * identity / target_length)

                    # Only keep alignments where both sequences match cutoff
                    status = "DUMP_OUT"
                    if query_identity < query_cutoff or target_identity < target_cutoff:
                        status = "FAILED_CUTOFF"

                    # Add object xref row
                    object_xref_id = self.get_object_xref_id(
                        target_id, query_id, ensembl_type, "SEQUENCE_MATCH", dbi, None, status
                    )
                    if object_xref_id:
                        continue
                    else:
                        try:
                            object_xref_id = self.add_object_xref(
                                target_id,
                                query_id,
                                ensembl_type,
                                "SEQUENCE_MATCH",
                                dbi,
                                None,
                                status,
                            )
                        except:
                            self.update_object_xref_end(
                                job_id, array_number, object_xref_id, dbi
                            )
                            raise IOError(f"Problem adding object_xref row")

                    if first:
                        self.update_object_xref_start(job_id, array_number, object_xref_id, dbi)
                        first = False

                    cigar_line = re.sub(" ", "", cigar_line)
                    cigar_line = re.sub(r"([MDI])(\d+)", r"\2\1", cigar_line)

                    # Add identity xref row
                    try:
                        identity_xref_query = insert(IdentityXrefUORM).values(
                            object_xref_id=object_xref_id,
                            query_identity=query_identity,
                            target_identity=target_identity,
                            hit_start=query_start + 1,
                            hit_end=query_end,
                            translation_start=target_start + 1,
                            translation_end=target_end,
                            cigar_line=cigar_line,
                            score=score,
                        )
                        dbi.execute(identity_xref_query)
                    except:
                        self.update_object_xref_end(job_id, array_number, object_xref_id, dbi)
                        raise IOError(f"Problem loading identity_xref")

                    master_xref_ids = [query_id]
                    for master_xref_id in master_xref_ids:
                        # Get all dependents related to master xref
                        dep_query = select(DependentXrefUORM.dependent_xref_id).where(
                            DependentXrefUORM.master_xref_id == master_xref_id
                        )
                        for dep in dbi.execute(dep_query).mappings().all():
                            # Add dependent object xref
                            dep_object_xref_id = self.get_object_xref_id(
                                target_id,
                                dep.dependent_xref_id,
                                ensembl_type,
                                "DEPENDENT",
                                dbi,
                                master_xref_id,
                                status,
                            )
                            if dep_object_xref_id:
                                continue
                            else:
                                try:
                                    dep_object_xref_id = self.add_object_xref(
                                        target_id,
                                        dep.dependent_xref_id,
                                        ensembl_type,
                                        "DEPENDENT",
                                        dbi,
                                        master_xref_id,
                                        status,
                                    )
                                except:
                                    self.update_object_xref_end(
                                        job_id, array_number, object_xref_id, dbi
                                    )
                                    raise IOError(f"Problem adding dependent object xref row")

                            # Add dependent identity xref
                            dbi.execute(
                                insert(IdentityXrefUORM).values(
                                    object_xref_id=dep_object_xref_id,
                                    query_identity=query_identity,
                                    target_identity=target_identity,
                                )
                            )

                            # Get the dependent dependents just in case
                            master_xref_ids.append(dep.dependent_xref_id)
        except Exception as e:
            logging.debug(f"Could not open map file {map_file}\n Resubmit this job. Error: {e}")
            return -1

        self.update_object_xref_end(job_id, array_number, object_xref_id, dbi)
        return total_lines

    def update_object_xref_end(self, job_id: int, array_number: int, object_xref_id: int, dbi: Connection) -> None:
        dbi.execute(
            update(MappingJobsORM)
            .where(
                MappingJobsORM.job_id == job_id,
                MappingJobsORM.array_number == array_number,
            )
            .values(object_xref_end=object_xref_id)
        )

    def update_object_xref_start(self, job_id: int, array_number: int, object_xref_id: int, dbi: Connection) -> None:
        dbi.execute(
            update(MappingJobsORM)
            .where(
                MappingJobsORM.job_id == job_id,
                MappingJobsORM.array_number == array_number,
            )
            .values(object_xref_start=object_xref_id)
        )
