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

"""Scheduling module to create cleanup jobs for specific xref sources."""

import logging
import os
import re
from typing import Optional
from sqlalchemy import select

from ensembl.xrefs.xref_source_db_model import (
    Source as SourceSORM,
    Version as VersionORM,
)

from ensembl.production.xrefs.Base import Base

class ScheduleCleanup(Base):
    def run(self):
        base_path: str = self.get_param("base_path", {"required": True, "type": str})
        source_db_url: str = self.get_param("source_db_url", {"required": True, "type": str})
        clean_files: Optional[bool] = self.get_param("clean_files", {"type": bool})
        clean_dir: Optional[str] = self.get_param("clean_dir", {"type": str})

        logging.info("ScheduleCleanup starting with parameters:")
        logging.info(f"Param: base_path = {base_path}")
        logging.info(f"Param: source_db_url = {source_db_url}")
        logging.info(f"Param: clean_files = {clean_files}")
        logging.info(f"Param: clean_dir = {clean_dir}")

        # Connect to source db
        db_engine = self.get_db_engine(source_db_url)
        with db_engine.connect() as dbi:
            # Get name and version file for each source
            query = select(SourceSORM.name.distinct(), VersionORM.revision).where(
                SourceSORM.source_id == VersionORM.source_id
            )
            sources = dbi.execute(query).mappings().all()

        cleanup_sources = 0
        for source in sources:
            # Only cleaning RefSeq and UniProt for now
            if not (
                re.search(r"^RefSeq_(dna|peptide)", source.name)
                or re.search(r"^Uniprot", source.name)
            ):
                continue

            # Remove / char from source name to access directory
            clean_name = re.sub(r"\/", "", source.name)

            # Send parameters into cleanup jobs for each source
            source_path = os.path.join(base_path, clean_name)
            if os.path.exists(source_path):
                cleanup_sources += 1
                logging.info(f"Source to cleanup: {source.name}")

                self.write_output(
                    "cleanup_sources",
                    {"name": source.name, "version_file": source.revision},
                )

        if cleanup_sources == 0:
            self.write_output("cleanup_sources", {})
