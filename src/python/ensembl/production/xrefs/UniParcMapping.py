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

"""Xref module to process the Uniparc mappings."""

import logging

from ensembl.production.xrefs.Base import Base
from ensembl.production.xrefs.mappers.UniParcMapper import UniParcMapper
from ensembl.production.xrefs.mappers.methods.MySQLChecksum import MySQLChecksum

class UniParcMapping(Base):
    def run(self):
        xref_db_url: str = self.get_param("xref_db_url", {"required": True, "type": str})
        species_name: str = self.get_param("species_name", {"required": True, "type": str})
        base_path: str = self.get_param("base_path", {"required": True, "type": str})
        release: int = self.get_param("release", {"required": True, "type": int})
        source_db_url: str = self.get_param("source_db_url", {"required": True, "type": str})
        registry: str = self.get_param("registry_url", {"type": str})
        core_db_url: str = self.get_param("species_db", {"type": str})

        logging.info(f"UniParcMapping starting for species '{species_name}'")

        if not core_db_url:
            core_db_url = self.get_db_from_registry(species_name, "core", release, registry)

        # Get species id
        db_engine = self.get_db_engine(core_db_url)
        with db_engine.connect() as core_dbi:
            species_id = self.get_taxon_id(core_dbi)

        # Get the uniparc mapper
        mapper = UniParcMapper(
            self.get_xref_mapper(xref_db_url, species_name, base_path, release, core_db_url, registry)
        )

        # Get source id
        db_engine = self.get_db_engine(source_db_url)
        with db_engine.connect() as source_dbi:
            source_id = self.get_source_id_from_name("UniParc", source_dbi)

            method = MySQLChecksum({"MAPPER": mapper})
            results = method.run(
                mapper.target(), source_id, mapper.object_type(), source_dbi
            )

        if results:
            mapper.upload(results, species_id)
