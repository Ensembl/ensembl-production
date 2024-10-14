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

"""Parser module for miRBase source."""

from ensembl.production.xrefs.parsers.BaseParser import *


class miRBaseParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id    = args["source_id"]
        species_id   = args["species_id"]
        species_name = args["species_name"]
        file         = args["file"]
        xref_dbi     = args["xref_dbi"]

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        # Get the species name(s)
        species_to_names = self.species_id_to_names(xref_dbi)
        if species_name:
            species_to_names.setdefault(species_id, []).append(species_name)
        if not species_to_names.get(species_id):
            return 0, "Skipped. Could not find species ID to name mapping"

        names = species_to_names[species_id]
        name_to_species_id = {name: species_id for name in names}

        xrefs = self.create_xrefs(source_id, file, species_id, name_to_species_id)
        if not xrefs:
            return 0, "No xrefs added"

        self.upload_xref_object_graphs(xrefs, xref_dbi)

        result_message = "Read %d xrefs from %s" % (len(xrefs), file)

        return 0, result_message

    def create_xrefs(self, source_id: int, file: str, species_id: int, name_to_species_id: Dict[str, int]) -> List[Dict[str, Any]]:
        xrefs = []

        # Read mirbase file
        for section in self.get_file_sections(file, "//\n"):
            if len(section) == 1:
                continue

            entry = "".join(section)
            if not entry:
                continue

            xref = {}

            (header, sequence) = re.split(r"\nSQ", entry, 2)
            species = None

            # Extract sequence
            if sequence:
                seq_lines = sequence.split("\n")
                seq_lines.pop(0)

                sequence = "".join(seq_lines)
                sequence = sequence.upper()
                sequence = re.sub("U", "T", sequence)
                sequence = re.sub(r"[\d+,\s+]", "", sequence)

            # Extract name, accession, and description
            name = re.search(r"^ID\s+(\S+)\s+", header, flags=re.MULTILINE).group(1)
            accession = re.search(r"^AC\s+(\S+);\s+", header, flags=re.MULTILINE).group(
                1
            )
            description = re.search(
                r"^DE\s+(.+)\s+stem(-|\s)loop", header, flags=re.MULTILINE
            ).group(1)

            # Format description and extract species name
            if description:
                description_parts = re.split(r"\s+", description)
                description_parts.pop()
                species = " ".join(description_parts)
                species = species.lower()
                species = re.sub(" ", "_", species)

            # If no species match, skip to next record
            species_id_check = name_to_species_id.get(species)
            if not species_id_check:
                continue

            if species_id and species_id == species_id_check:
                xref = {
                    "SEQUENCE_TYPE": "dna",
                    "STATUS": "experimental",
                    "SOURCE_ID": source_id,
                    "ACCESSION": accession,
                    "LABEL": name,
                    "DESCRIPTION": name,
                    "SEQUENCE": sequence,
                    "SPECIES_ID": species_id,
                }
                xrefs.append(xref)

        return xrefs
