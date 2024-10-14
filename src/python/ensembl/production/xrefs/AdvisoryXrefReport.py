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

from ensembl.production.xrefs.Base import *


class AdvisoryXrefReport(Base):
    def run(self):
        base_path        = self.param_required("base_path", {"type": "str"})
        species_name     = self.param_required("species_name", {"type": "str"})
        release          = self.param_required("release", {"type": "int"})
        datacheck_name   = self.param("datacheck_name", None, {"type": "str"})
        datacheck_output = self.param("datacheck_output", None, {"type": "str"})

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
