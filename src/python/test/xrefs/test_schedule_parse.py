import pytest
import os
from unittest.mock import MagicMock
from sqlalchemy import create_engine, text
from sqlalchemy.engine.url import make_url
from typing import Any, Dict, Callable, Optional
from ensembl.utils.database import DBConnection
from test.xrefs.test_helpers import check_row_count, check_dataflow_content

from ensembl.production.xrefs.ScheduleParse import ScheduleParse

DEFAULT_ARGS = {
    "species_name": "test_homo_sapiens_test",
    "release": 999,
    "registry_url": "http://dummy_registry",
    "priority": 1,
    "source_db_url": "mysql://user:pass@host/source_db",
    "xref_db_url": "mysql://user:pass@host/xref_db",
    "get_species_file": False,
    "species_db": "mysql://user:pass@host/core_db",
}

# Fixture to create a ScheduleParse instance
@pytest.fixture
def schedule_parse() -> Callable[[Optional[Dict[str, Any]]], ScheduleParse]:
    def _create_schedule_parse(args: Optional[Dict[str, Any]] = None) -> ScheduleParse:
        # Use provided args or default to default_args
        args = args or DEFAULT_ARGS

        return ScheduleParse(args, True, True)
    return _create_schedule_parse

# Function to populate the database with sources
def populate_source_db(mock_source_dbi: DBConnection):
    source_data = [
        [1, 'ArrayExpress', 'ArrayExpressParser'],
        [2, 'UniParc', 'ChecksumParser'],
        [3, 'DBASS3', 'DBASSParser'],
        [4, 'MIM', 'MIMParser'],
        [5, 'Reactome', 'ReactomeParser'],
        [6, 'RefSeq_dna', 'RefSeqParser'],
        [7, 'RefSeq_peptide', 'RefSeqParser'],
        [8, 'VGNC', 'VGNCParser'],
    ]
    for row in source_data:
        mock_source_dbi.execute(
            text("INSERT INTO source (source_id, name, parser) VALUES (:source_id, :name, :parser)"),
            {"source_id": row[0], "name": row[1], "parser": row[2],}
        )

    version_data = [
        [1, 'Database', 'core', 1, None, None],
        [2, 'dummy_uniparc_file_path', 'checksum', 1, None, None],
        [3, 'dummy_dbass_file_path', None, 1, None, None],
        [4, 'dummy_mim_file_path', None, 2, None, None],
        [5, 'dummy_reactome_file_path', None, 2, 'dummy_reactome_release', None],
        [6, 'dummy_refseq_dna_file_path', None, 2, 'dummy_refseq_dna_release', 'dummy_refseq_dna_clean_path'],
        [7, 'dummy_refseq_peptide_file_path', None, 3, 'dummy_refseq_peptide_release', 'dummy_refseq_peptide_clean_path'],
        [8, 'dummy_vgnc_file_path', None, 1, None, None],
    ]
    for row in version_data:
        mock_source_dbi.execute(
            text("INSERT INTO version (source_id, file_path, db, priority, revision, clean_path) VALUES (:source_id, :file_path, :db, :priority, :revision, :clean_path)"),
            {"source_id": row[0], "file_path": row[1], "db": row[2], "priority": row[3], "revision": row[4], "clean_path": row[5]}
        )

    mock_source_dbi.commit()

# Test case to check if an error is raised when a mandatory parameter is missing
def test_schedule_parse_missing_required_param(test_missing_required_param: Callable[[str, Dict[str, Any], str], None]):
    required_params = ["species_name", "release", "registry_url", "priority", "source_db_url", "xref_db_url", "get_species_file"]
    for param in required_params:
        test_missing_required_param("ScheduleParse", DEFAULT_ARGS, param)

# Test case to check if an error is raised when priority is invalid
def test_invalid_priority(schedule_parse: ScheduleParse):
    args = DEFAULT_ARGS.copy()
    args["priority"] = 4
    schedule_parse_instance = schedule_parse(args)

    with pytest.raises(AttributeError, match="Parameter 'priority' can only be of value 1, 2, or 3"):
        schedule_parse_instance.run()

# Test case to check successful run
def test_successful_run(mock_source_dbi: DBConnection, schedule_parse: ScheduleParse, pytestconfig):
    # Setup for test parameters and create a ScheduleParse instance
    test_scratch_path = pytestconfig.getoption("test_scratch_path")
    test_mysql_url = pytestconfig.getoption("test_db_url")
    args = DEFAULT_ARGS.copy()
    args["source_db_url"] = mock_source_dbi.engine.url
    args["xref_db_url"] = test_mysql_url
    args["dataflow_output_path"] = test_scratch_path
    args["sources_config_file"] = "flatfiles/config.ini"
    schedule_parse_instance = schedule_parse(args)

    # Add source data into source db
    populate_source_db(mock_source_dbi)

    # Mock needed methods
    schedule_parse_instance.get_core_db_info = MagicMock(return_value=(9606, 7742))

    # Create a db engine for connection
    test_engine = create_engine(make_url(test_mysql_url), isolation_level="AUTOCOMMIT")

    try:
        # Run the ScheduleParse instance with priority 1
        schedule_parse_instance.run()

        # Check if the xref update db was created
        with test_engine.connect() as conn:
            result = conn.execute(text("SHOW DATABASES"))
            db_names = [row[0] for row in result.fetchall()]
            assert "test_homo_sapiens_test_xref_update_999" in db_names, "Expected database test_homo_sapiens_test_xref_update_999 not found"

            # Connect to the db itself and create a table
            db_engine = create_engine(make_url(f"{test_mysql_url}/test_homo_sapiens_test_xref_update_999"), isolation_level="AUTOCOMMIT")
            with db_engine.connect() as db_conn:
                check_row_count(db_conn, "source", 11)
                check_row_count(db_conn, "source_url", 14)
                check_row_count(db_conn, "species", 3)

                # Get the source ids
                source_ids = {}
                result = db_conn.execute(text("SELECT source_id,name,priority_description FROM source")).all()
                for row in result:
                    if source_ids.get(row[1]):
                        source_ids[row[1]].update({row[2]: row[0]})
                    else:
                        source_ids[row[1]] = {row[2]: row[0]}

                # Get

        # Check the dataflow files
        expected_content = {
            "primary_sources": [
                {
                    "species_name": "test_homo_sapiens_test", "species_id": 9606, "core_db_url": "mysql://user:pass@host/core_db", "xref_db_url": f"{test_mysql_url}/test_homo_sapiens_test_xref_update_999",
                    "source_id": source_ids["ArrayExpress"]["multi"], "source_name": "ArrayExpress", "parser": "ArrayExpressParser", "db": "core", "file_name": "Database"
                },
                {
                    "species_name": "test_homo_sapiens_test", "species_id": 9606, "core_db_url": "mysql://user:pass@host/core_db", "xref_db_url": f"{test_mysql_url}/test_homo_sapiens_test_xref_update_999",
                    "source_id": source_ids["DBASS3"]["human"], "source_name": "DBASS3", "parser": "DBASSParser", "file_name": "dummy_dbass_file_path"
                }
            ],
            "schedule_secondary": [
                {"species_name": "test_homo_sapiens_test", "species_db": "mysql://user:pass@host/core_db", "xref_db_url": f"{test_mysql_url}/test_homo_sapiens_test_xref_update_999"}
            ]
        }
        for dataflow_file in ["primary_sources", "schedule_secondary"]:
            # Check if the dataflow file is created
            dataflow_file_path = os.path.join(test_scratch_path, f"dataflow_{dataflow_file}.json")

            # Check the content of the dataflow file
            check_dataflow_content(dataflow_file_path, expected_content[dataflow_file])

        # Run the ScheduleParse instance again with priority 2
        schedule_parse_instance.set_param("priority", 2)
        schedule_parse_instance.set_param("xref_db_url", f"{test_mysql_url}/test_homo_sapiens_test_xref_update_999")
        schedule_parse_instance.run()

        # Check the dataflow files
        expected_content = {
            "secondary_sources": [
                {
                    "species_name": "test_homo_sapiens_test", "species_id": 9606, "core_db_url": "mysql://user:pass@host/core_db", "xref_db_url": f"{test_mysql_url}/test_homo_sapiens_test_xref_update_999",
                    "source_id": source_ids["MIM"]["human"], "source_name": "MIM", "parser": "MIMParser", "file_name": "dummy_mim_file_path"
                },
                {
                    "species_name": "test_homo_sapiens_test", "species_id": 9606, "core_db_url": "mysql://user:pass@host/core_db", "xref_db_url": f"{test_mysql_url}/test_homo_sapiens_test_xref_update_999",
                    "source_id": source_ids["Reactome"]["multi"], "source_name": "Reactome", "parser": "ReactomeParser", "release_file": "dummy_reactome_release", "file_name": "dummy_reactome_file_path"
                },
                {
                    "species_name": "test_homo_sapiens_test", "species_id": 9606, "core_db_url": "mysql://user:pass@host/core_db", "xref_db_url": f"{test_mysql_url}/test_homo_sapiens_test_xref_update_999",
                    "source_id": source_ids["RefSeq_dna"]["human"], "source_name": "RefSeq_dna", "parser": "RefSeqParser", "release_file": "dummy_refseq_dna_release", "file_name": "dummy_refseq_dna_clean_path"
                }
            ],
            "schedule_tertiary": [
                {"species_name": "test_homo_sapiens_test", "species_db": "mysql://user:pass@host/core_db", "xref_db_url": f"{test_mysql_url}/test_homo_sapiens_test_xref_update_999"}
            ]
        }
        for dataflow_file in ["secondary_sources", "schedule_tertiary"]:
            # Check if the dataflow file is created
            dataflow_file_path = os.path.join(test_scratch_path, f"dataflow_{dataflow_file}.json")

            # Check the content of the dataflow file
            check_dataflow_content(dataflow_file_path, expected_content[dataflow_file])

        # Run the ScheduleParse instance again with priority 2
        schedule_parse_instance.set_param("priority", 3)
        schedule_parse_instance.run()

        # Check the dataflow files
        expected_content = {
            "tertiary_sources": [
                {
                    "species_name": "test_homo_sapiens_test", "species_id": 9606, "core_db_url": "mysql://user:pass@host/core_db", "xref_db_url": f"{test_mysql_url}/test_homo_sapiens_test_xref_update_999",
                    "source_id": source_ids["RefSeq_peptide"]["human"], "source_name": "RefSeq_peptide", "parser": "RefSeqParser", "release_file": "dummy_refseq_peptide_release", "file_name": "dummy_refseq_peptide_clean_path"
                }
            ],
            "dump_ensembl": [
                {"species_name": "test_homo_sapiens_test", "species_db": "mysql://user:pass@host/core_db", "xref_db_url": f"{test_mysql_url}/test_homo_sapiens_test_xref_update_999"}
            ]
        }
        for dataflow_file in ["tertiary_sources", "dump_ensembl"]:
            # Check if the dataflow file is created
            dataflow_file_path = os.path.join(test_scratch_path, f"dataflow_{dataflow_file}.json")

            # Check the content of the dataflow file
            check_dataflow_content(dataflow_file_path, expected_content[dataflow_file])
    finally:
        # Cleanup: Drop the test database if it exists
        with test_engine.connect() as conn:
            conn.execute(text("DROP DATABASE IF EXISTS test_homo_sapiens_test_xref_update_999"))

        # Cleanup: Remove the dataflow files if they exist
        for dataflow_file in ["primary_sources", "schedule_secondary", "secondary_sources", "schedule_tertiary", "tertiary_sources", "dump_ensembl"]:
            dataflow_file_path = os.path.join(test_scratch_path, f"dataflow_{dataflow_file}.json")
            if os.path.exists(dataflow_file_path):
                os.remove(dataflow_file_path)
