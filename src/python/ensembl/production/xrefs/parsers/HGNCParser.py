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


from typing import Any, Dict, List, Tuple, Optional
import csv
import logging
import re
import requests
import codecs
from sqlalchemy import select
from sqlalchemy.engine import Connection
from sqlalchemy.engine.url import URL
from unidecode import unidecode

from ensembl.core.models import (
    Transcript as TranscriptORM,
    AttribType as AttribTypeORM,
    TranscriptAttrib as TranscriptAttribORM,
)

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class HGNCParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        db_url = args.get("extra_db_url")
        xref_dbi = args.get("xref_dbi")
        verbose = args.get("verbose", False)

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        # Parse the file string and set default user
        file_params = self.parse_file_string(xref_file)
        file_params.setdefault("user", "ensro")

        # Prepare sources
        self_source_name = self.get_source_name_for_source_id(source_id, xref_dbi)
        source_ids = {
            "ccds": self.get_source_id_for_source_name(self_source_name, xref_dbi, "ccds"),
            "entrezgene_manual": self.get_source_id_for_source_name(self_source_name, xref_dbi, "entrezgene_manual"),
            "refseq_manual": self.get_source_id_for_source_name(self_source_name, xref_dbi, "refseq_manual"),
            "ensembl_manual": self.get_source_id_for_source_name(self_source_name, xref_dbi, "ensembl_manual"),
            "desc_only": self.get_source_id_for_source_name(self_source_name, xref_dbi, "desc_only"),
            "lrg": self.get_source_id_for_source_name("LRG_HGNC_notransfer", xref_dbi),
            "genecards": self.get_source_id_for_source_name("GeneCards", xref_dbi),
        }

        # Statistics counts
        name_count = {key: 0 for key in source_ids}

        # Connect to the ccds db
        ccds_db_url = db_url or self.construct_db_url(file_params)
        if not ccds_db_url:
            raise AttributeError("No ensembl ccds database provided")
        if verbose:
            logging.info(f"Found ccds DB: {ccds_db_url}")

        # Get HGNC file (wget or disk)
        mem_file = self.fetch_file(file_params, xref_file)

        # Make sure the file is utf8
        mem_file = codecs.encode(mem_file, "utf-8").decode("utf-8")
        mem_file = re.sub(r'"', '', mem_file)

        with self.get_filehandle(mem_file) as file_io:
            if file_io.read(1) == '':
                raise IOError(f"HGNC file is empty")
            file_io.seek(0)

            csv_reader = csv.DictReader(file_io, delimiter="\t")

            syn_count = self.process_lines(csv_reader, source_ids, name_count, species_id, ccds_db_url, xref_dbi)

        result_message = "HGNC xrefs loaded:\n"
        for count_type, count in name_count.items():
            if count_type == "desc_only": continue
            result_message += f"\t{count_type}\t{count}\n"
        result_message += f"{syn_count} synonyms added\n"
        result_message += f"{name_count['desc_only']} HGNC ids could not be associated in xrefs"

        result_message = re.sub(r"\n", "--", result_message)

        return 0, result_message

    def process_lines(self, csv_reader: csv.DictReader, source_ids: Dict[str, int], name_count: Dict[str, int], species_id: int, ccds_db_url: str, xref_dbi: Connection) -> int:
        # Prepare lookup lists
        refseq = self.get_acc_to_xref_ids("refseq", species_id, xref_dbi)
        source_list = ["refseq_peptide", "refseq_mRNA"]
        entrezgene = self.get_valid_xrefs_for_dependencies("EntrezGene", source_list, xref_dbi)

        # Get CCDS data
        ccds_to_ens = self.get_ccds_to_ens_mapping(ccds_db_url)

        synonym_count = 0

        # Helper function to add direct xrefs and synonyms
        def add_direct_xref_and_synonyms(source_key: str, accession: str, symbol: str, feature_id: str, name: str, previous_symbols: str, synonyms: str) -> Tuple[int, int]:
            xref_id = self.add_xref(
                {
                    "accession": accession,
                    "label": symbol,
                    "description": name,
                    "source_id": source_ids[source_key],
                    "species_id": species_id,
                    "info_type": "DIRECT",
                },
                xref_dbi,
            )
            self.add_direct_xref(xref_id, feature_id, "gene", "", xref_dbi)
            name_count[source_key] += 1

            count = self.add_synonyms_for_hgnc(
                {
                    "source_id": source_ids[source_key],
                    "name": accession,
                    "species_id": species_id,
                    "dead": previous_symbols,
                    "alias": synonyms,
                },
                xref_dbi,
            )

            return xref_id, count

        # Helper function to add dependent xrefs and synonyms
        def add_dependent_xref_and_synonyms(source_key: str, master_xrefs: List[int], accession: str, symbol: str, name: str, previous_symbols: str, synonyms: str) -> int:
            for xref_id in master_xrefs:
                self.add_dependent_xref(
                    {
                        "master_xref_id": xref_id,
                        "accession": accession,
                        "label": symbol,
                        "description": name,
                        "source_id": source_ids[source_key],
                        "species_id": species_id,
                    },
                    xref_dbi,
                )
                name_count[source_key] += 1

            count = self.add_synonyms_for_hgnc(
                {
                    "source_id": source_ids[source_key],
                    "name": accession,
                    "species_id": species_id,
                    "dead": previous_symbols,
                    "alias": synonyms,
                },
                xref_dbi,
            )

            return count

        # Read lines
        for line in csv_reader:
            accession = line["HGNC ID"]
            symbol = line["Approved symbol"]
            name = line["Approved name"]
            previous_symbols = line["Previous symbols"]
            synonyms = line["Alias symbols"]

            seen = False

            # Direct CCDS to ENST mappings
            ccds_list = re.split(r",\s", line["CCDS IDs"]) if line["CCDS IDs"] else []
            for ccds in ccds_list:
                enst_id = ccds_to_ens.get(ccds)
                if not enst_id:
                    continue

                direct_xref_id, syn_count = add_direct_xref_and_synonyms("ccds", accession, symbol, enst_id, name, previous_symbols, synonyms)
                synonym_count += syn_count

            # Direct LRG to ENST mappings
            lrg_id = self.extract_lrg_id(line["Locus specific databases"])
            if lrg_id:
                direct_xref_id, syn_count = add_direct_xref_and_synonyms("lrg", accession, symbol, lrg_id, name, previous_symbols, synonyms)
                synonym_count += syn_count

            # Direct Ensembl mappings
            ensg_id = line["Ensembl gene ID"]
            if ensg_id:
                seen = True

                direct_xref_id, syn_count = add_direct_xref_and_synonyms("ensembl_manual", accession, symbol, ensg_id, name, previous_symbols, synonyms)
                synonym_count += syn_count

                # GeneCards
                hgnc_id = re.search(r"HGNC:(\d+)", accession).group(1)
                synonym_count += add_dependent_xref_and_synonyms("genecards", [direct_xref_id], hgnc_id, symbol, name, previous_symbols, synonyms)

            # RefSeq
            refseq_id = line["RefSeq IDs"]
            if refseq_id and refseq.get(refseq_id):
                seen = True

                synonym_count += add_dependent_xref_and_synonyms("refseq_manual", refseq[refseq_id], accession, symbol, name, previous_symbols, synonyms)

            # EntrezGene
            entrez_id = line["NCBI Gene ID"]
            if entrez_id and entrezgene.get(entrez_id):
                seen = True

                synonym_count += add_dependent_xref_and_synonyms("entrezgene_manual", [entrezgene[entrez_id]], accession, symbol, name, previous_symbols, synonyms)

            # Store to keep descriptions if not stored yet
            if not seen:
                self.add_xref(
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
                name_count["desc_only"] += 1
                
                synonym_count += self.add_synonyms_for_hgnc(
                    {
                        "source_id": source_ids["desc_only"],
                        "name": accession,
                        "species_id": species_id,
                        "dead": previous_symbols,
                        "alias": synonyms,
                    },
                    xref_dbi,
                )

        return synonym_count

    def add_synonyms_for_hgnc(self, args: Dict[str, Any], dbi: Connection) -> int:
        source_id = args["source_id"]
        name = args["name"]
        species_id = args["species_id"]
        dead_string = args.get("dead")
        alias_string = args.get("alias")

        syn_count = 0

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
                syn_count += 1

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
                syn_count += 1
        
        return syn_count

    def parse_file_string(self, file_string: str) -> Dict[str, str]:
        file_string = re.sub(r"^\w+:", "", file_string)
        param_pairs = file_string.split(",")
        params = {}

        # Set provided values
        for pair in param_pairs:
            if "=>" in pair:
                key, value = pair.split("=>")
                params[key] = value

        return params

    def construct_db_url(self, file_params: Dict[str, str]) -> Optional[URL]:
        if file_params.get("host"):
            return URL.create(
                "mysql",
                file_params["user"],
                file_params["pass"],
                file_params["host"],
                file_params["port"],
                file_params["dbname"],
            )
        return None

    def get_ccds_to_ens_mapping(self, ccds_url: str) -> Dict[str, str]:
        db_engine = self.get_db_engine(ccds_url)
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
            ccds_id = re.sub(r"\.\d+", "", row.value) # Remove version
            
            ccds_to_ens[ccds_id] = row.stable_id

        return ccds_to_ens

    def fetch_file(self, file_params: Dict[str, str], file: str) -> str:
        if file_params.get("wget"):
            response = requests.get(file_params["wget"])
            if not response.ok:
                raise IOError(response.reason)
            return response.text
        return file

    def extract_lrg_id(self, lrg_id: str) -> Optional[str]:
        if lrg_id:
            match = re.search(r"(LRG_\d+)\|", lrg_id)
            if match:
                return match.group(1)
        return None
