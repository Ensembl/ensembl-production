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

"""Mapper extension module for species parasite."""

from typing import List

from ensembl.production.xrefs.mappers.BasicMapper import BasicMapper

class parasite(BasicMapper):
    def set_transcript_names(self) -> None:
        return None

    def gene_description_sources(self) -> List[str]:
        sources_list = [
            "RFAM",
            "RNAMMER",
            "TRNASCAN_SE",
            "miRBase",
            "HGNC",
            "IMGT/GENE_DB",
            "Uniprot/SWISSPROT",
            "RefSeq_peptide",
            "Uniprot/SPTREMBL",
        ]

        return sources_list

    def gene_description_filter_regexps(self) -> List[str]:
        regex = [
            r"^Uncharacterized protein\s*",
            r"^Putative uncharacterized protein\s*",
            r"^Hypothetical protein\s*",
        ]

        return regex
