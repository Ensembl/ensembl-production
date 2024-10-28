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

"""Parser module for Uniprot sources."""

import re
import logging
import csv
import codecs
from typing import Dict, Any, Tuple, List
from sqlalchemy.engine import Connection

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class UniProtParser(BaseParser):
    SWISSPROT_RELEASE_PATTERN = re.compile(r"(UniProtKB/Swiss-Prot Release .*)")
    TREMBL_RELEASE_PATTERN = re.compile(r"(UniProtKB/TrEMBL Release .*)")
    TAXON_PATTERN = re.compile(r"[a-zA-Z_]+=([0-9 ,]+).*;")
    CAUTION_PATTERN = re.compile(r"CAUTION: The sequence shown here is derived from an Ensembl")
    SP_TYPE_PATTERN = re.compile(r"(\w+)\s+(\w+)")
    PROTEIN_EVIDENCE_PATTERN = re.compile(r"(\d+)")
    VERSION_PATTERN = re.compile(r"\d+-\w+-\d+, entry version (\d+)")
    REVIEWED_PATTERN = re.compile(r"^Reviewed", re.IGNORECASE)
    UNREVIEWED_PATTERN = re.compile(r"Unreviewed", re.IGNORECASE)
    DESCRIPTION_PATTERN = re.compile(r"(RecName|SubName): Full=(.*)")
    ECO_PATTERN = re.compile(r"\s*\{ECO:.*?\}")
    EC_PATTERN = re.compile(r"EC=([^;]+)")
    SEQUENCE_PATTERN = re.compile(r"^SEQUENCE")
    WHITESPACE_PATTERN = re.compile(r"\s+")
    GENE_NAME_PATTERN = re.compile(r"Name=(.*)")
    SYNONYMS_PATTERN = re.compile(r"Synonyms=(.*)")
    SYNONYMS_COMMA_PATTERN = re.compile(r"\s*,\s*")
    DEPENDENTS_PATTERN = re.compile(r"^(GO|UniGene|RGD|CCDS|IPI|UCSC|SGD|HGNC|MGI|VGNC|Orphanet|ArrayExpress|GenomeRNAi|EPD|Xenbase|Reactome|MIM|GeneCards)")
    STABLE_ID_PATTERN = re.compile(r"\.[0-9]+")
    PROTEIN_ID_PATTERN = re.compile(r"([^.]+)\.([^.]+)")

    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")
        release_file = args.get("rel_file")
        verbose = args.get("verbose", False)
        hgnc_file = args.get("hgnc_file")

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        # Get needed source ids
        source_ids = self.get_source_ids(xref_dbi, verbose)

        # Parse and set release info
        self.set_release_info(release_file, source_ids, xref_dbi, verbose)

        result_message = self.create_xrefs(source_ids, species_id, xref_file, xref_dbi, hgnc_file)
        return 0, result_message

    def get_source_ids(self, dbi: Connection, verbose: bool) -> Dict[str, int]:
        source_names = {
            "sp_source_id": ("Uniprot/SWISSPROT", "sequence_mapped"),
            "sptr_source_id": ("Uniprot/SPTREMBL", "sequence_mapped"),
            "sptr_non_display_source_id": ("Uniprot/SPTREMBL", "protein_evidence_gt_2"),
            "sp_direct_source_id": ("Uniprot/SWISSPROT", "direct"),
            "sptr_direct_source_id": ("Uniprot/SPTREMBL", "direct"),
            "isoform_source_id": ("Uniprot_isoform", None),
        }

        source_ids = {
            key: self.get_source_id_for_source_name(name, dbi, type)
            for key, (name, type) in source_names.items()
        }

        if verbose:
            for key, value in source_ids.items():
                logging.info(f'{key} = {value}')

        return source_ids

    def set_release_info(self, release_file: str, source_ids: Dict[str, int], dbi: Connection, verbose: bool) -> None:
        if not release_file:
            return

        sp_release = None
        sptr_release = None

        with self.get_filehandle(release_file) as release_io:
            for line in release_io:
                line = line.strip()
                if not line:
                    continue

                match = self.SWISSPROT_RELEASE_PATTERN.search(line)
                if match:
                    sp_release = match.group(1)
                    if verbose:
                        logging.info(f"Swiss-Prot release is {sp_release}")
                else:
                    match = self.TREMBL_RELEASE_PATTERN.search(line)
                    if match:
                        sptr_release = match.group(1)
                        if verbose:
                            logging.info(f"SpTrEMBL release is {sptr_release}")

        # Set releases
        self.set_release(source_ids["sp_source_id"], sp_release, dbi)
        self.set_release(source_ids["sptr_source_id"], sptr_release, dbi)
        self.set_release(source_ids["sptr_non_display_source_id"], sptr_release, dbi)
        self.set_release(source_ids["sp_direct_source_id"], sp_release, dbi)
        self.set_release(source_ids["sptr_direct_source_id"], sptr_release, dbi)

    def create_xrefs(self, source_ids: Dict[str, int], species_id: int, xref_file: str, dbi: Connection, hgnc_file: str = None) -> str:
        counts = {
            "num_sp": 0,
            "num_sptr": 0,
            "num_sptr_non_display": 0,
            "num_direct_sp": 0,
            "num_direct_sptr": 0,
            "num_isoform": 0,
        }
        dependent_xrefs_counts = {}
        ensembl_derived_protein_count = 0
        count = 0

        # Get source ids of dependent sources
        dependent_sources = self.get_xref_sources(dbi)

        # Extract descriptions from hgnc
        hgnc_descriptions = {}
        if hgnc_file:
            hgnc_descriptions = self.get_hgnc_descriptions(hgnc_file)

        # Create a hash of all valid taxon_ids for this species
        species_id_to_tax = self.species_id_to_taxonomy(dbi)
        species_id_to_tax.setdefault(species_id, []).append(species_id)
        tax_ids = species_id_to_tax[species_id]
        tax_to_species_id = {tax_id: species_id for tax_id in tax_ids}

        xrefs = []

        # Read file
        for section in self.get_file_sections(xref_file, "//\n"):
            entry = self.extract_entry_fields(section)
            xref = {}

            # Extract the species taxon id
            found = False
            match = self.TAXON_PATTERN.search(entry["OX"][0])
            if match:
                ox = match.group(1)
                for taxon_id_from_file in ox.split(", "):
                    taxon_id_from_file = taxon_id_from_file.strip()
                    if tax_to_species_id.get(int(taxon_id_from_file)):
                        found = True
                        count += 1

            # If no taxon_id match found, skip to next record
            if not found:
                continue

            # Check for CC (caution) lines containing certain text
            # If sequence is from Ensembl, do not use
            ensembl_derived_protein = False
            for comment in entry.get("CC", []):
                ensembl_derived_protein = bool(self.CAUTION_PATTERN.search(comment))
                if ensembl_derived_protein:
                    ensembl_derived_protein_count += 1
                    break

            # Extract ^AC lines and build list of accessions
            accessions = [acc.strip() for acc in entry["AC"][0].split(";") if acc.strip()]
            accession = accessions[0]

            if accession.lower() == "unreviewed":
                logging.warning(f"WARNING: entries with accession of {accession} not allowed, will be skipped")
                continue

            # Starting building xref object
            xref["ACCESSION"] = accession
            xref["INFO_TYPE"] = "SEQUENCE_MATCH"
            xref["SYNONYMS"] = accessions[1:]

            # Extract the type, protein evidence code and version
            sp_type = self.SP_TYPE_PATTERN.search(entry["ID"][0]).group(2)
            protein_evidence_code = self.PROTEIN_EVIDENCE_PATTERN.search(entry["PE"][0]).group(1)
            for dt_line in entry.get("DT", []):
                match = self.VERSION_PATTERN.search(dt_line)
                if match:
                    version = match.group(1)
                    break

            # SwissProt/SPTrEMBL are differentiated by having Reviewed/Unreviewed here
            if self.REVIEWED_PATTERN.search(sp_type):
                xref["SOURCE_ID"] = source_ids["sp_source_id"]
                counts["num_sp"] += 1
            elif self.UNREVIEWED_PATTERN.search(sp_type):
                # Use normal source only if PE levels 1 & 2
                if protein_evidence_code and int(protein_evidence_code) < 3:
                    xref["SOURCE_ID"] = source_ids["sptr_source_id"]
                    counts["num_sptr"] += 1
                else:
                    xref["SOURCE_ID"] = source_ids["sptr_non_display_source_id"]
                    counts["num_sptr_non_display"] += 1
            else:
                continue

            # Some straightforward fields
            xref["LABEL"] = f"{accession}.{version}"
            xref["VERSION"] = version
            xref["SPECIES_ID"] = species_id
            xref["SEQUENCE_TYPE"] = "peptide"
            xref["STATUS"] = "experimental"
            xref["DEPENDENT_XREFS"] = []
            xref["DIRECT_XREFS"] = []

            # Extract the description
            description, ec_number = self.extract_description("".join(entry.get("DE", [])))
            xref["DESCRIPTION"] = description

            # Parse the EC_NUMBER, only for S.cerevisiae for now
            if ec_number and species_id == 4932:
                dependent = {}
                dependent["LABEL"] = ec_number
                dependent["ACCESSION"] = ec_number
                dependent["SOURCE_NAME"] = "EC_NUMBER"
                dependent["SOURCE_ID"] = dependent_sources["EC_NUMBER"]
                dependent["LINKAGE_SOURCE_ID"] = xref["SOURCE_ID"]
                xref["DEPENDENT_XREFS"].append(dependent)
                dependent_xrefs_counts["EC_NUMBER"] = (dependent_xrefs_counts.get("EC_NUMBER", 0) + 1)

            # Extract sequence
            sequence = ""
            for seq_line in entry.get("SQ", []):
                if not self.SEQUENCE_PATTERN.search(seq_line):
                    sequence += seq_line
            sequence = self.WHITESPACE_PATTERN.sub("", sequence)
            xref["SEQUENCE"] = sequence

            # Extract gene names
            if not ensembl_derived_protein and entry.get("GN"):
                gene_name, gene_synonyms = self.extract_gene_name(" ".join(entry["GN"]))

                # Add dependent xref for gene name
                if gene_name:
                    dependent = {}
                    dependent["LABEL"] = gene_name
                    dependent["ACCESSION"] = xref["ACCESSION"]
                    dependent["SOURCE_NAME"] = "Uniprot_gn"
                    dependent["SOURCE_ID"] = dependent_sources["Uniprot_gn"]
                    dependent["LINKAGE_SOURCE_ID"] = xref["SOURCE_ID"]
                    dependent["SYNONYMS"] = gene_synonyms
                    if hgnc_file and hgnc_descriptions.get(gene_name):
                        dependent["DESCRIPTION"] = hgnc_descriptions[gene_name]
                    xref["DEPENDENT_XREFS"].append(dependent)
                    dependent_xrefs_counts["Uniprot_gn"] = dependent_xrefs_counts.get("Uniprot_gn", 0) + 1

            # Dependent xrefs - only store those that are from sources listed in the source table
            seen = {}
            for dependent_line in entry.get("DR", []):
                vals = re.split(r";\s*", dependent_line)
                source = vals[0]
                dependent_acc = vals[1]
                extra = vals[2:] if len(vals) > 2 else []

                # Skip external sources obtained through other files
                if self.DEPENDENTS_PATTERN.search(source):
                    continue

                # If mapped to Ensembl, add as direct xref
                if source == "Ensembl":
                    stable_id = self.STABLE_ID_PATTERN.sub("", extra[0])

                    direct = {}
                    direct["STABLE_ID"] = stable_id
                    direct["ENSEMBL_TYPE"] = "Translation"
                    direct["LINKAGE_TYPE"] = "DIRECT"
                    if xref["SOURCE_ID"] == source_ids["sp_source_id"]:
                        direct["SOURCE_ID"] = source_ids["sp_direct_source_id"]
                        counts["num_direct_sp"] += 1
                    else:
                        direct["SOURCE_ID"] = source_ids["sptr_direct_source_id"]
                        counts["num_direct_sptr"] += 1
                    xref["DIRECT_XREFS"].append(direct)

                    match = re.search(r"(%s-[0-9]+)" % accession, extra[1])
                    if match:
                        isoform = match.group(1)

                        xref_id = self.add_xref(
                            {
                                "accession": isoform,
                                "label": isoform,
                                "source_id": source_ids["isoform_source_id"],
                                "species_id": species_id,
                                "info_type": "DIRECT",
                            },
                            dbi,
                        )
                        self.add_direct_xref(xref_id, stable_id, "translation", "DIRECT", dbi)
                        counts["num_isoform"] += 1

                # Create dependent xref structure & store it
                if dependent_sources.get(source):
                    # Only add depenedent accession once for record
                    if not seen.get(f"{source}:{dependent_acc}"):
                        dependent = {
                            "SOURCE_NAME": source,
                            "LINKAGE_SOURCE_ID": xref["SOURCE_ID"],
                            "SOURCE_ID": dependent_sources[source],
                            "ACCESSION": dependent_acc,
                        }

                        xref["DEPENDENT_XREFS"].append(dependent)
                        dependent_xrefs_counts[source] = dependent_xrefs_counts.get(source, 0) + 1
                        seen[f"{source}:{dependent_acc}"] = True

                    # For EMBL source, add protein_id as dependent xref
                    if source == "EMBL":
                        protein_id = extra[0]
                        if protein_id != "-" and not seen.get(f"{source}:{protein_id}"):
                            protein_id_acc = self.PROTEIN_ID_PATTERN.search(protein_id).group(1)
                            dependent = {
                                "SOURCE_NAME": source,
                                "SOURCE_ID": dependent_sources["protein_id"],
                                "LINKAGE_SOURCE_ID": xref["SOURCE_ID"],
                                "LABEL": protein_id,
                                "ACCESSION": protein_id_acc,
                            }

                            xref["DEPENDENT_XREFS"].append(dependent)
                            dependent_xrefs_counts["protein_id"] = dependent_xrefs_counts.get("protein_id", 0) + 1
                            seen[f"{source}:{protein_id}"] = True

            xrefs.append(xref)

            if count > 1000:
                self.upload_xref_object_graphs(xrefs, dbi)
                count = 0
                xrefs.clear()

        if xrefs:
            self.upload_xref_object_graphs(xrefs, dbi)

        result_message = (
            f'Read {counts["num_sp"]} SwissProt xrefs, {counts["num_sptr"]} SPTrEMBL xrefs with protein evidence codes 1-2, '
            f'and {counts["num_sptr_non_display"]} SPTrEMBL xrefs with protein evidence codes > 2 from {xref_file}\n'
            f'Added {counts["num_direct_sp"]} direct SwissProt xrefs and {counts["num_direct_sptr"]} direct SPTrEMBL xrefs\n'
            f'Added {counts["num_isoform"]} direct isoform xrefs\n'
            f'Skipped {ensembl_derived_protein_count} ensembl annotations as Gene names\n'
            f'Added the following dependent xrefs:\n'
        )
        for xref_source, xref_count in dependent_xrefs_counts.items():
            result_message += f"\t{xref_source}\t{xref_count}\n"

        return result_message

    def extract_entry_fields(self, section: str) -> Dict[str, List[str]]:
        entry_dict = {}
        in_sq_section = False

        for line in section:
            line = line.strip()
            if not line:
                continue

            line_key = line[:2]
            clean_line = line[2:].strip()

            if line_key == "SQ":
                in_sq_section = True
            elif in_sq_section:
                line_key = "SQ"
                clean_line = line

            entry_dict.setdefault(line_key, []).append(clean_line)

        return entry_dict
    
    def extract_description(self, full_description: str) -> Tuple[str, str]:
        descriptions = []
        ec_number = None
        description = ""

        description_lines = full_description.split(";")
        for line in description_lines:
            if not line.strip():
                continue

            match = self.DESCRIPTION_PATTERN.search(line)
            if match:
                descriptions.append(match.group(2))
            
            # Get the EC number, if present
            match = self.EC_PATTERN.search(line)
            if match:
                ec_number = match.group(1)
                ec_number = self.ECO_PATTERN.sub("", ec_number).strip()

        if descriptions:
            description = "; ".join(descriptions)
            description = self.ECO_PATTERN.sub("", description).strip()

        return description, ec_number
    
    def extract_gene_name(self, full_gene_names: str) -> Tuple[str, List[str]]:
        name_found = False
        gene_name = None
        synonyms_list = []

        gene_name_lines = full_gene_names.split(";")
        for line in gene_name_lines:
            if not line.strip():
                continue

            match = self.GENE_NAME_PATTERN.search(line)
            if match and not name_found:
                gene_name = match.group(1)
                gene_name = self.ECO_PATTERN.sub("", gene_name).strip()
                name_found = True
            
            match = self.SYNONYMS_PATTERN.search(line)
            if match:
                synonyms = match.group(1)
                synonyms = self.ECO_PATTERN.sub("", synonyms).strip()
                synonyms = self.SYNONYMS_COMMA_PATTERN.sub(",", synonyms)
                synonyms_list = synonyms.split(",")
        
        return gene_name, synonyms_list

    def get_hgnc_descriptions(self, hgnc_file: str) -> Dict[str, str]:
        descriptions = {}

        # Make sure the file is utf8
        hgnc_file = codecs.encode(hgnc_file, "utf-8").decode("utf-8")
        hgnc_file = re.sub(r'"', "", hgnc_file)

        hgnc_io = self.get_filehandle(hgnc_file)
        csv_reader = csv.DictReader(hgnc_io, delimiter="\t")

        # Read lines
        for line in csv_reader:
            gene_name = line["Approved symbol"]
            description = line["Approved name"]

            descriptions[gene_name] = description

        hgnc_io.close()

        return descriptions
