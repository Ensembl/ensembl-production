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

"""Parser module for Reactome source."""

import logging
import re
from typing import Any, Dict, Optional, Tuple
from sqlalchemy.engine import Connection

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class ReactomeParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        species_name = args.get("species_name")
        xref_file = args.get("file")
        release_file = args.get("rel_file")
        xref_dbi = args.get("xref_dbi")
        verbose = args.get("verbose", False)

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        # Parse release file
        if release_file:
            release = self.parse_release_file(release_file, verbose)
            if not release:
                raise ValueError(f"Could not find release using {release_file}")
            self.set_release(source_id, release, xref_dbi)

        # Create a hash of all valid names for this species
        species_to_alias = self.species_id_to_names(xref_dbi)
        if species_name:
            species_to_alias.setdefault(species_id, []).append(species_name)

        if not species_to_alias.get(species_id):
            return 0, "Skipped. Could not find species ID to name mapping"

        aliases = species_to_alias[species_id]
        alias_to_species_id = {alias: 1 for alias in aliases}

        # Get relevant source ids
        source_ids = self.get_source_ids(xref_dbi, verbose)

        parsed_count, dependent_count, direct_count, error_count = self.process_file(xref_file, alias_to_species_id, source_ids, species_id, xref_dbi, verbose)

        result_message = (
            f"{parsed_count} Reactome entries processed\n"
            f"\t{dependent_count} dependent xrefs added\n"
            f"\t{direct_count} direct xrefs added\n"
            f"\t{error_count} not found"
        )
        return 0, result_message

    def parse_release_file(self, release_file: str, verbose: bool) -> Optional[str]:
        release = None
        with self.get_filehandle(release_file) as release_io:
            for line in release_io:
                match = re.search(r"([0-9]*)", line)
                if match:
                    release = match.group(1)
                    if verbose:
                        logging.info(f"Reactome release is '{release}'")
        return release

    def get_source_ids(self, xref_dbi: Connection, verbose: bool) -> Tuple[int, int, int, int]:
        reactome_source_id = self.get_source_id_for_source_name("reactome", xref_dbi, "direct")
        transcript_reactome_source_id = self.get_source_id_for_source_name("reactome_transcript", xref_dbi)
        gene_reactome_source_id = self.get_source_id_for_source_name("reactome_gene", xref_dbi)
        reactome_uniprot_source_id = self.get_source_id_for_source_name("reactome", xref_dbi, "uniprot")

        if verbose:
            logging.info(f"Source_id = {reactome_source_id}")
            logging.info(f"Transcript_source_id = {transcript_reactome_source_id}")
            logging.info(f"Gene_source_id = {gene_reactome_source_id}")
            logging.info(f"Uniprot_source_id = {reactome_uniprot_source_id}")

        return {
            "reactome_source_id": reactome_source_id,
            "transcript_reactome_source_id": transcript_reactome_source_id,
            "gene_reactome_source_id": gene_reactome_source_id,
            "reactome_uniprot_source_id": reactome_uniprot_source_id
        }

    def process_file(self, xref_file: str, alias_to_species_id: Dict[str, int], source_ids: Dict[str, int], species_id: int, xref_dbi: Connection, verbose: bool) -> Tuple[int, int, int, int]:
        parsed_count, dep_count, direct_count, err_count = 0, 0, 0, 0

        # Get existing uniprot accessions
        is_uniprot = bool(re.search("UniProt", xref_file))
        uniprot_accessions = self.get_valid_codes("uniprot/", species_id, xref_dbi) if is_uniprot else {}

        with self.get_filehandle(xref_file) as file_io:
            if file_io.read(1) == '':
                raise IOError(f"Reactome file is empty")
            file_io.seek(0)

            for line in file_io:
                line = line.strip()
                ensembl_stable_id, reactome_id, url, description, evidence, species = re.split(r"\t+", line)

                # Check description pattern
                if not re.match(r"^[A-Za-z0-9_,\(\)\/\-\.:\+'&;\"\/\?%>\s\[\]]+$", description):
                    continue

                species = re.sub(r"\s", "_", species).lower()

                # Continue only for current species
                if alias_to_species_id.get(species):
                    parsed_count += 1

                    ensembl_type = None
                    info_type = "DIRECT"
                    current_source_id = source_ids["reactome_source_id"]

                    if is_uniprot:
                        if uniprot_accessions.get(ensembl_stable_id): # Add uniprot dependent xrefs
                            for xref in uniprot_accessions[ensembl_stable_id]:
                                self.add_dependent_xref(
                                    {
                                        "master_xref_id": xref,
                                        "accession": reactome_id,
                                        "label": reactome_id,
                                        "description": description,
                                        "source_id": source_ids["reactome_uniprot_source_id"],
                                        "species_id": species_id,
                                        "info_type": "DEPENDENT",
                                    },
                                    xref_dbi,
                                )
                                dep_count += 1
                    elif re.search(r"G[0-9]*$", ensembl_stable_id): # Attempt to guess the object_type based on the stable id
                        ensembl_type = "gene"
                        current_source_id = source_ids["gene_reactome_source_id"]
                    elif re.search(r"T[0-9]*$", ensembl_stable_id):
                        ensembl_type = "transcript"
                        current_source_id = source_ids["transcript_reactome_source_id"]
                    elif re.search(r"P[0-9]*$", ensembl_stable_id):
                        ensembl_type = "translation"
                    else: # Is not in Uniprot and does not match Ensembl stable id format
                        if verbose:
                            logging.debug(f"Could not find type for {ensembl_stable_id}")
                        err_count += 1
                        continue

                    # Add new entry for reactome xref as well as direct xref to ensembl stable id
                    if ensembl_type:
                        xref_id = self.add_xref(
                            {
                                "accession": reactome_id,
                                "label": reactome_id,
                                "description": description,
                                "source_id": current_source_id,
                                "species_id": species_id,
                                "info_type": info_type,
                            },
                            xref_dbi,
                        )
                        self.add_direct_xref(xref_id, ensembl_stable_id, ensembl_type, "", xref_dbi)
                        direct_count += 1

        return parsed_count, dep_count, direct_count, err_count
