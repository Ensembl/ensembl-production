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

"""Parser module for DBASS sources."""

from ensembl.production.xrefs.parsers.BaseParser import *

EXPECTED_NUMBER_OF_COLUMNS = 23


class DBASSParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args.get("source_id")
        species_id = args.get("species_id")
        xref_file  = args.get("file")
        xref_dbi   = args.get("xref_dbi")

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Need to pass source_id, species_id and file")

        file_io = self.get_filehandle(xref_file)
        csv_reader = csv.reader(file_io)

        # Check if header is valid
        header = next(csv_reader)
        patterns = [r"^id$", r"^genesymbol$", None, r"^ensemblreference$"]
        if not self.is_file_header_valid(EXPECTED_NUMBER_OF_COLUMNS, patterns, header):
            raise IOError(f"Malformed or unexpected header in DBASS file {xref_file}")

        processed_count = 0
        unmapped_count = 0

        # Read lines
        for line in csv_reader:
            if not line:
                continue

            if len(line) < EXPECTED_NUMBER_OF_COLUMNS:
                line_number = 2 + processed_count + unmapped_count
                raise IOError(
                    f"Line {line_number} of input file {xref_file} has an incorrect number of columns"
                )

            dbass_gene_id = line[0]
            dbass_gene_name = line[1]
            dbass_full_name = line[2]
            ensembl_id = line[3]

            # Do not attempt to create unmapped xrefs. Checking truthiness is good
            # enough here because the only non-empty string evaluating as false is
            # not a valid Ensembl stable ID.
            if ensembl_id:
                # DBASS files list synonyms in two ways: either "FOO (BAR)" (with or
                # without space) or "FOO/BAR". Both forms are relevant to us.
                match = re.search(
                    r"(.*)\s?/\s?(.*)", dbass_gene_name, re.IGNORECASE | re.DOTALL
                )
                if match:
                    first_gene_name = match.group(1)
                    second_gene_name = match.group(2)
                else:
                    match = re.search(
                        r"(.*)\s?\((.*)\)", dbass_gene_name, re.IGNORECASE | re.DOTALL
                    )
                    if match:
                        first_gene_name = match.group(1)
                        second_gene_name = match.group(2)
                    else:
                        first_gene_name = dbass_gene_name
                        second_gene_name = None

                label = first_gene_name
                synonym = second_gene_name
                ensembl_type = "gene"
                version = "1"

                xref_id = self.add_xref(
                    {
                        "accession": dbass_gene_id,
                        "version": version,
                        "label": label,
                        "source_id": source_id,
                        "species_id": species_id,
                        "info_type": "DIRECT",
                    },
                    xref_dbi,
                )

                if synonym:
                    self.add_synonym(xref_id, synonym, xref_dbi)

                self.add_direct_xref(xref_id, ensembl_id, ensembl_type, "", xref_dbi)

                processed_count += 1
            else:
                unmapped_count += 1

        file_io.close()

        result_message = f"{processed_count} direct xrefs successfully processed\n"
        result_message += f"Skipped {unmapped_count} unmapped xrefs"

        return 0, result_message
