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

"""Mapper extension module for species saccharomyces_cerevisiae."""

from typing import Dict, List, Tuple
from sqlalchemy.sql.expression import Select

from ensembl.production.xrefs.mappers.BasicMapper import BasicMapper

class saccharomyces_cerevisiae(BasicMapper):
    def gene_display_xref_sources(self) -> Tuple[List[str], Dict[str, Select]]:
        sources_list = ["SGD_GENE"]

        ignore_queries = {}

        return sources_list, ignore_queries

    def transcript_display_xref_sources(self) -> Tuple[List[str], Dict[str, Select]]:
        sources_list = ["SGD_TRANSCRIPT"]

        ignore_queries = {}

        return sources_list, ignore_queries

    def gene_description_sources(self) -> List[str]:
        sources_list = ["SGD_GENE"]

        return sources_list

    def gene_description_filter_regexps(self) -> List[str]:
        return []
