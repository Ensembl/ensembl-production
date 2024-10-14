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

"""Parser module for MIM to Gene source."""

from ensembl.production.xrefs.parsers.BaseParser import *

EXPECTED_NUMBER_OF_COLUMNS = 6


class Mim2GeneParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        general_source_id = args["source_id"]
        species_id        = args["species_id"]
        file              = args["file"]
        xref_dbi          = args["xref_dbi"]
        verbose           = args.get("verbose", False)

        if not general_source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        # Get needed source IDs
        mim_gene_source_id = self.get_source_id_for_source_name("MIM_GENE", xref_dbi)
        mim_morbid_source_id = self.get_source_id_for_source_name(
            "MIM_MORBID", xref_dbi
        )
        entrez_source_id = self.get_source_id_for_source_name("EntrezGene", xref_dbi)

        # This will be used to prevent insertion of duplicates
        self.build_dependent_mappings(mim_gene_source_id, xref_dbi)
        self.build_dependent_mappings(mim_morbid_source_id, xref_dbi)

        mim_gene = self.get_valid_codes("MIM_GENE", species_id, xref_dbi)
        mim_morbid = self.get_valid_codes("MIM_MORBID", species_id, xref_dbi)
        entrez = self.get_valid_codes("EntrezGene", species_id, xref_dbi)

        counters = {
            "all_entries": 0,
            "dependent_on_entrez": 0,
            "missed_master": 0,
            "missed_omim": 0,
        }

        file_io = self.get_filehandle(file)
        csv_reader = csv.reader(file_io, delimiter="\t")

        # Read lines
        for line in csv_reader:
            if not line:
                continue

            # Extract the header from among the comments
            match = re.search(r"\A([#])?", line[0])
            if match:
                is_comment = match.group(1)
                if is_comment:
                    patterns = [
                        r"\A[#]?\s*MIM[ ]number",
                        "GeneID",
                        "type",
                        "Source",
                        "MedGenCUI",
                        "Comment",
                    ]
                    if len(
                        line
                    ) == EXPECTED_NUMBER_OF_COLUMNS and not self.is_file_header_valid(
                        EXPECTED_NUMBER_OF_COLUMNS, patterns, line, True
                    ):
                        raise IOError(
                            f"Malformed or unexpected header in Mim2Gene file {file}"
                        )
                    continue

            if len(line) != EXPECTED_NUMBER_OF_COLUMNS:
                raise IOError(
                    f"Line {csv_reader.line_num} of input file {file} has an incorrect number of columns"
                )

            fields = [re.sub(r"\s+\Z", "", x) for x in line]
            omim_acc = fields[0]
            entrez_id = fields[1]
            type = fields[2]
            source = fields[3]
            medgen = fields[4]
            comment = fields[5]

            counters["all_entries"] += 1

            # No point in doing anything if we have no matching MIM xref ...
            if omim_acc not in mim_gene and omim_acc not in mim_morbid:
                counters["missed_omim"] += 1
                continue

            # ...or no EntrezGene xref to match it to
            if not entrez_id or entrez_id not in entrez:
                counters["missed_master"] += 1
                continue

            # Check if type is known
            if verbose and type not in [
                "gene",
                "gene/phenotype",
                "predominantly phenotypes",
                "phenotype",
            ]:
                logging.warn(
                    f"Unknown type {type} for MIM Number {omim_acc} ({file}:{csv_reader.line_num})"
                )

            # With all the checks taken care of, insert the mappings. We check
            # both MIM_GENE and MIM_MORBID every time because some MIM entries
            # can appear in both.
            if omim_acc in mim_gene:
                for mim_xref_id in mim_gene[omim_acc]:
                    counters["dependent_on_entrez"] += self.process_xref_entry(
                        {
                            "mim_xref_id": mim_xref_id,
                            "mim_source_id": mim_gene_source_id,
                            "entrez_xrefs": entrez[entrez_id],
                            "entrez_source_id": entrez_source_id,
                        },
                        xref_dbi,
                    )
            if omim_acc in mim_morbid:
                for mim_xref_id in mim_morbid[omim_acc]:
                    counters["dependent_on_entrez"] += self.process_xref_entry(
                        {
                            "mim_xref_id": mim_xref_id,
                            "mim_source_id": mim_morbid_source_id,
                            "entrez_xrefs": entrez[entrez_id],
                            "entrez_source_id": entrez_source_id,
                        },
                        xref_dbi,
                    )

        file_io.close()

        result_message = (
            "Processed %d entries. Out of those\n" % counters["all_entries"]
        )
        result_message += "\t%d had missing OMIM entries,\n" % counters["missed_omim"]
        result_message += (
            "\t%d were dependent EntrezGene xrefs,\n" % counters["dependent_on_entrez"]
        )
        result_message += "\t%d had missing master entries." % counters["missed_master"]

        return 0, result_message

    def process_xref_entry(self, args: Dict[str, Any], dbi: Connection) -> int:
        count = 0

        for ent_id in args["entrez_xrefs"]:
            self.add_dependent_xref_maponly(
                args["mim_xref_id"], args["mim_source_id"], ent_id, None, dbi, True
            )
            count += 1

        return count
