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

from ensembl.production.xrefs.parsers.BaseParser import *


class ReactomeParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id    = args["source_id"]
        species_id   = args["species_id"]
        species_name = args["species_name"]
        file         = args["file"]
        release_file = args["rel_file"]
        xref_dbi     = args["xref_dbi"]
        verbose      = args.get("verbose", False)

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        # Parse release file
        if release_file:
            release = None

            release_io = self.get_filehandle(release_file)
            for line in release_io:
                match = re.search(r"([0-9]*)", line)
                if match:
                    release = match.group(1)
                    if verbose:
                        logging.info(f"Reactome release is '{release}'")
            release_io.close()

            if not release:
                raise IOError(f"Could not find release using {release_file}")

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
        reactome_source_id = self.get_source_id_for_source_name(
            "reactome", xref_dbi, "direct"
        )
        transcript_reactome_source_id = self.get_source_id_for_source_name(
            "reactome_transcript", xref_dbi
        )
        gene_reactome_source_id = self.get_source_id_for_source_name(
            "reactome_gene", xref_dbi
        )
        reactome_uniprot_source_id = self.get_source_id_for_source_name(
            "reactome", xref_dbi, "uniprot"
        )

        # Cannot continue unless source ids are found
        if (
            not reactome_source_id
            or not transcript_reactome_source_id
            or not gene_reactome_source_id
        ):
            raise KeyError("Could not find source id for reactome sources")
        else:
            if verbose:
                logging.info(f"Source_id = {reactome_source_id}")
                logging.info(f"Transcript_source_id = {transcript_reactome_source_id}")
                logging.info(f"Gene_source_id = {gene_reactome_source_id}")

        if not reactome_uniprot_source_id:
            raise KeyError("Could not find source id for reactome uniprot")
        else:
            if verbose:
                logging.info(f"Uniprot_source_id = {reactome_uniprot_source_id}")

        # Get uniprot accessions
        is_uniprot = 0
        uniprot_accessions = {}
        if re.search("UniProt", file):
            is_uniprot = 1
            uniprot_accessions = self.get_valid_codes("uniprot/", species_id, xref_dbi)

        parsed_count, err_count = 0, 0

        # Read file
        reactome_io = self.get_filehandle(file)

        for line in reactome_io:
            line = line.strip()

            (ensembl_stable_id, reactome_id, url, description, evidence, species) = (
                re.split(r"\t+", line)
            )

            # Check description pattern
            match = re.search(
                r"^[A-Za-z0-9_,\(\)\/\-\.:\+'&;\"\/\?%>\s\[\]]+$", description
            )
            if not match:
                continue

            species = re.sub(r"\s", "_", species)
            species = species.lower()

            current_source_id = reactome_source_id

            if alias_to_species_id.get(species):
                parsed_count += 1

                ensembl_type = None
                info_type = "DIRECT"

                # Add uniprot dependent xrefs
                if is_uniprot:
                    if uniprot_accessions.get(ensembl_stable_id):
                        for xref in uniprot_accessions[ensembl_stable_id]:
                            xref_id = self.add_dependent_xref(
                                {
                                    "master_xref_id": xref,
                                    "accession": reactome_id,
                                    "label": reactome_id,
                                    "description": description,
                                    "source_id": reactome_uniprot_source_id,
                                    "species_id": species_id,
                                },
                                xref_dbi,
                            )
                        info_type = "DEPENDENT"

                # Attempt to guess the object_type based on the stable id
                elif re.search(r"G[0-9]*$", ensembl_stable_id):
                    ensembl_type = "gene"
                    current_source_id = gene_reactome_source_id
                elif re.search(r"T[0-9]*$", ensembl_stable_id):
                    ensembl_type = "transcript"
                    current_source_id = transcript_reactome_source_id
                elif re.search(r"P[0-9]*$", ensembl_stable_id):
                    ensembl_type = "translation"

                # Is not in Uniprot and does not match Ensembl stable id format
                else:
                    if verbose:
                        logging.debug(f"Could not find type for {ensembl_stable_id}")
                    err_count += 1
                    continue

                # Add new entry for reactome xref as well as direct xref to ensembl stable id
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

                if ensembl_type:
                    self.add_direct_xref(
                        xref_id, ensembl_stable_id, ensembl_type, "", xref_dbi
                    )

        reactome_io.close()

        result_message = f"{parsed_count} entries processed\n"
        result_message += f"{err_count} not found"

        return 0, result_message
