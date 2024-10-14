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

"""Xref module to process the RNAcentral mappings."""

from ensembl.production.xrefs.Base import *
from ensembl.production.xrefs.mappers.RNACentralMapper import RNACentralMapper
from ensembl.production.xrefs.mappers.methods.MySQLChecksum import MySQLChecksum


class RNACentralMapping(Base):
    def run(self):
        xref_db_url   = self.param_required("xref_db_url", {"type": "str"})
        species_name  = self.param_required("species_name", {"type": "str"})
        base_path     = self.param_required("base_path", {"type": "str"})
        release       = self.param_required("release", {"type": "int"})
        source_db_url = self.param_required("source_db_url", {"type": "str"})
        registry      = self.param("registry_url", None, {"type": "str"})
        core_db_url   = self.param("species_db", None, {"type": "str"})

        logging.info(f"RNACentralMapping starting for species '{species_name}'")

        if not core_db_url:
            core_db_url = self.get_db_from_registry(
                species_name, "core", release, registry
            )

        # Get species id
        db_engine = self.get_db_engine(core_db_url)
        with db_engine.connect() as core_dbi:
            species_id = self.get_taxon_id(core_dbi)

        # Get the rna central mapper
        mapper = RNACentralMapper(
            self.get_xref_mapper(
                xref_db_url, species_name, base_path, release, core_db_url, registry
            )
        )

        # Get source id
        db_engine = self.get_db_engine(source_db_url)
        with db_engine.connect() as source_dbi:
            source_id = self.get_source_id_from_name(source_dbi, "RNACentral")

            method = MySQLChecksum({"MAPPER": mapper})
            results = method.run(
                mapper.target(), source_id, mapper.object_type(), source_dbi
            )

        if results:
            mapper.upload(results, species_id)
