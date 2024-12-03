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

"""Xref module to print out advisory datachecks results (only needed now since we are still using perl datachecks)."""

import re

from ensembl.production.xrefs.Base import Base

class AdvisoryXrefReport(Base):
    def run(self):
        base_path: str = self.get_param("base_path", {"required": True, "type": str})
        species_name: str = self.get_param("species_name", {"required": True, "type": str})
        release: int = self.get_param("release", {"required": True, "type": int})
        datacheck_name: str = self.get_param("datacheck_name", {"type": str})
        datacheck_output: str = self.get_param("datacheck_output", {"type": str})

        # Create or locate report file
        report_file = self.get_path(
            base_path, species_name, release, "dc_report", f"{datacheck_name}.log"
        )

        # Return the quotation marks into the output
        datacheck_output = re.sub("__", "'", datacheck_output)

        # Write datacheck result into file
        with open(report_file, "a") as fh:
            fh.write(datacheck_output)
            fh.write("\n")
