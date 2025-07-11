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

import csv
import re
import logging
from typing import Any, Dict, Tuple
from sqlalchemy.engine import Connection

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class Mim2GeneParser(BaseParser):
    EXPECTED_NUMBER_OF_COLUMNS = 6

    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        general_source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")
        verbose = args.get("verbose", False)

        if not general_source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        counters = {
            "all_entries": 0,
            "dependent_on_entrez": 0,
            "missed_master": 0,
            "missed_omim": 0,
        }

        with self.get_filehandle(xref_file) as file_io:
            if file_io.read(1) == '':
                raise IOError(f"Mim2Gene file is empty")
            file_io.seek(0)

            csv_reader = csv.reader(file_io, delimiter="\t")

            self.process_lines(csv_reader, xref_file, species_id, counters, verbose, xref_dbi) 

        result_message = (
            f"Processed {counters['all_entries']} entries. Out of those\n"
            f"\t{counters['missed_omim']} had missing OMIM entries,\n"
            f"\t{counters['dependent_on_entrez']} were dependent EntrezGene xrefs,\n"
            f"\t{counters['missed_master']} had missing master entries."
        )
        # result_message = f"all={counters['all_entries']} -- missed_omim={counters['missed_omim']} -- dependent_on_entrez={counters['dependent_on_entrez']} -- missed_master={counters['missed_master']}"

        return 0, result_message

    def process_lines(self, csv_reader: csv.reader, xref_file:str, species_id: int, counters: Dict[str, int], verbose: bool, xref_dbi: Connection) -> None:
        # Get needed source IDs
        mim_gene_source_id = self.get_source_id_for_source_name("MIM_GENE", xref_dbi)
        mim_morbid_source_id = self.get_source_id_for_source_name("MIM_MORBID", xref_dbi)
        entrez_source_id = self.get_source_id_for_source_name("EntrezGene", xref_dbi)

        # This will be used to prevent insertion of duplicates
        self.build_dependent_mappings(mim_gene_source_id, xref_dbi)
        self.build_dependent_mappings(mim_morbid_source_id, xref_dbi)

        mim_gene = self.get_acc_to_xref_ids("MIM_GENE", species_id, xref_dbi)
        mim_morbid = self.get_acc_to_xref_ids("MIM_MORBID", species_id, xref_dbi)
        entrez = self.get_acc_to_xref_ids("EntrezGene", species_id, xref_dbi)

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
                        r"^GeneID$",
                        r"^type$",
                        r"^Source$",
                        r"^MedGenCUI$",
                        r"^Comment$",
                    ]
                    if not self.is_file_header_valid(self.EXPECTED_NUMBER_OF_COLUMNS, patterns, line, True):
                        raise ValueError(f"Malformed or unexpected header in Mim2Gene file {xref_file}")
                    continue

            if len(line) != self.EXPECTED_NUMBER_OF_COLUMNS:
                raise ValueError(f"Line {csv_reader.line_num} of input file has an incorrect number of columns")

            fields = [re.sub(r"\s+\Z", "", x) for x in line]
            omim_acc, entrez_id, type = fields[:3]

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
            if verbose and type not in ["gene", "gene/phenotype", "predominantly phenotypes", "phenotype"]:
                logging.warning(f"Unknown type {type} for MIM Number {omim_acc} ({xref_file}:{csv_reader.line_num})")

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

    def process_xref_entry(self, args: Dict[str, Any], dbi: Connection) -> int:
        count = 0
        for ent_id in args["entrez_xrefs"]:
            self.add_dependent_xref_maponly(
                args["mim_xref_id"], args["mim_source_id"], ent_id, None, dbi, True
            )
            count += 1
        return count
