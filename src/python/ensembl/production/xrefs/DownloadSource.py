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

"""Download module to download xref and version files."""

import logging
from sqlalchemy import select
from sqlalchemy.dialects.mysql import insert
from typing import Optional

from ensembl.xrefs.xref_source_db_model import (
    Source as SourceSORM,
    Version as VersionORM,
)

from ensembl.production.xrefs.Base import Base

class DownloadSource(Base):
    def run(self):
        base_path: str = self.get_param("base_path", {"required": True, "type": str})
        parser: str = self.get_param("parser", {"required": True, "type": str})
        name: str = self.get_param("name", {"required": True, "type": str})
        priority: int = self.get_param("priority", {"required": True, "type": int})
        source_db_url: str = self.get_param("source_db_url", {"required": True, "type": str})
        file: str = self.get_param("file", {"required": True, "type": str})
        skip_download: bool = self.get_param("skip_download", {"required": True, "type": bool})
        db: Optional[str] = self.get_param("db", {"type": str})
        version_file: Optional[str] = self.get_param("version_file", {"type": str})
        rel_number: Optional[str] = self.get_param("rel_number", {"type": str})
        catalog: Optional[str] = self.get_param("catalog", {"type": str})

        logging.info(f"DownloadSource starting for source {name}")

        # Download the main xref file
        extra_args = {
            "skip_download_if_file_present": skip_download,
            "db": db
        }
        if rel_number and catalog:
            extra_args.update({"rel_number": rel_number, "catalog": catalog})
        file_path = self.download_file(file, base_path, name, extra_args)

        # Download the version file
        version_path = None
        if version_file:
            extra_args["release"] = "version"
            version_path = self.download_file(version_file, base_path, name, extra_args)

        # Update source db
        db_engine = self.get_db_engine(source_db_url)
        with db_engine.connect() as dbi:
            dbi.execute(
                insert(SourceSORM)
                .values(name=name, parser=parser)
                .on_duplicate_key_update(parser=parser)
            )
            source_id = dbi.execute(
                select(SourceSORM.source_id).where(SourceSORM.name == name)
            ).scalar()

            dbi.execute(
                insert(VersionORM)
                .values(
                    source_id=source_id,
                    file_path=file_path,
                    db=db,
                    priority=priority,
                    revision=version_path,
                )
                .on_duplicate_key_update(revision=version_path)
            )
