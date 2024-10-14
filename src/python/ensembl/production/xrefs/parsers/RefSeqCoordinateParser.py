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

from ensembl.production.xrefs.parsers.BaseParser import *
from ensembl.common.RangeRegistry import RangeRegistry


class RefSeqCoordinateParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id       = args["source_id"]
        species_id      = args["species_id"]
        species_name    = args["species_name"]
        file            = args["file"]
        dba             = args["dba"]
        ensembl_release = args["ensembl_release"]
        xref_dbi        = args["xref_dbi"]
        verbose         = args.get("verbose", False)

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        source_ids = {
            "peptide": self.get_source_id_for_source_name(
                "RefSeq_peptide", xref_dbi, "otherfeatures"
            ),
            "mrna": self.get_source_id_for_source_name(
                "RefSeq_mRNA", xref_dbi, "otherfeatures"
            ),
            "ncrna": self.get_source_id_for_source_name(
                "RefSeq_ncRNA", xref_dbi, "otherfeatures"
            ),
            "peptide_predicted": self.get_source_id_for_source_name(
                "RefSeq_peptide_predicted", xref_dbi, "otherfeatures"
            ),
            "mrna_predicted": self.get_source_id_for_source_name(
                "RefSeq_mRNA_predicted", xref_dbi, "otherfeatures"
            ),
            "ncrna_predicted": self.get_source_id_for_source_name(
                "RefSeq_ncRNA_predicted", xref_dbi, "otherfeatures"
            ),
            "entrezgene": self.get_source_id_for_source_name("EntrezGene", xref_dbi),
            "wikigene": self.get_source_id_for_source_name("WikiGene", xref_dbi),
        }

        if verbose:
            logging.info(f'RefSeq_peptide source ID = {source_ids["peptide"]}')
            logging.info(f'RefSeq_mRNA source ID = {source_ids["mrna"]}')
            logging.info(f'RefSeq_ncRNA source ID = {source_ids["ncrna"]}')
            logging.info(
                f'RefSeq_peptide_predicted source ID = {source_ids["peptide_predicted"]}'
            )
            logging.info(
                f'RefSeq_mRNA_predicted source ID = {source_ids["mrna_predicted"]}'
            )
            logging.info(
                f'RefSeq_ncRNA_predicted source ID = {source_ids["ncrna_predicted"]}'
            )

        # Get the species name(s)
        species_id_to_names = self.species_id_to_names(xref_dbi)
        if species_name:
            species_id_to_names.setdefault(species_id, []).append(species_name)

        if not species_id_to_names.get(species_id):
            return 0, "Skipped. Could not find species ID to name mapping."
        species_name = species_id_to_names[species_id][0]

        # Connect to the appropriate dbs
        if dba:
            scripts_dir = args["perl_scripts_dir"]
            xref_db_url = args["xref_db_url"]
            source_ids_json = json.dumps(source_ids)

            logging.info(
                f"Running perl script {scripts_dir}/refseq_coordinate_parser.pl"
            )
            perl_cmd = f"perl {scripts_dir}/refseq_coordinate_parser.pl --xref_db_url '{xref_db_url}' --core_db_url '{args['core_db_url']}' --otherf_db_url '{dba}' --source_ids '{source_ids_json}' --species_id {species_id} --species_name {species_name} --release {ensembl_release}"
            cmd_output = subprocess.run(perl_cmd, shell=True, stdout=subprocess.PIPE)

            return 0, "Added refseq_import xrefs."
        else:
            # Not all species have an otherfeatures database, skip if not found
            return 0, f"Skipped. No otherfeatures database for '{species_name}'."
