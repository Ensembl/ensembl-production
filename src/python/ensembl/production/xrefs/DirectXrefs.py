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

"""Xref module to process direct xrefs."""

from ensembl.production.xrefs.Base import *
from ensembl.production.xrefs.mappers.DirectXrefsMapper import DirectXrefsMapper


class DirectXrefs(Base):
    def run(self):
        xref_db_url  = self.param_required("xref_db_url", {"type": "str"})
        species_name = self.param_required("species_name", {"type": "str"})
        base_path    = self.param_required("base_path", {"type": "str"})
        release      = self.param_required("release", {"type": "int"})
        registry     = self.param("registry_url", None, {"type": "str"})
        core_db_url  = self.param("species_db", None, {"type": "str"})

        logging.info(f"DirectXrefs starting for species '{species_name}'")

        # Get the appropriate mapper
        mapper = self.get_xref_mapper(
            xref_db_url, species_name, base_path, release, core_db_url, registry
        )

        # Process the direct xrefs
        direct_mappings = DirectXrefsMapper(mapper)
        direct_mappings.process()
