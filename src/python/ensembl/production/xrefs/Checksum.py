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

"""Checksum module for the Xref Download pipeline."""

import logging
from sqlalchemy import select, func

from ensembl.xrefs.xref_source_db_model import ChecksumXref as ChecksumXrefSORM

from ensembl.production.xrefs.Base import Base

class Checksum(Base):
    def run(self):
        base_path: str = self.get_param("base_path", {"required": True, "type": str})
        source_db_url: str = self.get_param("source_db_url", {"required": True, "type": str})
        skip_download: bool = self.get_param("skip_download", {"required": True, "type": bool})

        logging.info("Checksum starting with parameters:")
        logging.info(f"\tParam: base_path = {base_path}")
        logging.info(f"\tParam: source_db_url = {source_db_url}")
        logging.info(f"\tParam: skip_download = {skip_download}")

        # Connect to source db
        db_engine = self.get_db_engine(source_db_url)

        # Check if checksums already exist
        table_empty = self.check_table_empty(db_engine) if skip_download else True

        # Load checksums from files into db
        if table_empty:
            self.load_checksum(base_path, source_db_url)
            logging.info("Checksum data loaded")
        else:
            logging.info("Checksum data already exists, skipping loading")

    def check_table_empty(self, db_engine):
        """Check if the checksum table is empty."""
        with db_engine.connect() as dbi:
            query = select(func.count(ChecksumXrefSORM.checksum_xref_id))
            return dbi.execute(query).scalar() == 0
