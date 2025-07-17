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

"""Scheduling module to create a pipeline branch for each species in list or division."""

import logging
import re
import requests
from typing import List, Dict, Optional

from ensembl.production.xrefs.Base import Base

class ScheduleSpecies(Base):
    def run(self):
        run_all: bool = self.get_param("run_all", {"required": True, "type": bool})
        registry: str = self.get_param("registry_url", {"required": True, "type": str})
        ensembl_release: int = self.get_param("release", {"required": True, "type": int})
        metasearch_url: str = self.get_param("metasearch_url", {"required": True, "type": str})
        species: list = self.get_param("species", {"default": [], "type": list})
        antispecies: list = self.get_param("antispecies", {"default": [], "type": list})
        division: list = self.get_param("division", {"default": [], "type": list})
        group: str = self.get_param("group", {"default": "core", "type": str})
        db_prefix: Optional[str] = self.get_param("db_prefix", {"type": str})

        logging.info("ScheduleSpecies starting with parameters:")
        logging.info(f"\tParam: run_all = {run_all}")
        logging.info(f"\tParam: registry = {registry}")
        logging.info(f"\tParam: release = {ensembl_release}")
        logging.info(f"\tParam: metasearch_url = {metasearch_url}")
        logging.info(f"\tParam: species = {species}")
        logging.info(f"\tParam: antispecies = {antispecies}")
        logging.info(f"\tParam: division = {division}")
        logging.info(f"\tParam: db_prefix = {db_prefix}")
        logging.info(f"\tParam: group = {group}")

        # Fix registry url, if needed
        registry = self._fix_registry_url(registry)

        loaded_dbs = {}
        dbs = []

        # Construct the db name pattern
        db_prefix = f"{db_prefix}_" if db_prefix else ""
        name_pattern = f"{db_prefix}%_{group}%"

        # Getting all dbs
        if run_all:
            dbs = self._query_registry(metasearch_url, name_pattern, ensembl_release, registry)
            loaded_dbs = self.check_validity(dbs, db_prefix, group, ensembl_release)

        # Getting dbs for specified species
        elif species:
            for species_name in species:
                species_pattern = f"{db_prefix}{species_name}_core%"
                species_dbs = self._query_registry(metasearch_url, species_pattern, ensembl_release, registry)
                if not species_dbs:
                    raise LookupError(f"Database not found for {species_name}, check registry parameters")
                dbs.extend(species_dbs)

            loaded_dbs = self.check_validity(dbs, db_prefix, group, ensembl_release)

            # Check if all wanted species were found
            self._check_species_found(species, loaded_dbs)

        # Getting dbs for specified divisions
        elif division:
            for div in division:
                div_dbs = self._query_registry(metasearch_url, name_pattern, ensembl_release, registry, div)
                dbs.extend(div_dbs)

            loaded_dbs = self.check_validity(dbs, db_prefix, group, ensembl_release)

        # No species or division specified with run_all set to False
        else:
            raise ValueError("Must provide species or division with run_all set to False")

        if not loaded_dbs:
            raise LookupError(f"Could not find any matching dbs in registry {registry}")

        if run_all:
            logging.info(f"All species in {len(loaded_dbs)} databases loaded")

        # Write dataflow output
        for species_name, db in loaded_dbs.items():
            if species_name not in antispecies:
                self.write_output("species", {"species_name": species_name, "species_db": db})

    def _fix_registry_url(self, registry: str) -> str:
        match = re.search(r"^(.*)://(.*)", registry)
        if match:
            registry = match.group(2)
        match = re.search(r"(.*)/(.*)$", registry)
        if match:
            registry = match.group(1)
        return registry

    def _query_registry(self, metasearch_url: str, name_pattern: str, ensembl_release: int, registry: str, division: str = None) -> List[str]:
        ensembl_release_str = str(ensembl_release)

        filters = [
            {
                "meta_key": "schema_version",
                "meta_value": ensembl_release_str
            }
        ]

        if division:
            filters.append({"meta_key": "species.division", "meta_value": division})

        metasearch_body = {
            "name_pattern": name_pattern,
            "filters": filters,
            "servers": [registry],
        }
        response = requests.post(metasearch_url, json=metasearch_body).json()
        return response.get(registry, [])

    def _check_species_found(self, species_list: List[str], loaded_dbs: Dict[str, str]):
        for species_name in species_list:
            if species_name not in loaded_dbs:
                raise LookupError(f"Database not found for {species_name}, check registry parameters")

    def check_validity(self, dbs: List[str], prefix: str, group: str, release: int) -> Dict[str, str]:
        valid_dbs = {}

        for db in dbs:
            # Extract db name
            db_name = re.search(r"(.*)/(.*)$", db).group(2) if re.search(r"(.*)/(.*)$", db) else db

            # Check if db is valid
            match = re.search(rf"^{prefix}([a-z]+_[a-z0-9]+(?:_[a-z0-9]+)?)_{group}(?:_\d+)?_{release}_(\w+)$", db_name)
            if match:
                species_name = match.group(1)
                if species_name not in valid_dbs:
                    logging.info(f"Species {species_name} loaded")
                    valid_dbs[species_name] = db
                else:
                    raise ValueError(f"Database {valid_dbs[species_name]} already loaded for species {species_name}, cannot load second database {db}")
            else:
                logging.info(f"Could not extract species name from database {db}")

        return valid_dbs
