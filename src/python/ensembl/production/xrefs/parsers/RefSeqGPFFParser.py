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

"""Parser module for RefSeq sources (dna and peptide)."""

from ensembl.production.xrefs.parsers.BaseParser import *


class RefSeqGPFFParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id    = args["source_id"]
        species_id   = args["species_id"]
        species_name = args["species_name"]
        file         = args["file"]
        release_file = args["rel_file"]
        xref_dbi     = args["xref_dbi"]
        verbose      = args.get("verbose", False)

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        # Get needed source ids
        source_ids = {
            "peptide_source_id": self.get_source_id_for_source_name(
                "RefSeq_peptide", xref_dbi
            ),
            "mrna_source_id": self.get_source_id_for_source_name(
                "RefSeq_mRNA", xref_dbi, "refseq"
            ),
            "ncrna_source_id": self.get_source_id_for_source_name(
                "RefSeq_ncRNA", xref_dbi
            ),
            "pred_peptide_source_id": self.get_source_id_for_source_name(
                "RefSeq_peptide_predicted", xref_dbi
            ),
            "pred_mrna_source_id": self.get_source_id_for_source_name(
                "RefSeq_mRNA_predicted", xref_dbi, "refseq"
            ),
            "pred_ncrna_source_id": self.get_source_id_for_source_name(
                "RefSeq_ncRNA_predicted", xref_dbi
            ),
            "entrez_source_id": self.get_source_id_for_source_name(
                "EntrezGene", xref_dbi
            ),
            "wiki_source_id": self.get_source_id_for_source_name("WikiGene", xref_dbi),
        }

        if verbose:
            logging.info(
                f'RefSeq_peptide source ID = {source_ids["peptide_source_id"]}'
            )
            logging.info(f'RefSeq_mRNA source ID = {source_ids["mrna_source_id"]}')
            logging.info(f'RefSeq_ncRNA source ID = {source_ids["ncrna_source_id"]}')
            logging.info(
                f'RefSeq_peptide_predicted source ID = {source_ids["pred_peptide_source_id"]}'
            )
            logging.info(
                f'RefSeq_mRNA_predicted source ID = {source_ids["pred_mrna_source_id"]}'
            )
            logging.info(
                f'RefSeq_ncRNA_predicted source ID = {source_ids["pred_ncrna_source_id"]}'
            )
            logging.info(f'EntrezGene source ID = {source_ids["entrez_source_id"]}')
            logging.info(f'WikiGene source ID = {source_ids["wiki_source_id"]}')

        # Extract version from release file
        if release_file:
            # Parse and set release info
            index = 0
            for section in self.get_file_sections(release_file, "***"):
                index += 1
                if index == 2:
                    release = "".join(section)
                    release = re.sub(r"\s{2,}", " ", release)
                    release = release.strip()
                    release = re.sub(
                        r".*(NCBI Reference Sequence.*) Distribution.*", r"\1", release
                    )
                    release = re.sub(r"Release (\d+)", r"Release \1,", release)
                    break

            # Set releases
            self.set_release(source_ids["peptide_source_id"], release, xref_dbi)
            self.set_release(source_ids["mrna_source_id"], release, xref_dbi)
            self.set_release(source_ids["ncrna_source_id"], release, xref_dbi)
            self.set_release(source_ids["pred_mrna_source_id"], release, xref_dbi)
            self.set_release(source_ids["pred_ncrna_source_id"], release, xref_dbi)
            self.set_release(source_ids["pred_peptide_source_id"], release, xref_dbi)

        result_message = self.create_xrefs(
            source_ids, species_id, species_name, file, xref_dbi
        )

        return 0, result_message

    def create_xrefs(self, source_ids: Dict[str, int], species_id: int, species_name: str, file: str, dbi: Connection) -> str:
        counts = {
            "num_mrna": 0,
            "num_ncrna": 0,
            "num_pred_mrna": 0,
            "num_pred_ncrna": 0,
            "num_peptide": 0,
            "num_pred_peptide": 0,
            "num_entrez": 0,
            "num_wiki": 0,
        }

        # Create a dict of all valid names for this species
        species_id_to_names = self.species_id_to_names(dbi)
        if species_name:
            species_id_to_names.setdefault(species_id, []).append(species_name)
        if not species_id_to_names.get(species_id):
            return "Skipped. Could not find species ID to name mapping"
        names = species_id_to_names[species_id]
        name_to_species_id = {name: species_id for name in names}

        # Create a dict of all valid taxon_ids for this species
        species_id_to_tax = self.species_id_to_taxonomy(dbi)
        species_id_to_tax.setdefault(species_id, []).append(species_id)
        tax_ids = species_id_to_tax[species_id]
        tax_to_species_id = {tax_id: species_id for tax_id in tax_ids}

        # Retrieve existing RefSeq mRNA, EntrezGene, and WikiGene xrefs
        entrez_acc_to_label = self.get_acc_to_label("EntrezGene", species_id, dbi)
        refseq_ids = self.get_valid_codes("RefSeq_mRNA", species_id, dbi)
        refseq_ids.update(
            self.get_valid_codes("RefSeq_mRNA_predicted", species_id, dbi)
        )
        entrez_ids = self.get_valid_codes("EntrezGene", species_id, dbi)
        wiki_ids = self.get_valid_codes("WikiGene", species_id, dbi)

        # Get file type
        file_type = self.type_from_file(os.path.basename(file))
        if not file_type:
            return f"Could not work out sequence type for {file}"

        xrefs = []

        # Read file
        for section in self.get_file_sections(file, "//\n"):
            if len(section) == 1:
                continue

            entry = "".join(section)
            xref = {}

            # Extract the species name
            species_id_check = None
            match = re.search(r"\s+ORGANISM\s+(.*)\n", entry)
            if match:
                species = match.group(1).lower()
                species = re.sub(r"^\s*", "", species)
                species = re.sub(r"\s*\(.+\)", "", species)
                species = re.sub(r"\s+", "_", species)
                species = re.sub(r"\n", "", species)

                species_id_check = name_to_species_id[species]

            # Try going through the taxon ID if species check didn't work
            if not species_id_check:
                match = re.search(r"db_xref=\"taxon:(\d+)\"", entry)
                if match:
                    taxon_id = match.group(1)
                    species_id_check = tax_to_species_id[taxon_id]

            # Skip xrefs for species that aren't in the species table
            if not species_id_check or species_id != species_id_check:
                continue

            # Extract accession and version
            accession = re.search(
                r"^ACCESSION\s+(\S+)", entry, flags=re.MULTILINE
            ).group(1)
            version = re.search(r"^VERSION\s+(\S+)", entry, flags=re.MULTILINE).group(1)

            # Get the right source ID based on file type and whether this is predicted (X*) or not
            source_id = 0
            if file_type == "dna":
                if re.search(r"^XM_", accession):
                    source_id = source_ids["pred_mrna_source_id"]
                    counts["num_pred_mrna"] += 1
                elif re.search(r"^XR", accession):
                    source_id = source_ids["pred_ncrna_source_id"]
                    counts["num_pred_ncrna"] += 1
                elif re.search(r"^NM", accession):
                    source_id = source_ids["mrna_source_id"]
                    counts["num_mrna"] += 1
                elif re.search(r"^NR", accession):
                    source_id = source_ids["ncrna_source_id"]
                    counts["num_ncrna"] += 1
            elif file_type == "peptide":
                if re.search(r"^XP_", accession):
                    source_id = source_ids["pred_peptide_source_id"]
                    counts["num_pred_peptide"] += 1
                else:
                    source_id = source_ids["peptide_source_id"]
                    counts["num_peptide"] += 1

            if not source_id:
                logging.warning(
                    f"Could not get source ID for file type {file_type} for accession {accession}"
                )

            (acc_no_version, version) = version.split(".")
            xref["ACCESSION"] = accession
            if accession == acc_no_version:
                xref["VERSION"] = version

            # Extract description (may be multi-line)
            description = re.search(
                r"^DEFINITION\s+([^[]+)", entry, flags=re.MULTILINE
            ).group(1)
            description = re.sub(r"\nACCESSION.*", "", description, flags=re.DOTALL)
            description = re.sub(r"\n", "", description)
            description = re.sub(r"{.*}-like", "", description)
            description = re.sub(r"{.*}", "", description)
            description = re.sub(r"\s+", " ", description)
            if len(description) > 255:
                description = description[0:255]

            # Extract sequence
            sequence = re.search(
                r"^\s*ORIGIN\s+(.+)", entry, flags=re.DOTALL | re.MULTILINE
            ).group(1)
            sequence_lines = sequence.split("\n")
            parsed_sequence = ""
            for seq_line in sequence_lines:
                if seq_line:
                    sequence_only = re.search(r"^\s*\d+\s+(.*)$", seq_line).group(1)
                    if not sequence_only:
                        continue
                    parsed_sequence += sequence_only
            parsed_sequence = re.sub(r"\s", "", parsed_sequence)

            # Extract related pair to current RefSeq accession
            # For rna file, the pair is the protein_id
            # For peptide file, the pair is in DBSOURCE REFSEQ accession
            refseq_pair = None
            match = re.search(r"DBSOURCE\s+REFSEQ: accession (\S+)", entry)
            if match:
                refseq_pair = match.group(1)
            protein_id = re.findall(r"\/protein_id=.(\S+_\d+)", entry)
            coded_by = re.findall(r"\/coded_by=.(\w+_\d+)", entry)

            for cb in coded_by:
                xref["PAIR"] = cb

            if not xref.get("PAIR"):
                xref["PAIR"] = refseq_pair

            if not xref.get("PAIR"):
                for pi in protein_id:
                    xref["PAIR"] = pi

            xref["LABEL"] = f"{accession}.{version}"
            xref["DESCRIPTION"] = description
            xref["SOURCE_ID"] = source_id
            xref["SEQUENCE"] = parsed_sequence
            xref["SEQUENCE_TYPE"] = file_type
            xref["SPECIES_ID"] = species_id
            xref["INFO_TYPE"] = "SEQUENCE_MATCH"
            xref["DEPENDENT_XREFS"] = []

            # Extrat NCBIGene ids
            seen_in_record = {}
            ncbi_gene_ids = re.findall(r"db_xref=.GeneID:(\d+)", entry)
            for gene_id in ncbi_gene_ids:
                if not seen_in_record.get(gene_id) and entrez_acc_to_label.get(gene_id):
                    seen_in_record[gene_id] = 1

                    dependent = {}
                    dependent["SOURCE_ID"] = source_ids["entrez_source_id"]
                    dependent["LINKAGE_SOURCE_ID"] = source_id
                    dependent["ACCESSION"] = gene_id
                    dependent["LABEL"] = entrez_acc_to_label[gene_id]
                    xref["DEPENDENT_XREFS"].append(dependent)
                    counts["num_entrez"] += 1

                    dependent = {}
                    dependent["SOURCE_ID"] = source_ids["wiki_source_id"]
                    dependent["LINKAGE_SOURCE_ID"] = source_id
                    dependent["ACCESSION"] = gene_id
                    dependent["LABEL"] = entrez_acc_to_label[gene_id]
                    xref["DEPENDENT_XREFS"].append(dependent)
                    counts["num_wiki"] += 1

                    # Add xrefs for RefSeq mRNA as well where available
                    if refseq_pair:
                        refseq_pair = re.sub(r"\.[0-9]*", "", refseq_pair)
                    if refseq_pair:
                        if refseq_ids.get(refseq_pair):
                            for refseq_id in refseq_ids[refseq_pair]:
                                for entrez_id in entrez_ids.get(gene_id):
                                    self.add_dependent_xref_maponly(
                                        entrez_id,
                                        source_ids["entrez_source_id"],
                                        refseq_id,
                                        None,
                                        dbi,
                                    )
                                for wiki_id in wiki_ids.get(gene_id):
                                    self.add_dependent_xref_maponly(
                                        wiki_id,
                                        source_ids["entrez_source_id"],
                                        refseq_id,
                                        None,
                                        dbi,
                                    )

            xrefs.append(xref)

        if len(xrefs) > 0:
            self.upload_xref_object_graphs(xrefs, dbi)

        result_message = f'Added {counts["num_mrna"]} mRNA xrefs, {counts["num_pred_mrna"]} predicted mRNA xrefs, {counts["num_ncrna"]} ncRNA xrefs, {counts["num_pred_ncrna"]} predicted ncRNA xrefs, {counts["num_peptide"]} peptide xrefs, and {counts["num_pred_peptide"]} predicted peptide xrefs\n'
        result_message += f"Added the following dependent xrefs:\n"
        result_message += f'\tEntrezGene\t{counts["num_entrez"]}\n'
        result_message += f'\tWikiGene\t{counts["num_wiki"]}\n'

        return result_message

    def type_from_file(self, file_name: str) -> Optional[str]:
        if re.search("RefSeq_protein", file_name):
            return "peptide"
        if re.search("rna", file_name):
            return "dna"
        if re.search("protein", file_name):
            return "peptide"

        return None
