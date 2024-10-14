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

from ensembl.production.xrefs.parsers.BaseParser import *

from Bio import SeqIO


class JGI_ProteinParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args["source_id"]
        species_id = args["species_id"]
        file       = args["file"]
        xref_dbi   = args["xref_dbi"]

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        xrefs = []

        file_io = self.get_filehandle(file)
        fasta_sequences = SeqIO.parse(file_io, "fasta")

        for fasta in fasta_sequences:
            accession = fasta.id
            sequence = fasta.seq

            # Extract accession value
            accession = re.search(r"^ci0100(\w+?)$", accession).group(1)

            # Build an xref object and store it
            xref = {
                "ACCESSION": accession,
                "SEQUENCE": sequence,
                "SOURCE_ID": source_id,
                "SPECIES_ID": species_id,
                "SEQUENCE_TYPE": "peptide",
            }
            xrefs.append(xref)

        file_io.close()

        self.upload_xref_object_graphs(xrefs, xref_dbi)

        result_message = "%d JGI_ xrefs succesfully parsed" % len(xrefs)

        return 0, result_message
