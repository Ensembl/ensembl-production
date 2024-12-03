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

"""Parser module for RFAM source."""

import logging
import os
import re
import wget # type: ignore
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import urlparse
from sqlalchemy import and_, select
from sqlalchemy.engine import Connection
from sqlalchemy.engine.url import URL

from ensembl.core.models import (
    Analysis as AnalysisORM,
    Transcript as TranscriptORM,
    ExonTranscript as ExonTranscriptORM,
    SupportingFeature as SupportingFeatureORM,
    DnaAlignFeature as DnaAlignFeatureORM,
)

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class RFAMParser(BaseParser):
    ACCESSION_PATTERN = re.compile(r"^#=GF\sAC\s+(\w+)", re.MULTILINE)
    LABEL_PATTERN = re.compile(r"^#=GF\sID\s+([^\n]+)", re.MULTILINE)
    DESCRIPTION_PATTERN = re.compile(r"^#=GF\sDE\s+([^\n]+)", re.MULTILINE)

    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        species_name = args.get("species_name")
        xref_file = args.get("file")
        db_url = args.get("extra_db_url")
        ensembl_release = args.get("ensembl_release")
        xref_dbi = args.get("xref_dbi")
        verbose = args.get("verbose", False)

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        # Extract db connection parameters from file
        wget_url, db_user, db_host, db_port, db_name, db_pass = self.extract_params_from_string(
            xref_file, ["wget", "user", "host", "port", "dbname", "pass"]
        )
        db_user = db_user or "ensro"
        db_port = db_port or "3306"

        # Get the species name(s)
        species_id_to_names = self.species_id_to_names(xref_dbi)
        if species_name:
            species_id_to_names.setdefault(species_id, []).append(species_name)

        if not species_id_to_names.get(species_id):
            return 0, "Skipped. Could not find species ID to name mapping"

        species_name = species_id_to_names[species_id][0]

        # Connect to the appropriate rfam db
        rfam_db_url = self.get_rfam_db_url(db_host, db_user, db_pass, db_port, db_name, db_url, species_name, ensembl_release, verbose)
        if not rfam_db_url:
            raise AttributeError("Could not find RFAM DB.")
        if verbose:
            logging.info(f"Found RFAM DB: {rfam_db_url}")

        # Download file through wget if url present
        if wget_url:
            xref_file = self.download_file(wget_url, xref_file)

        # Add xrefs
        xref_count, direct_count = self.process_lines(xref_file, rfam_db_url, source_id, species_id, xref_dbi)

        result_message = f"Added {xref_count} RFAM xrefs and {direct_count} direct xrefs"
        return 0, result_message

    def get_rfam_db_url(self, db_host: str, db_user: str, db_pass: str, db_port: str, db_name: str, db_url: str, species_name: str, ensembl_release: str, verbose: bool) -> Any:
        if db_host:
            return URL.create("mysql", db_user, db_pass, db_host, db_port, db_name)
        elif db_url:
            return db_url
        else:
            if verbose:
                logging.info("Looking for db in mysql-ens-sta-1")
            registry = "ensro@mysql-ens-sta-1:4519"
            return self.get_db_from_registry(species_name, "core", ensembl_release, registry)

    def get_rfam_transcript_stable_ids(self, rfam_db_url: Any) -> Dict[str, List[str]]:
        db_engine = self.get_db_engine(rfam_db_url)
        with db_engine.connect() as rfam_dbi:
            query = (
                select(
                    TranscriptORM.stable_id.distinct(),
                    DnaAlignFeatureORM.hit_name,
                    AnalysisORM.analysis_id,
                )
                .join(
                    TranscriptORM,
                    and_(
                        TranscriptORM.analysis_id == AnalysisORM.analysis_id,
                        AnalysisORM.logic_name.like("ncrna%"),
                        TranscriptORM.biotype != "miRNA",
                    ),
                )
                .join(
                    ExonTranscriptORM,
                    ExonTranscriptORM.transcript_id == TranscriptORM.transcript_id,
                )
                .join(
                    SupportingFeatureORM,
                    and_(
                        SupportingFeatureORM.exon_id == ExonTranscriptORM.exon_id,
                        SupportingFeatureORM.feature_type == "dna_align_feature",
                    ),
                )
                .join(
                    DnaAlignFeatureORM,
                    DnaAlignFeatureORM.dna_align_feature_id == SupportingFeatureORM.feature_id,
                )
                .order_by(DnaAlignFeatureORM.hit_name)
            )
            result = rfam_dbi.execute(query).mappings().all()

        # Create a dict with RFAM accessions as keys and value is an array of ensembl transcript stable_ids
        rfam_transcript_stable_ids = {}
        for row in result:
            match = re.search(r"^(RF\d+)", row.hit_name)
            if match:
                rfam_id = match.group(1)
                rfam_transcript_stable_ids.setdefault(rfam_id, []).append(row.stable_id)

        return rfam_transcript_stable_ids

    def download_file(self, wget_url: str, rfam_file: str) -> str:
        uri = urlparse(wget_url)
        rfam_file = os.path.join(os.path.dirname(rfam_file), os.path.basename(uri.path))
        wget.download(wget_url, rfam_file)

        return rfam_file

    def process_lines(self, xref_file: str, rfam_db_url: Any, source_id: int, species_id: int, xref_dbi: Connection) -> Tuple[int, int]:
        xref_count, direct_count = 0, 0

        # Get data from rfam db
        rfam_transcript_stable_ids = self.get_rfam_transcript_stable_ids(rfam_db_url)

        for section in self.get_file_sections(xref_file, "//\n", "utf-8"):
            entry = "".join(section)

            # Extract data from entry
            accession, label, description = self.extract_entry_data(entry)

            if accession and rfam_transcript_stable_ids.get(accession):
                print("accession in dict")
                xref_id = self.add_xref(
                    {
                        "accession": accession,
                        "version": 0,
                        "label": label or accession,
                        "description": description,
                        "source_id": source_id,
                        "species_id": species_id,
                        "info_type": "DIRECT",
                    },
                    xref_dbi,
                )
                xref_count += 1

                for stable_id in rfam_transcript_stable_ids[accession]:
                    self.add_direct_xref(xref_id, stable_id, "Transcript", "", xref_dbi)
                    direct_count += 1

        return xref_count, direct_count

    def extract_entry_data(self, entry: str) -> Tuple[Optional[str], Optional[str], Optional[str]]:
        accession = self.extract_pattern(entry, self.ACCESSION_PATTERN)
        label = self.extract_pattern(entry, self.LABEL_PATTERN)
        description = self.extract_pattern(entry, self.DESCRIPTION_PATTERN)

        return accession, label, description

    def extract_pattern(self, text: str, pattern: re.Pattern) -> Optional[str]:
        match = pattern.search(text)
        return match.group(1) if match else None
