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

"""Parsing module to call specific file/db parsers based on xref source."""

import logging
import re
import importlib
from typing import Optional

from ensembl.production.xrefs.Base import Base

class ParseSource(Base):
    def run(self) -> None:
        parser_name: str = self.get_param("parser", {"required": True, "type": str})
        species_name: str = self.get_param("species_name", {"required": True, "type": str})
        species_id: int = self.get_param("species_id", {"required": True, "type": int})
        file_name: str = self.get_param("file_name", {"required": True, "type": str})
        source_id: int = self.get_param("source_id", {"required": True, "type": int})
        xref_db_url: str = self.get_param("xref_db_url", {"required": True, "type": str})
        registry_url: str = self.get_param("registry_url", {"required": True, "type": str})
        release: int = self.get_param("release", {"required": True, "type": int})
        core_db_url: str = self.get_param("core_db_url", {"required": True, "type": str})
        db: Optional[str] = self.get_param("db", {"type": str})
        release_file: Optional[str] = self.get_param("release_file", {"type": str})
        source_name: Optional[str] = self.get_param("source_name", {"type": str})

        logging.info(
            f"ParseSource starting for source '{source_name}' with parser '{parser_name}' for species '{species_name}'"
        )

        failure = 0
        message = None

        # Set parser arguments
        args = {
            "source_id": source_id,
            "species_id": species_id,
            "rel_file": release_file,
            "species_name": species_name,
            "file": file_name,
        }

        # Connect to xref db
        xref_dbi = self.get_dbi(xref_db_url)
        args["xref_dbi"] = xref_dbi

        # Get the extra db, if any
        if db:
            db_url = self.get_param(f"{db}_db_url", {"type": str})
            if not db_url:
                db_url = self.get_db_from_registry(species_name, db, release, registry_url)

            args["extra_db_url"] = db_url
            args["ensembl_release"] = release
            args["core_db_url"] = core_db_url

        # For RefSeqCoordinate source, we run a perl script
        if parser_name == "RefSeqCoordinateParser":
            args["perl_scripts_dir"] = self.get_param("perl_scripts_dir", {"required": True, "type": str})
            args["xref_db_url"] = xref_db_url

        # For UniProt we need the hgnc file to extract descriptions
        if re.search(r"^UniProt", parser_name):
            args['hgnc_file'] = self.get_param("hgnc_file", {"type": str})

        # Import the parser
        module_name = f"ensembl.production.xrefs.parsers.{parser_name}"
        module = importlib.import_module(module_name)
        parser_class = getattr(module, parser_name)
        parser = parser_class()

        errors, message = parser.run(args)
        failure += errors

        xref_dbi.close()

        if failure:
            raise Exception(f"Parser '{parser_name}' failed with message: {message}")

        logging.info(
            f"Source '{source_name}' parsed for species '{species_name}' with the following message:\n{message}"
        )
