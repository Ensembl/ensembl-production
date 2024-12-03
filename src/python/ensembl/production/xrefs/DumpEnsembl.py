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

import os
import subprocess
import logging

from ensembl.production.xrefs.Base import Base

class DumpEnsembl(Base):
    def run(self):
        species_name: str = self.get_param("species_name", {"required": True, "type": str})
        base_path: str = self.get_param("base_path", {"required": True, "type": str})
        release: int = self.get_param("release", {"required": True, "type": int})
        core_db_url: str = self.get_param("species_db", {"required": True, "type": str})
        xref_db_url: str = self.get_param("xref_db_url", {"required": True, "type": str})
        retry: bool = self.get_param("retry", {"type": bool, "default": False})

        logging.info(f"DumpEnsembl starting for species '{species_name}'")

        # Create file paths
        cdna_path = self.get_path(base_path, species_name, release, "ensembl", "transcripts.fa")
        pep_path = self.get_path(base_path, species_name, release, "ensembl", "peptides.fa")

        # Check if dumping has been done for this run before, to speed up development by not having to re-dump sequences
        if not retry and os.path.exists(cdna_path) and os.path.getsize(cdna_path) > 0 and os.path.exists(pep_path) and os.path.getsize(pep_path) > 0:
            logging.info(f"Dna and peptide data already dumped for species '{species_name}', skipping.")
        else:
            scripts_dir: str = self.get_param("perl_scripts_dir", {"required": True, "type": str})

            logging.info(f"Running perl script {scripts_dir}/dump_ensembl.pl")
            perl_cmd = [
                "perl",
                f"{scripts_dir}/dump_ensembl.pl",
                "--cdna_path", cdna_path,
                "--pep_path", pep_path,
                "--species", species_name,
                "--core_db_url", core_db_url,
                "--release", str(release)
            ]
            # subprocess.run(perl_cmd, check=True, stdout=subprocess.PIPE)
            subprocess.run(perl_cmd, capture_output=True, text=True, check=True)

        # Create jobs for peptide dumping and alignment
        self.write_output("dump_xref", {
            "species_name": species_name,
            "file_path": pep_path,
            "xref_db_url": xref_db_url,
            "seq_type": "peptide",
        })

        # Create jobs for cdna dumping and alignment
        self.write_output("dump_xref", {
            "species_name": species_name,
            "file_path": cdna_path,
            "xref_db_url": xref_db_url,
            "seq_type": "dna",
        })

        # Create job for schedule mapping
        self.write_output("schedule_mapping", {
            "species_name": species_name,
            "xref_db_url": xref_db_url,
            "species_db": core_db_url,
        })
