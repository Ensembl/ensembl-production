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

"""Parser module for RefSeq coordinate xrefs."""

import json
import logging
import subprocess
from typing import Any, Dict, Tuple
from sqlalchemy.engine import Connection

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class RefSeqCoordinateParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        species_name = args.get("species_name")
        db_url = args.get("extra_db_url")
        xref_dbi = args.get("xref_dbi")
        verbose = args.get("verbose", False)

        if not source_id or not species_id:
            raise AttributeError("Missing required arguments: source_id and species_id")

        source_ids = self.get_source_ids(verbose, xref_dbi)

        # Get the species name(s)
        species_id_to_names = self.species_id_to_names(xref_dbi)
        if species_name:
            species_id_to_names.setdefault(species_id, []).append(species_name)

        if not species_id_to_names.get(species_id):
            return 0, "Skipped. Could not find species ID to name mapping."
        species_name = species_id_to_names[species_id][0]

        # Connect to the appropriate dbs
        if db_url:
            return self.run_perl_script(args, source_ids, species_name)
        else:
            # Not all species have an otherfeatures database, skip if not found
            return 0, f"Skipped. No otherfeatures database for '{species_name}'."

    def get_source_ids(self, verbose: bool, xref_dbi: Connection) -> Dict[str, int]:
        source_ids = {
            "peptide": self.get_source_id_for_source_name("RefSeq_peptide", xref_dbi, "otherfeatures"),
            "mrna": self.get_source_id_for_source_name("RefSeq_mRNA", xref_dbi, "otherfeatures"),
            "ncrna": self.get_source_id_for_source_name("RefSeq_ncRNA", xref_dbi, "otherfeatures"),
            "peptide_predicted": self.get_source_id_for_source_name("RefSeq_peptide_predicted", xref_dbi, "otherfeatures"),
            "mrna_predicted": self.get_source_id_for_source_name("RefSeq_mRNA_predicted", xref_dbi, "otherfeatures"),
            "ncrna_predicted": self.get_source_id_for_source_name("RefSeq_ncRNA_predicted", xref_dbi, "otherfeatures"),
            "entrezgene": self.get_source_id_for_source_name("EntrezGene", xref_dbi),
            "wikigene": self.get_source_id_for_source_name("WikiGene", xref_dbi),
        }

        if verbose:
            logging.info(f'RefSeq_peptide source ID = {source_ids["peptide"]}')
            logging.info(f'RefSeq_mRNA source ID = {source_ids["mrna"]}')
            logging.info(f'RefSeq_ncRNA source ID = {source_ids["ncrna"]}')
            logging.info(f'RefSeq_peptide_predicted source ID = {source_ids["peptide_predicted"]}')
            logging.info(f'RefSeq_mRNA_predicted source ID = {source_ids["mrna_predicted"]}')
            logging.info(f'RefSeq_ncRNA_predicted source ID = {source_ids["ncrna_predicted"]}')
        
        return source_ids

    def run_perl_script(self, args: Dict[str, Any], source_ids: Dict[str, int], species_name: str) -> Tuple[int, str]:
        # For now, we run a perl script to add the xrefs, which has some mandatory arguments
        scripts_dir = args.get("perl_scripts_dir")
        xref_db_url = args.get("xref_db_url")
        if not scripts_dir or not xref_db_url:
            raise AttributeError("Missing required arguments: perl_scripts_dir and xref_db_url")

        source_ids_json = json.dumps(source_ids)

        logging.info(f"Running perl script {scripts_dir}/refseq_coordinate_parser.pl")
        perl_cmd = (
            "perl",
            f"{scripts_dir}/refseq_coordinate_parser.pl"
            f"--xref_db_url", xref_db_url
            f"--core_db_url", args.get('core_db_url'),
            f"--otherf_db_url", args.get('extra_db_url'),
            f"--source_ids", source_ids_json,
            f"--species_id", str(species_id),
            f"--species_name", species_name
            f"--release", str(args.get('ensembl_release'))
        )
        cmd_output = subprocess.run(perl_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        if cmd_output.returncode != 0:
            logging.error(f"Perl script ({scripts_dir}/refseq_coordinate_parser.pl) failed with error: {cmd_output.stderr.decode('utf-8')}")
            return 1, "Failed to add refseq_import xrefs."

        return 0, "Added refseq_import xrefs."
