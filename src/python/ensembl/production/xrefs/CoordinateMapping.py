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

"""Xref module to process the coordinate mappings."""

import logging
from typing import Optional

from ensembl.production.xrefs.Base import Base
from ensembl.production.xrefs.mappers.CoordinateMapper import CoordinateMapper

class CoordinateMapping(Base):
    def run(self):
        xref_db_url: str = self.get_param("xref_db_url", {"required": True, "type": str})
        species_name: str = self.get_param("species_name", {"required": True, "type": str})
        base_path: str = self.get_param("base_path", {"required": True, "type": str})
        release: int = self.get_param("release", {"required": True, "type": int})
        scripts_dir: str = self.get_param("perl_scripts_dir", {"required": True, "type": str})
        registry: Optional[str] = self.get_param("registry_url", {"type": str})
        core_db_url: Optional[str] = self.get_param("species_db", {"type": str})

        logging.info(f"CoordinateMapping starting for species '{species_name}'")

        # Retrieve core database URL if not provided
        if not core_db_url:
            core_db_url = self.get_db_from_registry(species_name, "core", release, registry)

        # Get species id
        db_engine = self.get_db_engine(core_db_url)
        with db_engine.connect() as core_dbi:
            species_id = self.get_taxon_id(core_dbi)

        # Get the appropriate mapper
        mapper = self.get_xref_mapper(xref_db_url, species_name, base_path, release, core_db_url, registry)

        # Process the coordinate xrefs
        coord = CoordinateMapper(mapper)
        coord.run_coordinatemapping(species_name, species_id, scripts_dir)
