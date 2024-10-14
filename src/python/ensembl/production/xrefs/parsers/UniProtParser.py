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

from ensembl.production.xrefs.parsers.BaseParser import *

import codecs


class UniProtParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id    = args["source_id"]
        species_id   = args["species_id"]
        file         = args["file"]
        xref_dbi     = args["xref_dbi"]
        release_file = args["rel_file"]
        verbose      = args.get("verbose", False)
        hgnc_file    = args.get("hgnc_file")

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        # Get needed source ids
        source_ids = {
            "sp_source_id": self.get_source_id_for_source_name(
                "Uniprot/SWISSPROT", xref_dbi, "sequence_mapped"
            ),
            "sptr_source_id": self.get_source_id_for_source_name(
                "Uniprot/SPTREMBL", xref_dbi, "sequence_mapped"
            ),
            "sptr_non_display_source_id": self.get_source_id_for_source_name(
                "Uniprot/SPTREMBL", xref_dbi, "protein_evidence_gt_2"
            ),
            "sp_direct_source_id": self.get_source_id_for_source_name(
                "Uniprot/SWISSPROT", xref_dbi, "direct"
            ),
            "sptr_direct_source_id": self.get_source_id_for_source_name(
                "Uniprot/SPTREMBL", xref_dbi, "direct"
            ),
            "isoform_source_id": self.get_source_id_for_source_name(
                "Uniprot_isoform", xref_dbi
            ),
        }

        if verbose:
            logging.info(f'SwissProt source ID = {source_ids["sp_source_id"]}')
            logging.info(f'SpTREMBL source ID = {source_ids["sptr_source_id"]}')
            logging.info(
                f'SpTREMBL protein_evidence > 2 source ID = {source_ids["sptr_non_display_source_id"]}'
            )
            logging.info(
                f'SwissProt direct source ID = {source_ids["sp_direct_source_id"]}'
            )
            logging.info(
                f'SpTREMBL direct source ID = {source_ids["sptr_direct_source_id"]}'
            )

        # Parse and set release info
        if release_file:
            sp_release = None
            sptr_release = None

            release_io = self.get_filehandle(release_file)
            for line in release_io:
                line = line.strip()
                if not line:
                    continue

                match = re.search(r"(UniProtKB/Swiss-Prot Release .*)", line)
                if match:
                    sp_release = match.group(1)
                    if verbose:
                        logging.info(f"Swiss-Prot release is {sp_release}")
                else:
                    match = re.search(r"(UniProtKB/TrEMBL Release .*)", line)
                    if match:
                        sptr_release = match.group(1)
                        if verbose:
                            logging.info(f"SpTrEMBL release is {sptr_release}")

            release_io.close()

            # Set releases
            self.set_release(source_ids["sp_source_id"], sp_release, xref_dbi)
            self.set_release(source_ids["sptr_source_id"], sptr_release, xref_dbi)
            self.set_release(
                source_ids["sptr_non_display_source_id"], sptr_release, xref_dbi
            )
            self.set_release(source_ids["sp_direct_source_id"], sp_release, xref_dbi)
            self.set_release(
                source_ids["sptr_direct_source_id"], sptr_release, xref_dbi
            )

        result_message = self.create_xrefs(source_ids, species_id, file, xref_dbi, hgnc_file)

        return 0, result_message

    def create_xrefs(self, source_ids: Dict[str, int], species_id: int, file: str, dbi: Connection, hgnc_file: str = None) -> str:
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

        # Get sources ids of dependent sources
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
        for section in self.get_file_sections(file, "//\n"):
            if len(section) == 1:
                continue

            entry = "".join(section)
            xref = {}

            # Extract the species taxon id
            found = 0
            match = re.search(r"OX\s+[a-zA-Z_]+=([0-9 ,]+).*;", entry)
            if match:
                ox = match.group(1)
                for taxon_id_from_file in ox.split(", "):
                    taxon_id_from_file = re.sub(r"\s", "", taxon_id_from_file)
                    if tax_to_species_id.get(taxon_id_from_file):
                        found = 1
                        count += 1

            # If no taxon_id's match, skip to next record
            if not found:
                continue

            # Check for CC (caution) lines containing certain text
            # If sequence is from Ensembl, do not use
            ensembl_derived_protein = 0
            if re.search(
                r"CAUTION: The sequence shown here is derived from an Ensembl", entry
            ):
                ensembl_derived_protein = 1
                ensembl_derived_protein_count += 1

            # Extract ^AC lines and build list of accessions
            accessions = []
            accessions_only = re.findall(r"\nAC\s+(.+)", entry)
            for accessions_line in accessions_only:
                for acc in accessions_line.split(";"):
                    acc = acc.strip()
                    if acc:
                        accessions.append(acc)
            accession = accessions[0]

            if accession.lower() == "unreviewed":
                logging.warn(
                    f"WARNING: entries with accession of {accession} not allowed, will be skipped"
                )
                continue

            xref["ACCESSION"] = accession
            xref["INFO_TYPE"] = "SEQUENCE_MATCH"
            xref["SYNONYMS"] = []
            for i in range(1, len(accessions)):
                xref["SYNONYMS"].append(accessions[i])

            sp_type = re.search(r"ID\s+(\w+)\s+(\w+)", entry).group(2)
            protein_evidence_code = re.search(r"PE\s+(\d+)", entry).group(1)
            version = re.search(r"DT\s+\d+-\w+-\d+, entry version (\d+)", entry).group(
                1
            )

            # SwissProt/SPTrEMBL are differentiated by having STANDARD/PRELIMINARY here
            if re.search(r"^Reviewed", sp_type, re.IGNORECASE):
                xref["SOURCE_ID"] = source_ids["sp_source_id"]
                counts["num_sp"] += 1
            elif re.search(r"Unreviewed", sp_type, re.IGNORECASE):
                # Use normal source only if it is PE levels 1 & 2
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

            # Extract ^DE lines only and build cumulative description string
            description = ""
            description_lines = re.findall(r"\nDE\s+(.+)", entry)
            for line in description_lines:
                match = re.search(r"RecName: Full=(.*);", line)
                if match:
                    if description:
                        description += "; "
                    description += match.group(1)
                else:
                    match = re.search(r"SubName: Full=(.*);", line)
                    if match:
                        if description:
                            description += "; "
                        description += match.group(1)

                description = re.sub(r"^\s*", "", description)
                description = re.sub(r"\s*$", "", description)
                description = re.sub(r"\s*\{ECO:.*?\}", "", description)

                # Parse the EC_NUMBER line, only for S.cerevisiae for now
                if re.search(r"EC=", line) and species_id == "4932":
                    # Get the EC Number and make it an xref for S.cer if any
                    EC = re.search(r"\s*EC=([^;]+);", line).group(1)

                    dependent = {}
                    dependent["LABEL"] = EC
                    dependent["ACCESSION"] = EC
                    dependent["SOURCE_NAME"] = "EC_NUMBER"
                    dependent["SOURCE_ID"] = dependent_sources["EC_NUMBER"]
                    dependent["LINKAGE_SOURCE_ID"] = xref["SOURCE_ID"]
                    xref["DEPENDENT_XREFS"].append(dependent)
                    dependent_xrefs_counts["EC_NUMBER"] = (
                        dependent_xrefs_counts.get("EC_NUMBER", 0) + 1
                    )

            xref["DESCRIPTION"] = description

            # Extract sequence
            sequence = re.search(r"SQ\s+(.+)", entry, flags=re.DOTALL).group(1)
            sequence = re.sub(r"\n", "", sequence)
            sequence = re.sub(r"\/\/", "", sequence)
            sequence = re.sub(r"\s", "", sequence)
            sequence = re.sub(r"^.*;", "", sequence)
            xref["SEQUENCE"] = sequence

            # Extract gene names
            gene_names = re.findall(r"\nGN\s+(.+)", entry)
            gene_names = " ".join(gene_names).split(";")

            # Do not allow the addition of UniProt Gene Name dependent Xrefs
            # if the protein was imported from Ensembl. Otherwise we will
            # re-import previously set symbols
            if not ensembl_derived_protein:
                dependent = {}
                name_found = 0
                gene_name = None
                dep_synonyms = []
                for line in gene_names:
                    line = line.strip()

                    if not re.search(r"Name=", line) and not re.search(
                        r"Synonyms=", line
                    ):
                        continue

                    match = re.search(r"Name=([A-Za-z0-9_\-\.\s]+)", line)
                    if match and not name_found:
                        gene_name = match.group(1).rstrip()
                        gene_name = re.sub(r"\nGN", "", gene_name)
                        name_found = 1

                    match = re.search(r"Synonyms=(.*)", line)
                    if match:
                        synonym = match.group(1)
                        synonym = re.sub(r"\{.*?\}", "", synonym)
                        synonym = re.sub(r"\s+$", "", synonym)
                        synonym = re.sub(r"\s*,\s*", ",", synonym)
                        synonyms = synonym.split(",")
                        for synonym in synonyms:
                            if synonym not in dep_synonyms:
                                dep_synonyms.append(synonym)

                if gene_name:
                    dependent["LABEL"] = gene_name
                    dependent["ACCESSION"] = xref["ACCESSION"]
                    dependent["SOURCE_NAME"] = "Uniprot_gn"
                    dependent["SOURCE_ID"] = dependent_sources["Uniprot_gn"]
                    dependent["LINKAGE_SOURCE_ID"] = xref["SOURCE_ID"]
                    dependent["SYNONYMS"] = dep_synonyms
                    if hgnc_file and hgnc_descriptions.get(gene_name) is not None:
                        dependent["DESCRIPTION"] = hgnc_descriptions[gene_name]
                    xref["DEPENDENT_XREFS"].append(dependent)
                    dependent_xrefs_counts["Uniprot_gn"] = (
                        dependent_xrefs_counts.get("Uniprot_gn", 0) + 1
                    )

            # Dependent xrefs - only store those that are from sources listed in the source table
            deps = re.findall(r"\n(DR\s+.+)", entry)

            seen = {}
            for dep in deps:
                match = re.search(r"^DR\s+(.+)", dep)
                if match:
                    vals = re.split(r";\s*", match.group(1))
                    source = vals[0]
                    acc = vals[1]
                    extra = []
                    if len(vals) > 2:
                        extra = vals[2 : len(vals)]

                    # Skip external sources obtained through other files
                    if re.search(
                        r"^(GO|UniGene|RGD|CCDS|IPI|UCSC|SGD|HGNC|MGI|VGNC|Orphanet|ArrayExpress|GenomeRNAi|EPD|Xenbase|Reactome|MIM|GeneCards)",
                        source,
                    ):
                        continue

                    # If mapped to Ensembl, add as direct xref
                    if source == "Ensembl":
                        direct = {}
                        isoform = {}

                        stable_id = extra[0]
                        stable_id = re.sub(r"\.[0-9]+", "", stable_id)
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
                            self.add_to_direct_xrefs(
                                {
                                    "stable_id": stable_id,
                                    "ensembl_type": "translation",
                                    "accession": isoform,
                                    "label": isoform,
                                    "source_id": source_ids["isoform_source_id"],
                                    "linkage": "DIRECT",
                                    "species_id": species_id,
                                },
                                dbi,
                            )
                            counts["num_isoform"] += 1

                    # Create dependent xref structure & store it
                    if dependent_sources.get(source):
                        dependent = {}

                        dependent["SOURCE_NAME"] = source
                        dependent["LINKAGE_SOURCE_ID"] = xref["SOURCE_ID"]
                        dependent["SOURCE_ID"] = dependent_sources[source]
                        dependent["ACCESSION"] = acc

                        if not seen.get(f"{source}:{acc}"):
                            xref["DEPENDENT_XREFS"].append(dependent)
                            dependent_xrefs_counts[source] = (
                                dependent_xrefs_counts.get(source, 0) + 1
                            )
                            seen[f"{source}:{acc}"] = 1

                        if re.search(r"EMBL", dep) and not re.search(r"ChEMBL", dep):
                            protein_id = extra[0]
                            if protein_id != "-" and not seen.get(
                                f"{source}:{protein_id}"
                            ):
                                dependent = {}

                                dependent["SOURCE_NAME"] = source
                                dependent["SOURCE_ID"] = dependent_sources["protein_id"]
                                dependent["LINKAGE_SOURCE_ID"] = xref["SOURCE_ID"]
                                dependent["LABEL"] = protein_id
                                dependent["ACCESSION"] = re.search(
                                    r"([^.]+)\.([^.]+)", protein_id
                                ).group(1)
                                xref["DEPENDENT_XREFS"].append(dependent)
                                dependent_xrefs_counts[source] = (
                                    dependent_xrefs_counts.get(source, 0) + 1
                                )
                                seen[f"{source}:{protein_id}"] = 1

            xrefs.append(xref)

            if count > 1000:
                self.upload_xref_object_graphs(xrefs, dbi)
                count = 0
                xrefs.clear()

        if len(xrefs) > 0:
            self.upload_xref_object_graphs(xrefs, dbi)

        result_message = f'Read {counts["num_sp"]} SwissProt xrefs, {counts["num_sptr"]} SPTrEMBL xrefs with protein evidence codes 1-2, and {counts["num_sptr_non_display"]} SPTrEMBL xrefs with protein evidence codes > 2 from {file}\n'
        result_message += f'Added {counts["num_direct_sp"]} direct SwissProt xrefs and {counts["num_direct_sptr"]} direct SPTrEMBL xrefs\n'
        result_message += f'Added {counts["num_isoform"]} direct isoform xrefs\n'
        result_message += f"Skipped {ensembl_derived_protein_count} ensembl annotations as Gene names\n"

        result_message += f"Added the following dependent xrefs:\n"
        for xref_source, xref_count in dependent_xrefs_counts.items():
            result_message += f"\t{xref_source}\t{xref_count}\n"

        return result_message

    def get_hgnc_descriptions(self, hgnc_file: str) -> Dict[str, str]:
        descriptions = {}

        # Make sure the file is utf8
        hgnc_file = codecs.encode(hgnc_file, "utf-8").decode("utf-8")
        hgnc_file = re.sub(r'"', '', hgnc_file)

        hgnc_io = self.get_filehandle(hgnc_file)
        csv_reader = csv.DictReader(hgnc_io, delimiter="\t")

        # Read lines
        for line in csv_reader:
            gene_name = line["Approved symbol"]
            description = line["Approved name"]

            descriptions[gene_name] = description

        hgnc_io.close()

        return descriptions