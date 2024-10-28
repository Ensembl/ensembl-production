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

import os
import re
import logging
from typing import Any, Dict, Optional, Tuple
from sqlalchemy.engine import Connection

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class RefSeqParser(BaseParser):
    ORGAMISM_PATTERN = re.compile(r"\s+ORGANISM\s+(.*)\n")
    TAXON_PATTERN = re.compile(r"db_xref=\"taxon:(\d+)\"")
    ACCESSION_PATTERN = re.compile(r"^ACCESSION\s+(\S+)", re.MULTILINE)
    VERSION_PATTERN = re.compile(r"^VERSION\s+(\S+)", re.MULTILINE)
    TYPE_PATTERNS = {
        "dna": {
            re.compile(r"^XM_"): ("num_pred_mrna", "pred_mrna_source_id"),
            re.compile(r"^XR"): ("num_pred_ncrna", "pred_ncrna_source_id"),
            re.compile(r"^NM"): ("num_mrna", "mrna_source_id"),
            re.compile(r"^NR"): ("num_ncrna", "ncrna_source_id"),
        },
        "peptide": {
            re.compile(r"^XP_"): ("num_pred_peptide", "pred_peptide_source_id"),
        }
    }
    DESCRIPTION_PATTERN = re.compile(r"^DEFINITION\s+(.+?)(?=\n\S)", re.DOTALL | re.MULTILINE)
    DESC_REMOVE_BRACES_PATTERN = re.compile(r"\{.*?\}-like|\{.*?\}")
    NORMALIZE_WHITESPACE_PATTERN = re.compile(r"\s+")
    SEQUENCE_PATTERN = re.compile(r"^\s*ORIGIN\s+(.+)", re.DOTALL | re.MULTILINE)
    SEQ_REMOVE_NUMBERS_PATTERN = re.compile(r"\d+\s+")
    PROTEIN_IDS_PATTERN = re.compile(r"\/protein_id=.(\S+_\d+)")
    CODED_BY_PATTERN = re.compile(r"\/coded_by=.(\w+_\d+)")
    DBSOURCE_PATTERN = re.compile(r"^DBSOURCE\s+REFSEQ: accession (\S+_\d+)")
    GENEID_PATTERN = re.compile(r"db_xref=.GeneID:(\d+)")

    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        species_name = args.get("species_name")
        xref_file = args.get("file")
        release_file = args.get("rel_file")
        xref_dbi = args.get("xref_dbi")
        verbose = args.get("verbose", False)

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        # Get needed source ids
        source_ids = {
            "peptide_source_id": self.get_source_id_for_source_name("RefSeq_peptide", xref_dbi),
            "mrna_source_id": self.get_source_id_for_source_name("RefSeq_mRNA", xref_dbi, "refseq"),
            "ncrna_source_id": self.get_source_id_for_source_name("RefSeq_ncRNA", xref_dbi),
            "pred_peptide_source_id": self.get_source_id_for_source_name("RefSeq_peptide_predicted", xref_dbi),
            "pred_mrna_source_id": self.get_source_id_for_source_name("RefSeq_mRNA_predicted", xref_dbi, "refseq"),
            "pred_ncrna_source_id": self.get_source_id_for_source_name("RefSeq_ncRNA_predicted", xref_dbi),
            "entrez_source_id": self.get_source_id_for_source_name("EntrezGene", xref_dbi),
            "wiki_source_id": self.get_source_id_for_source_name("WikiGene", xref_dbi),
        }

        if verbose:
            for key, value in source_ids.items():
                logging.info(f'{key} = {value}')

        # Extract version from release file
        if release_file:
            release = self.extract_release_info(release_file)

            if release:
                if verbose:
                    logging.info(f"RefSeq release info: {release}")

                for key in ["peptide_source_id", "mrna_source_id", "ncrna_source_id", "pred_mrna_source_id", "pred_ncrna_source_id", "pred_peptide_source_id"]:
                    self.set_release(source_ids[key], release, xref_dbi)

        result_message = self.create_xrefs(source_ids, species_id, species_name, xref_file, xref_dbi)
        return 0, result_message

    def extract_release_info(self, release_file: str) -> str:
        release_info = ""
        for section in self.get_file_sections(release_file, "***"):
            release_info = "".join(section)
            break

        match = re.search(r"(NCBI Reference Sequence.*?)(?=Distribution)", release_info, re.DOTALL)
        if match:
            release = " ".join(match.group(1).split())
            release = re.sub(r"Release (\d+)", r"Release \1,", release)
            return release
        
        return None

    def create_xrefs(self, source_ids: Dict[str, int], species_id: int, species_name: str, xref_file: str, dbi: Connection) -> str:
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

        # Get file type
        file_type = self.type_from_file(os.path.basename(xref_file))
        if not file_type:
            return f"Skipped. Could not work out sequence type for {xref_file}"

        # Retrieve existing RefSeq mRNA, EntrezGene, and WikiGene xrefs
        entrez_acc_to_label = self.get_acc_to_label("EntrezGene", species_id, dbi)
        refseq_ids = self.get_valid_codes("RefSeq_mRNA", species_id, dbi)
        refseq_ids.update(self.get_valid_codes("RefSeq_mRNA_predicted", species_id, dbi))
        entrez_ids = self.get_valid_codes("EntrezGene", species_id, dbi)
        wiki_ids = self.get_valid_codes("WikiGene", species_id, dbi)

        xrefs = []

        # Read file
        for section in self.get_file_sections(xref_file, "//\n"):
            entry = "".join(section)
            xref = {}

            # Extract the species name and check species ID
            species_id_check = self.check_species(entry, name_to_species_id, tax_to_species_id)

            # Skip xrefs for species that don't pass the check
            if not species_id_check or species_id != species_id_check:
                continue

            # Extract accession
            accession = self.ACCESSION_PATTERN.search(entry).group(1)
            xref["ACCESSION"] = accession

            # Get the right source ID based on file type and whether this is predicted (X*) or not
            source_id = self.get_source_id_for_accession(accession, file_type, source_ids, counts)
            # result_message += f"{accession}--{source_id}|"

            if not source_id:
                logging.warning(f"Could not get source ID for file type {file_type} for accession {accession}")
                continue

            # Extract and fix the version
            version = self.VERSION_PATTERN.search(entry).group(1)
            acc_no_version, version = version.split(".", 1) if "." in version else (version, None)
            if acc_no_version == accession and version is not None:
                xref["VERSION"] = version

            # Extract description (may be multi-line)
            description = self.extract_description(entry)

            # Extract sequence
            parsed_sequence = self.extract_sequence(entry)

            # Extract related pair to current RefSeq accession
            # - for rna file, the pair is the protein_id
            # - for peptide file, the pair is in DBSOURCE REFSEQ accession or in the coded_by
            xref["PAIR"] = self.extract_refseq_pair(file_type, entry)

            # Build the xref fields
            xref["LABEL"] = f"{accession}.{version}"
            xref["DESCRIPTION"] = description
            xref["SOURCE_ID"] = source_id
            xref["SEQUENCE"] = parsed_sequence
            xref["SEQUENCE_TYPE"] = file_type
            xref["SPECIES_ID"] = species_id
            xref["INFO_TYPE"] = "SEQUENCE_MATCH"
            xref["DEPENDENT_XREFS"] = []

            # Extract NCBIGene ids
            seen_in_record = {}
            ncbi_gene_ids = self.GENEID_PATTERN.findall(entry)
            for gene_id in ncbi_gene_ids:
                if gene_id not in seen_in_record and gene_id in entrez_acc_to_label:
                    seen_in_record[gene_id] = True
                    entrez_label = entrez_acc_to_label[gene_id]

                    self.add_dependents(xref, gene_id, source_ids, entrez_label, counts)

                    if file_type == "peptide" and xref['PAIR']:
                        if refseq_ids.get(xref['PAIR']):
                            for refseq_id in refseq_ids[xref['PAIR']]:
                                for entrez_id in entrez_ids.get(gene_id, []):
                                    self.add_dependent_xref_maponly(entrez_id, source_ids["entrez_source_id"], refseq_id, None, dbi)
                                for wiki_id in wiki_ids.get(gene_id, []):
                                    self.add_dependent_xref_maponly(wiki_id, source_ids["wiki_source_id"], refseq_id, None, dbi)

            xrefs.append(xref)

        if xrefs:
            self.upload_xref_object_graphs(xrefs, dbi)

        result_message = (
            f'Added {counts["num_mrna"]} mRNA xrefs, {counts["num_pred_mrna"]} predicted mRNA xrefs, '
            f'{counts["num_ncrna"]} ncRNA xrefs, {counts["num_pred_ncrna"]} predicted ncRNA xrefs, '
            f'{counts["num_peptide"]} peptide xrefs, and {counts["num_pred_peptide"]} predicted peptide xrefs\n'
            f'Added the following dependent xrefs:\n'
            f'\tEntrezGene\t{counts["num_entrez"]}\n'
            f'\tWikiGene\t{counts["num_wiki"]}\n'
        )

        return result_message

    def check_species(self, entry: str, name_to_species_id: Dict[str, int], tax_to_species_id: Dict[int, int]) -> Optional[int]:
        species_id_check = None

        match = self.ORGAMISM_PATTERN.search(entry)
        if match:
            species = match.group(1).lower().strip()
            species = re.sub(r"\s*\(.+\)", "", species)
            species = re.sub(r"\s+", "_", species)
            species_id_check = name_to_species_id.get(species)

        # Try going through the taxon ID if species check didn't work
        if not species_id_check:
            match = self.TAXON_PATTERN.search(entry)
            if match:
                taxon_id = int(match.group(1))
                species_id_check = tax_to_species_id.get(taxon_id)

        return species_id_check

    def get_source_id_for_accession(self, accession: str, file_type: str, source_ids: Dict[str, int], counts: Dict[str, int]) -> int:
        # Check for dna or peptide patterns
        if file_type in self.TYPE_PATTERNS:
            for pattern, (count_key, source_id_key) in self.TYPE_PATTERNS[file_type].items():
                if pattern.search(accession):
                    counts[count_key] += 1
                    return source_ids[source_id_key]

        # Default case for peptide
        if file_type == "peptide":
            counts["num_peptide"] += 1
            return source_ids["peptide_source_id"]

        return 0

    def extract_description(self, entry: str) -> str:
        description = self.DESCRIPTION_PATTERN.search(entry).group(1).strip()
        description = self.DESC_REMOVE_BRACES_PATTERN.sub("", description)
        description = self.NORMALIZE_WHITESPACE_PATTERN.sub(" ", description)

        return description[:255].strip()

    def extract_sequence(self, entry: str) -> str:
        sequence = self.SEQUENCE_PATTERN.search(entry).group(1)
        sequence = self.SEQ_REMOVE_NUMBERS_PATTERN.sub("", sequence)
        parsed_sequence = "".join(self.NORMALIZE_WHITESPACE_PATTERN.sub("", seq_line) for seq_line in sequence.split("\n") if seq_line)

        return parsed_sequence

    def extract_refseq_pair(self, file_type:str, entry: str) -> Optional[str]:
        if file_type == "dna":
            protein_ids = self.PROTEIN_IDS_PATTERN.findall(entry)
            if protein_ids:
                return protein_ids[-1]
        elif file_type == "peptide":
            coded_by = self.CODED_BY_PATTERN.findall(entry)
            if coded_by:
                return coded_by[-1]

            match = self.DBSOURCE_PATTERN.search(entry)
            if match:
                return match.group(1)

        return None

    def add_dependents(self, xref: Dict[str, Any], gene_id: str, source_ids: Dict[str, int], label: str, counts: Dict[str, int]) -> None:
        # Add EntrezGene and WikiGene dependent xrefs
        for source_key in ["entrez", "wiki"]:
            dependent = {
                "SOURCE_ID": source_ids[f"{source_key}_source_id"],
                "LINKAGE_SOURCE_ID": xref["SOURCE_ID"],
                "ACCESSION": gene_id,
                "LABEL": label,
            }
            xref["DEPENDENT_XREFS"].append(dependent)
            counts[f"num_{source_key}"] += 1

    def type_from_file(self, file_name: str) -> Optional[str]:
        if re.search("RefSeq_protein", file_name):
            return "peptide"
        if re.search("rna", file_name):
            return "dna"
        if re.search("protein", file_name):
            return "peptide"
        return None
