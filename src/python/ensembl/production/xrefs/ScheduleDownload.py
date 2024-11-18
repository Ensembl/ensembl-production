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

"""Scheduling module to create download jobs for all xref sources in config file."""

import json
import logging

from ensembl.production.xrefs.Base import Base

class ScheduleDownload(Base):
    def run(self) -> None:
        config_file: str = self.get_param("config_file", {"required": True, "type": str})
        source_db_url: str = self.get_param("source_db_url", {"required": True, "type": str})
        reuse_db: bool = self.get_param("reuse_db", {"required": True, "type": bool})

        logging.info("ScheduleDownload starting with parameters:")
        logging.info(f"Param: config_file = {config_file}")
        logging.info(f"Param: source_db_url = {source_db_url}")
        logging.info(f"Param: reuse_db = {reuse_db}")

        # Create the source db from url
        self.create_source_db(source_db_url, reuse_db)

        # Extract sources to download from config file
        with open(config_file) as conf_file:
            sources = json.load(conf_file)

        if not sources:
            raise ValueError(
                f"No sources found in config file {config_file}. Need sources to run pipeline"
            )

        for source_data in sources:
            name = source_data["name"]
            parser = source_data["parser"]
            priority = source_data["priority"]
            file = source_data["file"]
            db = source_data.get("db")
            version_file = source_data.get("release")
            rel_number = source_data.get("release_number")
            catalog = source_data.get("catalog")

            logging.info(f"Source to download: {name}")

            # Pass the source parameters into download jobs
            self.write_output(
                "sources",
                {
                    "parser": parser,
                    "name": name,
                    "priority": priority,
                    "db": db,
                    "version_file": version_file,
                    "file": file,
                    "rel_number": rel_number,
                    "catalog": catalog,
                },
            )
