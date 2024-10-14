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

from ensembl.production.xrefs.Base import *


class ScheduleSpecies(Base):
    def run(self):
        run_all         = self.param_required("run_all", {"type": "bool"})
        registry        = self.param_required("registry_url", {"type": "str"})
        ensembl_release = self.param_required("release", {"type": "int"})
        metasearch_url  = self.param_required("metasearch_url", {"type": "str"})
        species         = self.param("species", None, {"default": "", "type": "str"})
        antispecies     = self.param("antispecies", None, {"default": "", "type": "str"})
        division        = self.param("division", None, {"default": "", "type": "str"})
        db_prefix       = self.param("db_prefix", None, {"type": "str"})
        group           = self.param("group", None, {"default": "core", "type": "str"})

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

        if species:
            species = species.split(",")
        if antispecies:
            antispecies = antispecies.split(",")
        if division:
            division = division.split(",")
        ensembl_release = str(ensembl_release)

        # Fix registry url, if needed
        match = re.search(r"^(.*)://(.*)", registry)
        if match:
            registry = match.group(2)
        match = re.search(r"(.*)/(.*)", registry)
        if match:
            registry = match.group(1)

        loaded_dbs = {}
        dbs = []

        # Construct the db name pattern
        name_pattern = f"%_{group}%"
        if db_prefix:
            db_prefix = f"{db_prefix}_"
        else:
            db_prefix = ""
        name_pattern = f"{db_prefix}{name_pattern}"

        # Getting all dbs
        if run_all:
            metasearch_body = {
                "name_pattern": name_pattern,
                "filters": [
                    {"meta_key": "schema_version", "meta_value": ensembl_release},
                ],
                "servers": [registry],
            }

            # Query registry for all core dbs
            dbs = requests.post(metasearch_url, json=metasearch_body).json()
            dbs = dbs[registry]

            loaded_dbs = self.check_validity(dbs, db_prefix, group, ensembl_release)

        # Getting dbs for specified species
        elif species and len(species) > 0:
            for species_name in species:
                name_pattern = f"{species_name}_core%"
                name_pattern = f"{db_prefix}{name_pattern}"

                metasearch_body = {
                    "name_pattern": name_pattern,
                    "filters": [
                        {"meta_key": "schema_version", "meta_value": ensembl_release},
                    ],
                    "servers": [registry],
                }

                # Query registry for species dbs
                species_dbs = requests.post(metasearch_url, json=metasearch_body).json()

                if len(species_dbs[registry]) < 1:
                    raise IOError(
                        f"Database not found for {species_name}, check registry parameters"
                    )
                else:
                    dbs = dbs + species_dbs[registry]

            loaded_dbs = self.check_validity(dbs, db_prefix, group, ensembl_release)

            # Check if all wanted species were found
            for species_name in species:
                if not loaded_dbs.get(species_name):
                    raise IOError(
                        f"Database not found for {species_name}, check registry parameters"
                    )

        # Getting dbs for specified divisions
        elif division and len(division) > 0:
            for div in division:
                metasearch_body = {
                    "name_pattern": name_pattern,
                    "filters": [
                        {"meta_key": "schema_version", "meta_value": ensembl_release},
                        {"meta_key": "species.division", "meta_value": div},
                    ],
                    "servers": [registry],
                }

                # Query registry for dbs in division
                div_dbs = requests.post(metasearch_url, json=metasearch_body).json()
                dbs = dbs + div_dbs[registry]

            loaded_dbs = self.check_validity(dbs, db_prefix, group, ensembl_release)

        if len(loaded_dbs) == 0:
            raise IOError(f"Could not find any matching dbs in registry {registry}")

        if run_all:
            logging.info(f"All species in {len(loaded_dbs)} databases loaded")

        # Write dataflow output
        for species_name, db in loaded_dbs.items():
            if species_name not in antispecies:
                self.write_output(
                    "species", {"species_name": species_name, "species_db": db}
                )

    def check_validity(self, dbs: List(str), prefix: str, group: str, release: str):
        valid_dbs = {}

        for db in dbs:
            # Extract db name
            db_name = db
            match = re.search(r"(.*)/(.*)", db_name)
            if match:
                db_name = match.group(2)

            # Check if db is valid
            match = re.search(
                r"^(%s)([a-z]+_[a-z0-9]+(?:_[a-z0-9]+)?)_%s(?:_\d+)?_%s_(\w+)$"
                % (prefix, group, release),
                db_name,
            )
            if match:
                species_name = match.group(2)
                if not valid_dbs.get(species_name):
                    logging.info(f"Species {species_name} loaded")
                    valid_dbs[species_name] = db
                else:
                    raise IOError(
                        f"Database {valid_dbs[species_name]} already loaded for species {species_name}, cannot load second database {db}"
                    )
            else:
                logging.info(f"Could not extract species name from database {db}")

        return valid_dbs
