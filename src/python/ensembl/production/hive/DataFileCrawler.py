#  See the NOTICE file distributed with this work for additional information
#  regarding copyright ownership.
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
"""Crawler module for DataFile Scraper pipeline. Finds and loads manifest files."""

from pathlib import Path

import eHive

from ..datafile.scraper.utils import manifest_rows
from ..datafile.scraper.serializers import metadata_from_db, metadata_from_manifest
from .BaseProdRunnable import BaseProdRunnable


class DataFileCrawler(BaseProdRunnable):
    def run(self):
        file_metadata_list = []
        errors = []
        root_dir = Path(self.param("root_dir")).resolve()
        metadata_db_url = self.param("metadata_db_url")
        manifests = root_dir.rglob("MANIFEST")
        for manifest in manifests:
            with open(manifest, "r") as manifest_file:
                try:
                    for manifest_row in manifest_rows(manifest_file):
                        manifest_dir = (root_dir / manifest).parent
                        manifest_data = metadata_from_manifest(
                            manifest_row, manifest_dir
                        )
                        species = manifest_data["species"]
                        ens_release = manifest_data["ens_release"]
                        db_data, err = metadata_from_db(
                            metadata_db_url, species, ens_release
                        )
                        if err:
                            msg = f"Error fetching metadata from DB {metadata_db_url}: {err}"
                            errors.append(msg)
                        else:
                            file_metadata_list.append({**manifest_data, **db_data})
                except ValueError as exc:
                    msg = f"Error while reading {manifest.resolve()}: {exc}"
                    errors.append(msg)
        self.param("file_metadata_list", file_metadata_list)
        self.param("errors", errors)

    def write_output(self):
        for data in self.param("file_metadata_list"):
            self.flow_output_data(data)
        self.write_result({"errors": self.param("errors")})
