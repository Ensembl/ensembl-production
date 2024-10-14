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

"""Parser module for ArrayExpress source."""

from ensembl.production.xrefs.parsers.BaseParser import *


class ArrayExpressParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id       = args["source_id"]
        species_id      = args["species_id"]
        species_name    = args["species_name"]
        file            = args["file"]
        dba             = args["dba"]
        ensembl_release = args["ensembl_release"]
        xref_dbi        = args["xref_dbi"]
        verbose         = args.get("verbose", False)

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        # Extract db connection parameters from file name
        project, db_user, db_host, db_port, db_name, db_pass = (
            self.extract_params_from_string(
                file, ["project", "user", "host", "port", "dbname", "pass"]
            )
        )
        if not db_user:
            db_user = "ensro"
        if not db_port:
            db_port = "3306"

        # Get the species name(s)
        species_id_to_names = self.species_id_to_names(xref_dbi)
        if species_name:
            species_id_to_names.setdefault(species_id, []).append(species_name)

        if not species_id_to_names.get(species_id):
            return 0, "Skipped. Could not find species ID to name mapping"
        names = species_id_to_names[species_id]

        # Look up the species in ftp server and check if active
        species_lookup = self._get_species()
        active = self._is_active(species_lookup, names, verbose)
        if not active:
            return 0, "Skipped. ArrayExpress source not active for species"

        species_name = species_id_to_names[species_id][0]

        # Connect to the appropriate arrayexpress db
        if db_host:
            arrayexpress_db_url = URL.create(
                "mysql", db_user, db_pass, db_host, db_port, db_name
            )
        elif project and project == "ensembl":
            if verbose:
                logging.info("Looking for db in mysql-ens-sta-1")
            registry = "ensro@mysql-ens-sta-1:4519"
            arrayexpress_db_url = self.get_db_from_registry(
                species_name, "core", ensembl_release, registry
            )
        elif project and project == "ensemblgenomes":
            if verbose:
                logging.info(
                    "Looking for db in mysql-eg-staging-1 and mysql-eg-staging-2"
                )
            registry = "ensro@mysql-eg-staging-1.ebi.ac.uk:4160"
            arrayexpress_db_url = self.get_db_from_registry(
                species_name, "core", ensembl_release, registry
            )

            if not arrayexpress_db_url:
                registry = "ensro@mysql-eg-staging-2.ebi.ac.uk:4275"
                arrayexpress_db_url = self.get_db_from_registry(
                    species_name, "core", ensembl_release, registry
                )
        elif dba:
            arrayexpress_db_url = dba
        else:
            arrayexpress_db_url = None

        if not arrayexpress_db_url:
            raise IOError(
                f"Could not find ArrayExpress DB. Missing or unsupported project value. Supported values: ensembl, ensemblgenomes."
            )
        else:
            if verbose:
                logging.info(f"Found ArrayExpress DB: {arrayexpress_db_url}")

        xref_count = 0

        db_engine = self.get_db_engine(arrayexpress_db_url)
        with db_engine.connect() as arrayexpress_dbi:
            query = select(GeneORM.stable_id).where(
                GeneORM.biotype != "LRG_gene", GeneORM.is_current == 1
            )
            result = arrayexpress_dbi.execute(query).mappings().all()

        # Add direct xref for every current gene found
        for row in result:
            xref_id = self.add_xref(
                {
                    "accession": row.stable_id,
                    "label": row.stable_id,
                    "source_id": source_id,
                    "species_id": species_id,
                    "info_type": "DIRECT",
                },
                xref_dbi,
            )
            self.add_direct_xref(xref_id, row.stable_id, "gene", "", xref_dbi)

            xref_count += 1

        result_message = f"Added {xref_count} DIRECT xrefs"

        return 0, result_message

    def _get_species(self) -> Dict[str, int]:
        ftp_server = "ftp.ebi.ac.uk"
        ftp_dir = "pub/databases/microarray/data/atlas/bioentity_properties/ensembl"

        species_lookup = {}

        ftp = FTP(ftp_server)
        ftp.login("anonymous", "-anonymous@")
        ftp.cwd(ftp_dir)
        remote_files = ftp.nlst()
        ftp.close()

        for file in remote_files:
            species = file.split(".")[0]
            species_lookup[species] = 1

        return species_lookup

    def _is_active(self, species_lookup: Dict[str, int], names: List[str], verbose: bool) -> bool:
        # Loop through the names and aliases first. If we get a hit then great
        active = False
        for name in names:
            if species_lookup.get(name):
                if verbose:
                    logging.info(
                        f"Found ArrayExpress has declared the name {name}. This was an alias"
                    )
                active = True
                break

        return active
