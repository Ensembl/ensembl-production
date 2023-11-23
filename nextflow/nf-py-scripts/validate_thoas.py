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

import mysql

from ensembl.multi_load import get_default_collection_name
from ensembl.util.mongo import MongoDbClient
from ensembl.util.mysql import MySQLClient
from ensembl.util.utils import load_config
import logging

"""
The aim of this script is to compare the number of genes, transcripts, proteins and exons 
loaded to MongoDB collection with those stored in the core DB, to check if data is loaded properly
Usage:
python validate_thoas.py --config /path/to/ensembl-thoas-configs/load-108.conf --collection graphql_230402183410_a358938_108
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
                "type": "Transcript",
                # TODO: find a way to get rid of 'genome_id' since it can change
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
        WHERE coord_system.name IN ('chromosome', 'scaffold', 'primary_assembly')
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
            -- 'primary_assembly' is added for megaderma_lyra_gca004026885v1
            WHERE coord_system.name IN ('chromosome', 'scaffold', 'primary_assembly')
            AND meta_key='species.production_name'
            AND meta_value='"""
            + prod_name
            + """'
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
            mongodb_count = next(mongo_client.collection().aggregate(pipeline))[
                "uniqueExonsCount"
            ]
        else:
            mongodb_count = mongo_client.collection().count_documents(
                {"type": doc_type, "genome_id": genome_id}
            )
    except Exception:
        raise StopIteration(
            f"Please make sure is mongo connected properly and '{mongo_client.collection_name}' collection exists"
        )

    return mysqldb_count, mongodb_count


def pretty_print_table(count_list, doc_type):
    header = [
        "production_name ('" + doc_type + "' Count)",
        "MySQL Count",
        "Mongo Count",
        "Match",
    ]
    print("-" * 100)
    print("| {:60} | {:^10} | {:>10} | {:>5} |".format(*header))
    print("-" * 100)
    for row in count_list:
        print("| {:60} | {:^11} | {:>11} | {:^5} |".format(*row + [row[1] == row[2]]))
    print("-" * 100)
    mysql_total_count = sum(x[1] for x in count_list)
    mongo_total_count = sum(x[2] for x in count_list)
    total_list = ["Total", mysql_total_count, mongo_total_count] + [
        mysql_total_count == mongo_total_count
    ]
    print("| {:60} | {:^11} | {:>11} | {:^5} |".format(*total_list))
    print("-" * 100)


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
        "--collection", help="MongoDB collection name that will be used"
    )
    
    ARG_PARSER.add_argument(
        "--species_name", help="species production name"
    )

    CLI_ARGS = ARG_PARSER.parse_args()

    CONF_PARSER = load_config(CLI_ARGS.config, validation=False)

    mongo_collection_name = get_default_collection_name(
        CONF_PARSER["GENERAL"]["release"]
    )

    if CLI_ARGS.collection:
        mongo_collection_name = CLI_ARGS.collection
    else:
        mongo_collection_name = get_default_collection_name(
            CONF_PARSER["GENERAL"]["release"]
        )

    logging.basicConfig(filename=f"thoas.validation.{mongo_collection_name}.log", format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.DEBUG)
    # Connect to Mongo DB
    
    MONGO_CLIENT = MongoDbClient(CONF_PARSER, mongo_collection_name)
    print(f"Counting from '{mongo_collection_name}' collection..")
    genes_per_species = []
    transcripts_per_species = []
    proteins_per_species = []
    exons_per_species = []
    # each section of the file dictates a particular assembly to work on
    for section in CONF_PARSER.sections():
        # one section is MongoDB config, the rest are species info
        
        
        # section = CLI_ARGS.species_name
        if section in ["MONGO DB", "GENERAL", "METADATA DB", "TAXON DB"]:
            continue
        
        # skip section if section is not in args.species     
        if (CLI_ARGS.species_name) and (section not in [CLI_ARGS.species_name]):
            continue 

        # Connect to MySQL DB
        conn = MySQLClient(CONF_PARSER, section)
        mysql_cursor = conn.connection.cursor()

        genome_uuid = CONF_PARSER[section]["genome_uuid"]
        production_name = CONF_PARSER[section]["production_name"]
        #species_production = CONF_PARSER[section]["species_production"]

        mysql_transcripts_count, mongo_transcripts_count = count_queries(
            MONGO_CLIENT, mysql_cursor, genome_uuid, production_name, "Transcript"
        )
        mysql_proteins_count, mongo_proteins_count = count_queries(
            MONGO_CLIENT, mysql_cursor, genome_uuid, production_name, "Protein"
        )
        mysql_exons_count, mongo_exons_count = count_queries(
            MONGO_CLIENT, mysql_cursor, genome_uuid, production_name, "Exon"
        )
    

    # if mysql_genes_count!= mongo_genes_count \
    #     or mysql_transcripts_count != mongo_transcripts_count \
    #     or mysql_proteins_count != mongo_proteins_count \
    #     or mysql_exons_count != mongo_exons_count:
    #     logger.error(",".join([genome_uuid, production_name, 
    #                             f"Gene:{mysql_genes_count == mongo_genes_count}",
    #                             f"Transcript:{mysql_transcripts_count == mongo_transcripts_count}",
    #                             f"Protein:{mysql_proteins_count == mysql_proteins_count}",
    #                             f"Exon:{mysql_exons_count == mongo_exons_count}"
    #                             ]))
