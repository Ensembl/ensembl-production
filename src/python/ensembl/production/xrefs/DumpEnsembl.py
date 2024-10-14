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

"""Dumping module to dump sequence data from a core db."""

from ensembl.production.xrefs.Base import *


class DumpEnsembl(Base):
    def run(self):
        species_name = self.param_required("species_name", {"type": "str"})
        base_path    = self.param_required("base_path", {"type": "str"})
        release      = self.param_required("release", {"type": "int"})
        core_db_url  = self.param_required("species_db", {"type": "str"})
        xref_db_url  = self.param_required("xref_db_url", {"type": "str"})
        retry        = self.param("retry", None, {"type": "bool", "default": False})

        logging.info(f"DumpEnsembl starting for species '{species_name}'")

        # Create files paths
        cdna_path = self.get_path(
            base_path, species_name, release, "ensembl", "transcripts.fa"
        )
        pep_path = self.get_path(
            base_path, species_name, release, "ensembl", "peptides.fa"
        )

        # Check if dumping has been done for this run before, to speed up development by not having to re-dump sequences
        if (
            not retry
            and os.path.exists(cdna_path)
            and os.path.getsize(cdna_path) > 0
            and os.path.exists(pep_path)
            and os.path.getsize(pep_path) > 0
        ):
            logging.info(
                f"Dna and peptide data already dumped for species '{species_name}', skipping."
            )
        else:
            scripts_dir = self.param_required("perl_scripts_dir")

            logging.info(f"Running perl script {scripts_dir}/dump_ensembl.pl")
            perl_cmd = f"perl {scripts_dir}/dump_ensembl.pl --cdna_path '{cdna_path}' --pep_path '{pep_path}' --species {species_name} --core_db_url '{core_db_url}' --release {release}"
            cmd_output = subprocess.run(perl_cmd, shell=True, stdout=subprocess.PIPE)

        # Create jobs for peptide dumping and alignment
        dataflow_params = {
            "species_name": species_name,
            "file_path": pep_path,
            "xref_db_url": xref_db_url,
            "seq_type": "peptide",
        }
        self.write_output("dump_xref", dataflow_params)

        # Create jobs for cdna dumping and alignment
        dataflow_params = {
            "species_name": species_name,
            "file_path": cdna_path,
            "xref_db_url": xref_db_url,
            "seq_type": "dna",
        }
        self.write_output("dump_xref", dataflow_params)

        # Create job for schedule mapping
        dataflow_params = {
            "species_name": species_name,
            "xref_db_url": xref_db_url,
            "species_db": core_db_url,
        }
        self.write_output("schedule_mapping", dataflow_params)
