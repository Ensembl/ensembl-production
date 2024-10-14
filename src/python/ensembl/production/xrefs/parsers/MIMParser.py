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

"""Parser module for MIM source."""

from ensembl.production.xrefs.parsers.BaseParser import *


class MIMParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        general_source_id = args["source_id"]
        species_id        = args["species_id"]
        file              = args["file"]
        xref_dbi          = args["xref_dbi"]
        verbose           = args.get("verbose", False)

        if not general_source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        old_to_new, removed = {}, {}
        sources = []

        sources.append(general_source_id)

        gene_source_id = self.get_source_id_for_source_name("MIM_GENE", xref_dbi)
        sources.append(gene_source_id)
        morbid_source_id = self.get_source_id_for_source_name("MIM_MORBID", xref_dbi)
        sources.append(morbid_source_id)

        TYPE_SINGLE_SOURCES = {
            "*": gene_source_id,
            "": morbid_source_id,
            "#": morbid_source_id,
            "%": morbid_source_id,
        }

        counters = {gene_source_id: 0, morbid_source_id: 0, "removed": 0, "synonyms": 0}

        if verbose:
            logging.info("Sources are: " + ", ".join(map(str, sources)))

        for section in self.get_file_sections(file, "*RECORD*"):
            if len(section) == 1:
                continue

            record = "".join(section)

            # Extract the TI field
            ti = self.extract_ti(record)
            if not ti:
                raise IOError("Failed to extract TI field from record")

            # Extract record type
            (record_type, number, long_desc) = self.parse_ti(ti)
            if record_type is None:
                raise IOError(
                    "Failed to extract record type and description from TI field"
                )

            # Use the first block of text as description
            fields = re.split(";;", long_desc, flags=re.MULTILINE | re.DOTALL)
            label = fields[0]
            label = f"{label} [{record_type}{number}]"

            xref_object = {
                "accession": number,
                "label": label,
                "description": long_desc,
                "species_id": species_id,
                "info_type": "UNMAPPED",
            }

            if TYPE_SINGLE_SOURCES.get(record_type):
                type_source = TYPE_SINGLE_SOURCES[record_type]
                xref_object["source_id"] = type_source
                counters[type_source] += 1

                xref_id = self.add_xref(xref_object, xref_dbi)
            elif record_type == "+":
                # This type means both gene and phenotype, add both
                xref_object["source_id"] = gene_source_id
                counters[gene_source_id] += 1
                xref_id = self.add_xref(xref_object, xref_dbi)

                xref_object["source_id"] = morbid_source_id
                counters[morbid_source_id] += 1
                xref_id = self.add_xref(xref_object, xref_dbi)
            elif record_type == "^":
                match = re.search(
                    r"MOVED\sTO\s(\d+)", long_desc, flags=re.MULTILINE | re.DOTALL
                )
                if match:
                    new_number = match.group(1)
                    if new_number != number:
                        old_to_new[number] = new_number
                elif long_desc == "REMOVED FROM DATABASE":
                    removed[number] = 1
                    counters["removed"] += 1
                else:
                    raise IOError(f"Unsupported type of a '^' record: '{long_desc}'")

        # Generate synonyms from "MOVED TO" entries
        for old, new in old_to_new.items():
            # Some entries in the MIM database have been moved multiple times
            # Keep traversing the chain of renames until we have reached the end
            while old_to_new.get(new):
                new = old_to_new[new]

            # Check if the entry has been removed from the database
            if not removed.get(new):
                self.add_to_syn_for_mult_sources(
                    new, sources, old, species_id, xref_dbi
                )
                counters["synonyms"] += 1

        result_message = "%d genemap and %d phenotype MIM xrefs added\n" % (
            counters[gene_source_id],
            counters[morbid_source_id],
        )
        result_message += (
            "\t%d synonyms (defined by MOVED TO) added\n" % counters["synonyms"]
        )
        result_message += "\t%d entries removed" % counters["removed"]

        return 0, result_message

    def extract_ti(self, input_record: str) -> str:
        ti = None

        match = re.search(
            r"[*]FIELD[*]\sTI\n(.+?)\n?(?:[*]FIELD[*]| [*]RECORD[*]| [*]THEEND[*])",
            input_record,
            flags=re.MULTILINE | re.DOTALL,
        )
        if match:
            ti = match.group(1)

        return ti

    def parse_ti(self, ti: str) -> Tuple[Optional[str], Optional[str], Optional[str]]:
        ti = re.sub(r"(?:;;\n|\n;;)", ";;", ti, flags=re.MULTILINE | re.DOTALL)
        ti = re.sub(r"\n", "", ti, flags=re.MULTILINE | re.DOTALL)

        match = re.search(r"\A([#%+*^]*)(\d+)\s+(.+)", ti)
        if match:
            return match.group(1), match.group(2), match.group(3)

        return None, None, None
