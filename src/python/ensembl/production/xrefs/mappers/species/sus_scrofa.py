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

"""Mapper extension module for species sus_scrofa."""

from ensembl.production.xrefs.mappers.BasicMapper import BasicMapper
from ensembl.production.xrefs.mappers.DisplayXrefs import DisplayXrefs

class sus_scrofa(BasicMapper):
    def official_name(self) -> str:
        return "PIGGY"

    def set_transcript_names(self) -> None:
        return None

    def set_display_xrefs(self) -> None:
        display = DisplayXrefs(self)
        display.set_display_xrefs_from_stable_table()
