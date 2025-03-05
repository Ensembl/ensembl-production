#!/usr/bin/env python
"""
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2025] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

'''
Dump the json files for solr indexing  
'''

import re
import json
import argparse
import ijson
import logging
import os
from sqlalchemy import func
from ensembl.database import DBConnection
from sqlalchemy import select, text
from ensembl.core.models import Gene, Xref, SeqRegion, Analysis, AnalysisDescription, Biotype, AttribType, CoordSystem, \
    SeqRegionAttrib, Transcript, ExternalSynonym, Meta

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)
lrg_detector = re.compile("^LRG")


class JsonIterator(list):
    def __init__(self, it):
        self.it = it

    def __iter__(self):
        return self.it

    def __len__(self):
        return 1


def format_to_solr(gene, genome_uuid):
    gene_stable_id = get_stable_id(gene["id"], gene["version"])

    gene_name = re.sub(r"\[.*?\]", "", gene["description"]).rstrip() if gene[
                                                                            "description"] is not None else None,
    gene_name = str(gene_name[0]) if gene_name is not None else ""

    if gene_name.find(' [Source:') != -1:
        end_index = gene_name.find(' [Source:') + 1
        gene_name = gene_name[0:end_index]

    return {
        "type": "Gene",
        "stable_id": gene_stable_id,
        "unversioned_stable_id": gene["id"],
        "biotype": gene["biotype"],
        "symbol": gene["name"],
        "alternative_symbols": gene["alternative_symbols"].split(',') if gene[
                                                                             "alternative_symbols"] is not None else [],
        # Note that the description comes the long way via xref
        # pipeline and includes a [source: string]
        "name": gene_name if gene_name is not None else "",
        "slice.region.name": gene["seq_region_name"],
        "slice.location.start": int(gene['start']),
        "slice.location.end": int(gene['end']),
        "slice.strand.code": "forward" if int(gene["strand"]) > 0 else "reverse",
        "transcript_count": gene["transcript_count"],
        "genome_id": genome_uuid
    }


def fetch_gene_info(core_db_connection, specie_production_name, genome_uuid):
    """
    Fetch gene info from ensembl core db, only gene with toplevel seq-region are considered for solr indexing
    """
    # Set species id to fetch genes for specific species in collection db
    species_id = select(Meta.species_id).filter(Meta.meta_key == "species.production_name").filter(
        Meta.meta_value == f"{specie_production_name}").distinct()

    # Todo avoid subquery  by adding backref for Gene model in ensembl-py repo
    transcript_subquery = select(
        Transcript.gene_id,
        func.count(Transcript.transcript_id).label('transcript_count')
    ) \
        .group_by(Transcript.gene_id) \
        .subquery()

    # Todo avoid subquery  by adding backref for Gene model in ensembl-py repo
    synonyms_subquery = select(
        ExternalSynonym.xref_id,
        func.group_concat(ExternalSynonym.synonym).label('alternative_symbols')
    ) \
        .group_by(ExternalSynonym.xref_id) \
        .subquery()

    query = select(
        Gene.gene_id.label('gene_id'),
        Gene.stable_id.label('id'),
        Gene.version.label('version'),
        Xref.display_label.label('name'),
        Gene.description,
        Gene.biotype,
        Gene.source,
        Gene.seq_region_start.label('start'),
        Gene.seq_region_end.label('end'),
        Gene.seq_region_strand.label('strand'),
        SeqRegion.name.label('seq_region_name'),
        # 'gene'.label('ensembl_object_type'),
        Analysis.logic_name.label('analysis'),
        AnalysisDescription.display_label.label('analysis_display'),
        Biotype.so_term.label('so_term'),
        AttribType.code.label('sequence_attrib'),
        transcript_subquery.c.transcript_count,
        synonyms_subquery.c.alternative_symbols,

    ) \
        .select_from(Gene) \
        .join(Transcript, Transcript.gene_id == Gene.gene_id) \
        .outerjoin(Xref, Gene.display_xref_id == Xref.xref_id) \
        .join(SeqRegion, Gene.seq_region_id == SeqRegion.seq_region_id) \
        .join(CoordSystem, SeqRegion.coord_system_id == CoordSystem.coord_system_id) \
        .join(SeqRegionAttrib, SeqRegion.seq_region_id == SeqRegionAttrib.seq_region_id) \
        .join(AttribType, AttribType.attrib_type_id == SeqRegionAttrib.attrib_type_id) \
        .join(Analysis, Gene.analysis_id == Analysis.analysis_id) \
        .outerjoin(AnalysisDescription, Gene.analysis_id == AnalysisDescription.analysis_id) \
        .outerjoin(Biotype, (Biotype.name == Gene.biotype) & (Biotype.object_type == 'gene')) \
        .outerjoin(transcript_subquery, Gene.gene_id == transcript_subquery.c.gene_id) \
        .outerjoin(synonyms_subquery, Gene.display_xref_id == synonyms_subquery.c.xref_id) \
        .filter(CoordSystem.species_id == species_id.scalar_subquery()) \
        .filter(AttribType.code == 'toplevel') \
        .filter(Gene.source != 'LRG database') \
        .group_by(Gene.gene_id)

    logger.info(
        f"Fetch genes in toplevel regions for species {specie_production_name} with query: {query}"
    )
    with DBConnection(core_db_connection).session_scope() as session:
        session.execute(query).fetchall()
        count = 0
        for gene in session.execute(query).fetchall():
            count += 1
            yield format_to_solr(gene._asdict(), genome_uuid)

        if not count:
            logger.error(
                f"No Genes Fetched, Might be issue in Xref ids Not Linked to Gene"
            )


def is_valid_data_path(path):
    """Check if the given data path is a valid directory."""
    if not os.path.isdir(path):
        raise argparse.ArgumentTypeError(f"{path} is not a valid directory")
    return path


def get_stable_id(iid, version):
    "Get a stable_id with or without a version"
    stable_id = f"{iid}.{str(version)}" if version else iid
    return stable_id


def dump_gene_search_data(
        json_file,
        genome_uuid,
):
    """
    Reads from "custom download" gene JSON dumps and converts to suit
    Core Data Modelling schema.
    json_file = File containing gene data from production pipeline
    """
    gene_buffer = []

    # at least until there's a process for alt-alleles etc.
    default_region = True
    required_keys = ("name", "description")
    with open(json_file, encoding="UTF-8") as file:
        for gene in ijson.items(file, "item"):

            for key in required_keys:
                if key not in gene:
                    gene[key] = None
            # LRGs are difficult. They should probably be kept in another
            # Gene Set because they have little to do with Ensembl Genebuild
            if lrg_detector.search(gene["id"]):
                logger.warning(
                    f"Ignore Genes which are LRG {gene['id']} "
                )
                continue

            normalised_gene_biotype = gene["biotype"].lower()

            gene_stable_id = get_stable_id(
                gene["id"], gene["version"]
            )

            gene_name = re.sub(r"\[.*?\]", "", gene["description"]).rstrip() if gene[
                                                                                    "description"] is not None else None,
            gene_name = str(gene_name[0]) if gene_name is not None else ""
            if gene_name.find(' [Source:') != -1:
                end_index = gene_name.find(' [Source:') + 1
                gene_name = gene_name[0:end_index]
            # This is a temporary hack to only include top-level region.
            # This is not the sufficient criteria to include all top-level regions.
            # There are examples in rapid where it has  over 1 million top level regions, none of which are chromosomes
            # This should either be incorporated in the JSON search dump or some proper logic at this place
            if gene["coord_system"]["name"] != 'chromosome':
                logger.warning(
                    f"Ignore Genes which are not in chromosome {gene['id']} "
                )
                continue

            solr_json_gene = {
                "type": "Gene",
                "stable_id": gene_stable_id,
                "unversioned_stable_id": gene["id"],
                "biotype": gene["biotype"],
                "symbol": gene["name"],
                "alternative_symbols": gene["synonyms"] if "synonyms" in gene else [],
                # Note that the description comes the long way via xref
                # pipeline and includes a [source: string]
                "name": gene_name if gene_name is not None else "",
                "slice.region.name": gene["seq_region_name"],
                "slice.location.start": int(gene['start']),
                "slice.location.end": int(gene['end']),
                "slice.strand.code": "forward" if int(gene["strand"]) > 0 else "reverse",
                "transcript_count": len(gene["transcripts"]),
                "genome_id": genome_uuid
            }

            yield solr_json_gene


if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="Create Json dumps for solr indexing"
    )
    parser.add_argument(
        "--genome_uuid",
        help="Unique uuid string for a genome ",
        required=True
    )
    parser.add_argument(
        "--species",
        help="Ensembl Species Production Name",
        required=True
    )
    parser.add_argument(
        "--division",
        help="Ensembl Species Division Name ex: vertebrates",
        required=True
    )
    parser.add_argument(
        "--data_path",
        type=is_valid_data_path,
        help="Thoas/Search dumps directory path location",
    )
    parser.add_argument(
        "--core_db_uri",
        help="Ensembl core db host uri ex: mysql://localhost:3306/homo_sapiens_core_110_38",
    )
    parser.add_argument(
        '--output', type=str,
        help='output file ex: <genome_uuid>_toplevel_solr.json'
    )

    ARGS = parser.parse_args()

    if not (ARGS.data_path != '' and ARGS.core_db_uri != ''):
        raise argparse.ArgumentTypeError(f"One of the param required --data_path or --core_db_uri")

    if ARGS.data_path and ARGS.core_db_uri:
        raise argparse.ArgumentTypeError(f"One of the param required --data_path or --core_db_uri")

    species = ARGS.species
    division = ARGS.division
    genome_uuid = ARGS.genome_uuid
    db_collection_regex = re.compile(
        r'^(?P<prefix>\w+_collection)_(?P<type>core|rnaseq|cdna|otherfeatures|variation|funcgen)(_\d+)?_(\d+)_(?P<assembly>\d+)$')
    # replace division name with production division name
    pattern = re.compile(r'^(ensembl)?', re.IGNORECASE)
    division = pattern.sub('', division).lower()

    db_details = re.match(r"mysql:\/\/.*:?(.*?)@(.*?):\d+\/(?P<dbname>.*)", ARGS.core_db_uri)
    database_name = db_details.group('dbname')

    JSON_FILE = ""
    if ARGS.data_path:
        # set search path for species which are not in collection
        specific_path = f"{division}/json/"
        if db_collection_regex.match(database_name):
            collection_match = db_collection_regex.match(database_name)
            db_prefix = database_name.group('prefix')
            specific_path = f"{division}/json/{db_prefix}"

        JSON_FILE = os.path.join(ARGS.data_path, specific_path, species, f"{species}_genes.json")

        if not os.path.exists(JSON_FILE):
            raise FileNotFoundError(f" File Not Found {JSON_FILE}")

    # dump the json file with gene and assembly information for solr indexes
    OUTPUT_FILENAME = ARGS.output
    if not OUTPUT_FILENAME:
        OUTPUT_FILENAME = f"{genome_uuid}_toplevel_solr.json"

    logger.info(
        f"Generating Genesearch index files for species : {species}"
    )
    logger.info(
        f"Writing Solr index file to {OUTPUT_FILENAME} "
    )
    with open(OUTPUT_FILENAME, 'w') as out:
        if ARGS.core_db_uri:
            logger.info(
                f"Fetching Gene information from core db : {database_name}  , host: {ARGS.core_db_uri}"
            )
            json.dump(JsonIterator(fetch_gene_info(ARGS.core_db_uri, species, genome_uuid)), out, indent=4)
        if ARGS.data_path:
            logger.info(
                f"Fetching Gene information from Search Dumps {JSON_FILE}"
            )
            json.dump(JsonIterator(
                dump_gene_search_data(JSON_FILE, genome_uuid)
            ), out, indent=4)

        logger.info(
            f"Solr index file {OUTPUT_FILENAME} Completed!"
        )

