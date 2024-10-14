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

from ensembl.production.xrefs.Base import *


class DownloadSource(Base):
    def run(self):
        base_path     = self.param_required("base_path", {"type": "str"})
        parser        = self.param_required("parser", {"type": "str"})
        name          = self.param_required("name", {"type": "str"})
        priority      = self.param_required("priority", {"type": "int"})
        source_db_url = self.param_required("source_db_url", {"type": "str"})
        file          = self.param_required("file", {"type": "str"})
        skip_download = self.param_required("skip_download", {"type": "bool"})
        db            = self.param("db", None, {"type": "str"})
        version_file  = self.param("version_file", None, {"type": "str"})
        rel_number    = self.param("rel_number", None, {"type": "str"})
        catalog       = self.param("catalog", None, {"type": "str"})

        logging.info(f"DownloadSource starting for source {name}")

        # Download the main xref file
        extra_args = {}
        extra_args["skip_download_if_file_present"] = skip_download
        extra_args["db"] = db
        if rel_number and catalog:
            extra_args["rel_number"] = rel_number
            extra_args["catalog"] = catalog
        file_name = self.download_file(file, base_path, name, extra_args)

        # Download the version file
        version = ""
        if version_file:
            extra_args["release"] = "version"
            version = self.download_file(version_file, base_path, name, extra_args)

        # Update source db
        db_engine = self.get_db_engine(source_db_url)
        with db_engine.connect() as dbi:
            dbi.execute(
                insert(SourceSORM)
                .values(name=name, parser=parser)
                .prefix_with("IGNORE")
            )

            source_id = dbi.execute(
                select(SourceSORM.source_id).where(SourceSORM.name == name)
            ).scalar()
            dbi.execute(
                insert(VersionORM)
                .values(
                    source_id=source_id,
                    file_path=file_name,
                    db=db,
                    priority=priority,
                    revision=version,
                )
                .prefix_with("IGNORE")
            )
