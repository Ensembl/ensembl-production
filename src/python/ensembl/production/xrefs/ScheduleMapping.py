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

"""Scheduling module to xref mapping jobs."""

import logging

from ensembl.production.xrefs.Base import Base
from ensembl.production.xrefs.mappers.CoreInfo import CoreInfo

class ScheduleMapping(Base):
    def run(self):
        xref_db_url: str = self.get_param("xref_db_url", {"required": True, "type": str})
        species_name: str = self.get_param("species_name", {"required": True, "type": str})
        base_path: str = self.get_param("base_path", {"required": True, "type": str})
        release: int = self.get_param("release", {"required": True, "type": int})
        registry: str = self.get_param("registry_url", {"type": str})
        core_db_url: str = self.get_param("species_db", {"type": str})

        logging.info(f"ScheduleMapping starting for species '{species_name}'")

        # Get the appropriate mapper
        mapper = self.get_xref_mapper(xref_db_url, species_name, base_path, release, core_db_url, registry)

        # Load the core data
        logging.info("Loading core data")
        core_info = CoreInfo(mapper)
        core_info.get_core_data()
        core_info.get_alt_alleles()

        if not core_db_url:
            core_db_url = self.get_db_from_registry(
                species_name, "core", release, registry
            )

        # Pass mapping data
        dataflow_params = {
            "xref_db_url": xref_db_url,
            "species_name": species_name,
            "species_db": core_db_url,
        }

        self.write_output("pre_mapping", dataflow_params)
        self.write_output("mapping", dataflow_params)
