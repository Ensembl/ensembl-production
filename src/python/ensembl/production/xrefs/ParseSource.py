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

from ensembl.production.xrefs.Base import *


class ParseSource(Base):
    def run(self):
        parser_name  = self.param_required("parser", {"type": "str"})
        species_name = self.param_required("species_name", {"type": "str"})
        species_id   = self.param_required("species_id", {"type": "int"})
        file_name    = self.param_required("file_name", {"type": "str"})
        source_id    = self.param_required("source_id", {"type": "int"})
        xref_db_url  = self.param_required("xref_db_url", {"type": "str"})
        registry     = self.param_required("registry_url", {"type": "str"})
        release      = self.param_required("release", {"type": "int"})
        core_db_url  = self.param_required("core_db_url", {"type": "str"})
        db           = self.param("db", None, {"type": "str"})
        release_file = self.param("release_file", None, {"type": "str"})
        source_name  = self.param("source_name", None, {"type": "str"})

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
            dba = self.param(f"{db}_db_url")
            if not dba:
                dba = self.get_db_from_registry(species_name, db, release, registry)

            args["dba"] = dba
            args["ensembl_release"] = release
            args["core_db_url"] = core_db_url

        # For RefSeqCoordinate source, we run a perl script
        if parser_name == "RefSeqCoordinateParser":
            args["perl_scripts_dir"] = self.param_required("perl_scripts_dir")
            args["xref_db_url"] = xref_db_url

        # For UniProt we need the hgnc file to extract descriptions
        if re.search(r"^UniProt", parser_name):
            args['hgnc_file'] = self.param("hgnc_file", None, {"type": "str"})

        # Import the parser
        module_name = f"ensembl.production.xrefs.parsers.{parser_name}"
        module = importlib.import_module(module_name)
        parser_class = getattr(module, parser_name)
        parser = parser_class()

        (errors, message) = parser.run(args)
        failure += errors

        xref_dbi.close()

        if failure:
            raise Exception(f"Parser '{parser_name}' failed with message: {message}")

        logging.info(
            f"Source '{source_name}' parsed for species '{species_name}' with the following message:\n{message}"
        )
