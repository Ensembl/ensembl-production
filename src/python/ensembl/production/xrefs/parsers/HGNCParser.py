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

"""Parser module for HGNC source."""

from ensembl.production.xrefs.parsers.BaseParser import *

from unidecode import unidecode
import codecs


class HGNCParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args["source_id"]
        species_id = args["species_id"]
        file       = args["file"]
        dba        = args["dba"]
        xref_dbi   = args["xref_dbi"]
        verbose    = args.get("verbose", False)

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        # Parse the file string and set default user
        file_params = self.parse_file_string(file)
        if not file_params.get("user"):
            file_params["user"] = "ensro"

        # Prepare lookup lists
        swissprot = self.get_valid_codes("Uniprot/SWISSPROT", species_id, xref_dbi)
        refseq = self.get_valid_codes("refseq", species_id, xref_dbi)
        source_list = ["refseq_peptide", "refseq_mRNA"]
        entrezgene = self.get_valid_xrefs_for_dependencies(
            "EntrezGene", source_list, xref_dbi
        )

        # Prepare sources
        self_source_name = self.get_source_name_for_source_id(source_id, xref_dbi)
        source_ids = {
            "ccds": self.get_source_id_for_source_name(
                self_source_name, xref_dbi, "ccds"
            ),
            "entrezgene_manual": self.get_source_id_for_source_name(
                self_source_name, xref_dbi, "entrezgene_manual"
            ),
            "refseq_manual": self.get_source_id_for_source_name(
                self_source_name, xref_dbi, "refseq_manual"
            ),
            "ensembl_manual": self.get_source_id_for_source_name(
                self_source_name, xref_dbi, "ensembl_manual"
            ),
            "desc_only": self.get_source_id_for_source_name(
                self_source_name, xref_dbi, "desc_only"
            ),
            "lrg": self.get_source_id_for_source_name("LRG_HGNC_notransfer", xref_dbi),
            "genecards": self.get_source_id_for_source_name("GeneCards", xref_dbi),
        }

        # Statistics counts
        name_count = {
            "ccds": 0,
            "lrg": 0,
            "ensembl_manual": 0,
            "genecards": 0,
            "refseq_manual": 0,
            "entrezgene_manual": 0,
        }
        mismatch = 0

        # Connect to the ccds db
        ccds_db_url = None
        if dba:
            ccds_db_url = dba
        elif file_params.get("host"):
            ccds_db_url = URL.create(
                "mysql",
                file_params["user"],
                file_params["pass"],
                file_params["host"],
                file_params["port"],
                file_params["dbname"],
            )
        else:
            raise AttributeError("No ensembl ccds database provided")

        if not ccds_db_url:
            raise AttributeError("No ensembl ccds database provided")
        else:
            if verbose:
                logging.info(f"Found ccds DB: {ccds_db_url}")

        # Get CCDS data
        db_engine = self.get_db_engine(ccds_db_url)
        with db_engine.connect() as ccds_dbi:
            query = (
                select(TranscriptAttribORM.value, TranscriptORM.stable_id)
                .join(
                    TranscriptAttribORM,
                    TranscriptORM.transcript_id == TranscriptAttribORM.transcript_id,
                )
                .join(
                    AttribTypeORM,
                    TranscriptAttribORM.attrib_type_id == AttribTypeORM.attrib_type_id,
                )
                .where(AttribTypeORM.code == "ccds_transcript")
            )
            result = ccds_dbi.execute(query).mappings().all()

        ccds_to_ens = {}
        for row in result:
            # Remove version
            ccds_id = re.sub(r"\.\d+", "", row.value)

            ccds_to_ens[ccds_id] = row.stable_id

        # Get HGNC file (wget or disk)
        mem_file = file
        if file_params.get("wget"):
            response = requests.get(file_params["wget"])
            if not response.ok:
                raise IOError(response.reason)
            mem_file = response.text

        # Make sure the file is utf8
        mem_file = codecs.encode(mem_file, "utf-8").decode("utf-8")
        mem_file = re.sub(r'"', '', mem_file)

        file_io = self.get_filehandle(mem_file)
        csv_reader = csv.DictReader(file_io, delimiter="\t")

        # Read lines
        for line in csv_reader:
            accession = line["HGNC ID"]
            symbol = line["Approved symbol"]
            name = line["Approved name"]
            previous_symbols = line["Previous symbols"]
            synonyms = line["Alias symbols"]

            seen = 0

            # Direct CCDS to ENST mappings
            ccds = line["CCDS IDs"]
            ccds_list = []
            if ccds:
                ccds_list = re.split(r",\s", ccds)

            for ccds in ccds_list:
                enst_id = ccds_to_ens.get(ccds)
                if not enst_id:
                    continue

                self.add_to_direct_xrefs(
                    {
                        "stable_id": enst_id,
                        "ensembl_type": "gene",
                        "accession": accession,
                        "label": symbol,
                        "description": name,
                        "source_id": source_ids["ccds"],
                        "species_id": species_id,
                    },
                    xref_dbi,
                )
                self.add_synonyms_for_hgnc(
                    {
                        "source_id": source_ids["ccds"],
                        "name": accession,
                        "species_id": species_id,
                        "dead": previous_symbols,
                        "alias": synonyms,
                    },
                    xref_dbi,
                )

                name_count["ccds"] += 1

            # Direct LRG to ENST mappings
            lrg_id = line["Locus specific databases"]
            if lrg_id:
                match = re.search(r"(LRG_\d+)\|", lrg_id)
                if match:
                    lrg_id = match.group(1)

                    self.add_to_direct_xrefs(
                        {
                            "stable_id": lrg_id,
                            "ensembl_type": "gene",
                            "accession": accession,
                            "label": symbol,
                            "description": name,
                            "source_id": source_ids["lrg"],
                            "species_id": species_id,
                        },
                        xref_dbi,
                    )
                    self.add_synonyms_for_hgnc(
                        {
                            "source_id": source_ids["lrg"],
                            "name": accession,
                            "species_id": species_id,
                            "dead": previous_symbols,
                            "alias": synonyms,
                        },
                        xref_dbi,
                    )

                    name_count["lrg"] += 1

            # Direct Ensembl mappings
            ensg_id = line["Ensembl gene ID"]
            if ensg_id:
                seen = 1

                self.add_to_direct_xrefs(
                    {
                        "stable_id": ensg_id,
                        "ensembl_type": "gene",
                        "accession": accession,
                        "label": symbol,
                        "description": name,
                        "source_id": source_ids["ensembl_manual"],
                        "species_id": species_id,
                    },
                    xref_dbi,
                )
                self.add_synonyms_for_hgnc(
                    {
                        "source_id": source_ids["ensembl_manual"],
                        "name": accession,
                        "species_id": species_id,
                        "dead": previous_symbols,
                        "alias": synonyms,
                    },
                    xref_dbi,
                )

                name_count["ensembl_manual"] += 1

                # GeneCards
                direct_id = self.get_xref_id(
                    accession, source_ids["ensembl_manual"], species_id, xref_dbi
                )
                hgnc_id = re.search(r"HGNC:(\d+)", accession).group(1)

                self.add_dependent_xref(
                    {
                        "master_xref_id": direct_id,
                        "accession": hgnc_id,
                        "label": symbol,
                        "description": name,
                        "source_id": source_ids["genecards"],
                        "species_id": species_id,
                    },
                    xref_dbi,
                )
                self.add_synonyms_for_hgnc(
                    {
                        "source_id": source_ids["genecards"],
                        "name": hgnc_id,
                        "species_id": species_id,
                        "dead": previous_symbols,
                        "alias": synonyms,
                    },
                    xref_dbi,
                )

                name_count["genecards"] += 1

            # RefSeq
            refseq_id = line["RefSeq IDs"]
            if refseq_id and refseq.get(refseq_id):
                seen = 1

                for xref_id in refseq[refseq_id]:
                    self.add_dependent_xref(
                        {
                            "master_xref_id": xref_id,
                            "accession": accession,
                            "label": symbol,
                            "description": name,
                            "source_id": source_ids["refseq_manual"],
                            "species_id": species_id,
                        },
                        xref_dbi,
                    )
                    name_count["refseq_manual"] += 1

                self.add_synonyms_for_hgnc(
                    {
                        "source_id": source_ids["refseq_manual"],
                        "name": accession,
                        "species_id": species_id,
                        "dead": previous_symbols,
                        "alias": synonyms,
                    },
                    xref_dbi,
                )

            # EntrezGene
            entrez_id = line["NCBI Gene ID"]
            if entrez_id and entrezgene.get(entrez_id):
                seen = 1

                self.add_dependent_xref(
                    {
                        "master_xref_id": entrezgene[entrez_id],
                        "accession": accession,
                        "label": symbol,
                        "description": name,
                        "source_id": source_ids["entrezgene_manual"],
                        "species_id": species_id,
                    },
                    xref_dbi,
                )
                self.add_synonyms_for_hgnc(
                    {
                        "source_id": source_ids["entrezgene_manual"],
                        "name": accession,
                        "species_id": species_id,
                        "dead": previous_symbols,
                        "alias": synonyms,
                    },
                    xref_dbi,
                )

                name_count["entrezgene_manual"] += 1

            # Store to keep descriptions if not stored yet
            if not seen:
                xref_id = self.add_xref(
                    {
                        "accession": accession,
                        "label": symbol,
                        "description": name,
                        "source_id": source_ids["desc_only"],
                        "species_id": species_id,
                        "info_type": "MISC",
                    },
                    xref_dbi,
                )
                self.add_synonyms_for_hgnc(
                    {
                        "source_id": source_ids["desc_only"],
                        "name": accession,
                        "species_id": species_id,
                        "dead": previous_symbols,
                        "alias": synonyms,
                    },
                    xref_dbi,
                )
                mismatch += 1

        file_io.close()

        result_message = "HGNC xrefs loaded:\n"
        for count_type, count in name_count.items():
            result_message += f"\t{count_type}\t{count}\n"
        result_message += f"{mismatch} HGNC ids could not be associated in xrefs"

        return 0, result_message

    def add_synonyms_for_hgnc(self, args: Dict[str, Any], dbi: Connection) -> None:
        source_id    = args["source_id"]
        name         = args["name"]
        species_id   = args["species_id"]
        dead_string  = args.get("dead")
        alias_string = args.get("alias")

        # Dead name, add to synonym
        if dead_string:
            dead_string = re.sub('"', "", dead_string)
            dead_array = re.split(r",\s", dead_string)

            for dead in dead_array:
                try:
                    dead = dead.decode("utf-8")
                except:
                    pass
                dead = unidecode(dead.upper())

                self.add_to_syn(name, source_id, dead, species_id, dbi)

        # Alias name, add to synonym
        if alias_string:
            alias_string = re.sub('"', "", alias_string)
            alias_array = re.split(r",\s", alias_string)

            for alias in alias_array:
                try:
                    alias = alias.decode("utf-8")
                except:
                    pass
                alias = unidecode(alias.upper())

                self.add_to_syn(name, source_id, alias, species_id, dbi)

    def parse_file_string(self, file_string: str) -> Dict[str, str]:
        # file_string = re.sub(r"\A\w+:", "", file_string)
        file_string = re.sub(r"^\w+:", "", file_string)

        param_pairs = file_string.split(",")
        params = {}

        # Set provided values
        for pair in param_pairs:
            if re.search("=>", pair):
                key, value = pair.split("=>")
                params[key] = value

        return params
