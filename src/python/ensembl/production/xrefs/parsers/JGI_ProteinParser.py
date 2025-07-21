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

"""Parser module for JGI source."""

import re
from Bio import SeqIO
from typing import Dict, Any, Tuple

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class JGI_ProteinParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        xrefs = []

        with self.get_filehandle(xref_file) as file_io:
            if file_io.read(1) == '':
                raise IOError(f"JGIProtein file is empty")
            file_io.seek(0)

            fasta_sequences = SeqIO.parse(file_io, "fasta")

            for fasta in fasta_sequences:
                accession = fasta.id
                sequence = str(fasta.seq)

                # Extract accession value
                match = re.search(r"^ci0100(\w+?)$", accession)
                if not match:
                    continue
                accession = match.group(1)

                # Build an xref object and store it
                xref = {
                    "ACCESSION": accession,
                    "SEQUENCE": sequence,
                    "SOURCE_ID": source_id,
                    "SPECIES_ID": species_id,
                    "SEQUENCE_TYPE": "peptide",
                    "INFO_TYPE": "SEQUENCE_MATCH",
                }
                xrefs.append(xref)

        self.add_xref_objects(xrefs, xref_dbi)

        result_message = f"{len(xrefs)} JGI_ xrefs successfully parsed"

        return 0, result_message
