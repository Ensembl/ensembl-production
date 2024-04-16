"""
.. See the NOTICE file distributed with this work for additional information
   regarding copyright ownership.
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

import argparse
import contextlib
import mysql
import sys

from ensembl.util.mongo import MongoDbClient
from ensembl.util.mysql import MySQLClient
from ensembl.util.utils import load_config

"""
The aim of this script is to compare the number of genes, transcripts, proteins and exons 
loaded to MongoDB with those stored in the core DB, to check if data is loaded properly
Usage:
    python src/ensembl/count_data.py --config /path/to/ensembl-thoas-configs/load-110_241_vinay.conf
e.g.
    python src/ensembl/count_data.py --config ../ensembl-thoas-configs/load-110_241_vinay.conf
"""


def count_queries(mongo_client, mysqldb_cursor, genome_id, prod_name, doc_type):
    """
    Count by Types (Genes, Transcripts..) and compare data
    in both Core MySQL DB and MongoDb
    """
    # db table name where the data will be fetched from
    db_table_name = ""

    # pipeline is used top count exons
    # Exons are a tricky ones, we will be getting them from inside transcript
    pipeline = [
        {"$unwind": "$spliced_exons"},
        {
            "$match": {
                "genome_id": genome_id,
            }
        },
        {
            "$group": {
                "_id": None,
                "uniqueCount": {"$addToSet": "$spliced_exons.exon.stable_id"},
            }
        },
        {"$project": {"uniqueExonsCount": {"$size": "$uniqueCount"}}},
    ]

    if doc_type == "Gene":
        db_table_name = "gene"

    if doc_type == "Transcript":
        db_table_name = "transcript"

    if doc_type == "Exon":
        db_table_name = "exon"

    count_query = (
            """
        SELECT COUNT(*) FROM """
            + db_table_name
            + """
        JOIN seq_region USING(seq_region_id)
        JOIN coord_system USING(coord_system_id)
        JOIN meta USING(species_id)
        WHERE coord_system.name IN ('chromosome', 'scaffold', 'primary_assembly', 'supercontig')
        AND meta_key='species.production_name'
        AND meta_value='"""
            + prod_name
            + """'
    """
    )

    # Proteins are an exception, since we would like to
    # ignore supercontig and scaffold and keep chromosome only
    # ref: https://www.ebi.ac.uk/panda/jira/browse/EA-1080
    if doc_type == "Protein":
        count_query = (
                """
            SELECT COUNT(*) FROM translation
            JOIN transcript USING(transcript_id)
            JOIN seq_region USING(seq_region_id)
            JOIN coord_system USING(coord_system_id)
            JOIN meta USING(species_id)
            WHERE coord_system.name IN ('chromosome', 'scaffold', 'primary_assembly', 'supercontig')
            AND meta_key='species.production_name'
            AND meta_value='"""
                + prod_name
                + """'
        """
        )

    if doc_type == "Region":
        count_query = """
            SELECT COUNT(*)
            FROM (
                SELECT COUNT(*) FROM gene
                JOIN seq_region USING(seq_region_id)
                JOIN coord_system USING(coord_system_id)
                JOIN meta USING(species_id)
                JOIN analysis USING(analysis_id)
                WHERE meta_key='species.production_name'
                AND logic_name <> 'lrg_import'
                GROUP BY seq_region_id
            ) AS c;
        """

        # TODO: decide which query to keep
        count_query_slow_x10 = (
                """
            SELECT COUNT(DISTINCT(gene.seq_region_id))
            FROM gene INNER JOIN seq_region USING (seq_region_id)
            INNER JOIN (
                SELECT seq_region_id, value FROM seq_region_attrib
                    INNER JOIN attrib_type USING (attrib_type_id)
                    WHERE attrib_type.code = 'toplevel'
                ) as seq_reg USING (seq_region_id)
            INNER JOIN (
                SELECT seq_region_id, value FROM seq_region_attrib
                    INNER JOIN attrib_type USING (attrib_type_id)
                    WHERE attrib_type.code = 'md5_toplevel'
                ) as checksum USING (seq_region_id)
            INNER JOIN coord_system USING (coord_system_id)
            INNER JOIN (
                SELECT species_id, meta_value FROM meta
                WHERE meta_key = 'species.production_name'
            ) as species_name USING (species_id)
            INNER JOIN (
                SELECT species_id, meta_value FROM meta
                WHERE meta_key = 'assembly.accession'
            ) as accession USING (species_id)
            LEFT JOIN (
                SELECT seq_region_id, value FROM seq_region_attrib
                INNER JOIN attrib_type USING (attrib_type_id)
                WHERE attrib_type.code = 'circular_seq'
            ) as circular_regions USING (seq_region_id)
            WHERE species_name.meta_value='"""
                + prod_name
                + """';
        """
        )

    # execute both MySQL and Mongo queries
    try:
        mysqldb_cursor.execute(count_query)
        mysqldb_count = mysql_cursor.fetchone()[0]
    except (TypeError, mysql.connector.errors.ProgrammingError) as e:
        raise Exception(
            f"[ERROR] Couldn't find '{doc_type}', make sure it's a valid type."
        )

    try:
        if doc_type == "Exon":
            # Fetch the first result where the count is
            mongo_client.set_collection("transcript")
            mongodb_count = next(mongo_client.get_collection().aggregate(pipeline))[
                "uniqueExonsCount"
            ]
        else:
            mongo_client.set_collection(doc_type.lower())
            mongodb_count = mongo_client.get_collection().count_documents(
                {"genome_id": genome_id}
            )
    except Exception:
        raise StopIteration(
            f"Please make sure is mongo connected properly and '{mongo_client.collection_name}' collection exists"
        )

    return mysqldb_count, mongodb_count


if __name__ == "__main__":
    """
    This can be integrated into multi_load.py later (to keep the code DRY)
    """
    ARG_PARSER = argparse.ArgumentParser()
    ARG_PARSER.add_argument(
        "--config",
        help="Config file containing the database and division info for species and MongoDB",
        default="load.conf",
    )
    ARG_PARSER.add_argument(
        "--species", help="Ensembl Species production name"
    )

    CLI_ARGS = ARG_PARSER.parse_args()
    CONF_PARSER = load_config(CLI_ARGS.config, validation=False)

    # Connect to Mongo DB
    MONGO_CLIENT = MongoDbClient(CONF_PARSER)
    print(f"Counting from '{MONGO_CLIENT.mongo_db}' Mongo Database..")
    genes_per_species = []
    transcripts_per_species = []
    proteins_per_species = []
    exons_per_species = []
    regions_per_species = []
    asm_count = 1

    # section is equivalent to species production name
    section = CLI_ARGS.species

    # Connect to MySQL DB
    conn = MySQLClient(CONF_PARSER, section)
    mysql_cursor = conn.connection.cursor()

    genome_uuid = CONF_PARSER[section]["genome_uuid"]
    production_name = CONF_PARSER[section]["production_name"]

    mysql_genes_count, mongo_genes_count = count_queries(
        MONGO_CLIENT, mysql_cursor, genome_uuid, production_name, "Gene"
    )
    mysql_transcripts_count, mongo_transcripts_count = count_queries(
        MONGO_CLIENT, mysql_cursor, genome_uuid, production_name, "Transcript"
    )
    mysql_proteins_count, mongo_proteins_count = count_queries(
        MONGO_CLIENT, mysql_cursor, genome_uuid, production_name, "Protein"
    )
    # TODO: Exon Count is slow -> add an index?
    mysql_exons_count, mongo_exons_count = count_queries(
        MONGO_CLIENT, mysql_cursor, genome_uuid, production_name, "Exon"
    )
    mysql_regions_count, mongo_regions_count = count_queries(
        MONGO_CLIENT, mysql_cursor, genome_uuid, production_name, "Region"
    )

    genes_per_species.append([section, mysql_genes_count, mongo_genes_count])
    transcripts_per_species.append(
        [section, mysql_transcripts_count, mongo_transcripts_count]
    )
    proteins_per_species.append(
        [section, mysql_proteins_count, mongo_proteins_count]
    )
    exons_per_species.append([section, mysql_exons_count, mongo_exons_count])
    regions_per_species.append([section, mysql_regions_count, mongo_regions_count])

    with open(f"{section}_count.txt", "w") as file, contextlib.redirect_stdout(file):
        header = [
                "species",
                "MySQL Count",
                "Mongo Count",
        ]

        print(f"#type,{','.join(header)}")
        valid_genomic_feature_count = 0
        for doc_type, genomic_feature_count in [('Gene', genes_per_species), ('Transcript', transcripts_per_species),
                                                ('Proteins', proteins_per_species), ('Exons', exons_per_species),
                                                ('Regions', regions_per_species)]:

            print(f"{doc_type},{','.join([str(i) for i in genomic_feature_count[0]])}")

            if genomic_feature_count[0][1] != genomic_feature_count[0][2]:
                valid_genomic_feature_count = 1

    if valid_genomic_feature_count:
        print(f"[ERROR] Mismatch in genomic feature loaded into mongo collection for species {section}")
        sys.exit(1)
