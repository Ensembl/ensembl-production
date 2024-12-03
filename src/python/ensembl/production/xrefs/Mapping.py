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

"""Mapping module to map the added xrefs into the core DB."""

import logging

from ensembl.production.xrefs.Base import Base
from ensembl.production.xrefs.mappers.ProcessPriorities import ProcessPriorities
from ensembl.production.xrefs.mappers.ProcessPaired import ProcessPaired
from ensembl.production.xrefs.mappers.ProcessMoves import ProcessMoves
from ensembl.production.xrefs.mappers.OfficialNaming import OfficialNaming
from ensembl.production.xrefs.mappers.TestMappings import TestMappings
from ensembl.production.xrefs.mappers.XrefLoader import XrefLoader
from ensembl.production.xrefs.mappers.DisplayXrefs import DisplayXrefs

class Mapping(Base):
    def run(self):
        xref_db_url: str = self.get_param("xref_db_url", {"required": True, "type": str})
        species_name: str = self.get_param("species_name", {"required": True, "type": str})
        base_path: str = self.get_param("base_path", {"required": True, "type": str})
        release: int = self.get_param("release", {"required": True, "type": int})
        registry: str = self.get_param("registry_url", {"type": str})
        core_db_url: str = self.get_param("species_db", {"type": str})
        verbose: bool = self.get_param("verbose", {"type": bool, "default": False})

        logging.info(f"Mapping starting for species '{species_name}'")

        if not core_db_url:
            core_db_url = self.get_db_from_registry(
                species_name, "core", release, registry
            )

        # Get species id
        db_engine = self.get_db_engine(core_db_url)
        with db_engine.connect() as core_dbi:
            species_id = self.get_taxon_id(core_dbi)

        # Get the appropriate mapper
        mapper = self.get_xref_mapper(xref_db_url, species_name, base_path, release, core_db_url, registry)

        # Process the xref priorities
        priorities = ProcessPriorities(mapper)
        priorities.process()

        # Process the paired xrefs
        paired = ProcessPaired(mapper)
        paired.process()

        # Process the needed xref moves
        mover = ProcessMoves(mapper)
        mover.biomart_testing(verbose)
        mover.source_defined_move(verbose)
        mover.process_alt_alleles(verbose)

        # Set the official names for select species
        naming = OfficialNaming(mapper)
        naming.run(species_id, verbose)

        # Test the validity of the data before mapping into the core DB
        warnings = 0
        logging.info("Testing mappings")
        tester = TestMappings(mapper)
        warnings += tester.direct_stable_id_check()
        warnings += tester.xrefs_counts_check()
        warnings += tester.name_change_check(mapper.official_name())

        # Map xref data onto the core DB
        loader = XrefLoader(mapper)
        loader.update(species_name)

        # Set the display xrefs
        display = DisplayXrefs(mapper)
        display.build_display_xrefs()

        # Pass datachecks data
        dataflow_params = {"species_name": species_name, "species_db": core_db_url}

        self.write_output("datacheck", dataflow_params)
