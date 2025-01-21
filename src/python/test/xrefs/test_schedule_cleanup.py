import pytest
import os
import shutil
from sqlalchemy import text
from typing import Any, Dict, Callable, Optional
from ensembl.utils.database import DBConnection
from test_helpers import check_dataflow_content

from ensembl.production.xrefs.ScheduleCleanup import ScheduleCleanup

DEFAULT_ARGS = {
    "base_path": "dummy_base_path",
    "source_db_url": "mysql://user:pass@host/db",
}

# Fixture to create a ScheduleCleanup instance
@pytest.fixture
def schedule_cleanup() -> Callable[[Optional[Dict[str, Any]]], ScheduleCleanup]:
    def _create_schedule_cleanup(args: Optional[Dict[str, Any]] = None) -> ScheduleCleanup:
        # Use provided args or default to default_args
        args = args or DEFAULT_ARGS

        return ScheduleCleanup(args, True, True)
    return _create_schedule_cleanup

# Function to populate the database with sources
def populate_source_db(mock_source_dbi: DBConnection):
    source_data = [
        [1, 'DBASS3', 'DBASSParser'],
        [2, 'RefSeq_dna', 'RefSeqParser'],
        [3, 'Uniprot/SWISSPROT', 'UniProtParser'],
        [4, 'VGNC', 'VGNCParser'],
    ]
    for row in source_data:
        mock_source_dbi.execute(
            text("INSERT INTO source (source_id, name, parser) VALUES (:source_id, :name, :parser)"),
            {"source_id": row[0], "name": row[1], "parser": row[2],}
        )

    version_data = [
        [1, 1, ''],
        [2, 2, 'dummy_base_path/RefSeq_dna/RefSeq-release200.txt'],
        [3, 1, 'dummy_base_path/UniprotSWISSPROT/reldate.txt'],
        [4, 1, ''],
    ]
    for row in version_data:
        mock_source_dbi.execute(
            text("INSERT INTO version (source_id, priority, revision) VALUES (:source_id, :priority, :revision)"),
            {"source_id": row[0], "priority": row[1], "revision": row[2],}
        )

    mock_source_dbi.commit()

# Test case to check if an error is raised when a mandatory parameter is missing
def test_schedule_cleanup_missing_required_param(test_missing_required_param: Callable[[str, Dict[str, Any], str], None]):
    test_missing_required_param("ScheduleCleanup", DEFAULT_ARGS, "base_path")
    test_missing_required_param("ScheduleCleanup", DEFAULT_ARGS, "source_db_url")

# Test case to check successful run
def test_successful_run(mock_source_dbi: DBConnection, schedule_cleanup: ScheduleCleanup, pytestconfig: pytest.Config):
    # Setup for test parameters and create a ScheduleCleanup instance
    test_scratch_path = pytestconfig.getoption("test_scratch_path")
    args = {
        "base_path": test_scratch_path,
        "source_db_url": mock_source_dbi.engine.url,
        "dataflow_output_path": test_scratch_path
    }
    schedule_cleanup_instance = schedule_cleanup(args)

    dataflow_file_path = os.path.join(test_scratch_path, "dataflow_cleanup_sources.json")
    try:
        # Run the DownloadSource instance without any sources to clean up
        schedule_cleanup_instance.run()

        # Check that the dataflow file is created
        assert os.path.exists(dataflow_file_path), f"Expected file {dataflow_file_path} not found"

        # Check that the dataflow file is empty then remove it
        assert os.path.getsize(dataflow_file_path) == 0, f"Expected file {dataflow_file_path} to be empty"
        os.remove(dataflow_file_path)

        # Add source data into source db
        populate_source_db(mock_source_dbi)

        # Run the ScheduleCleanup instance again without existing source folders
        schedule_cleanup_instance.run()

        # Check that the dataflow file is created
        assert os.path.exists(dataflow_file_path), f"Expected file {dataflow_file_path} not found"

        # Check that the dataflow file is empty then remove it
        assert os.path.getsize(dataflow_file_path) == 0, f"Expected file {dataflow_file_path} to be empty"
        os.remove(dataflow_file_path)

        # Create source folders for cleanup
        os.makedirs(f"{test_scratch_path}/RefSeq_dna")
        os.makedirs(f"{test_scratch_path}/UniprotSWISSPROT")

        # Run the ScheduleCleanup instance again
        schedule_cleanup_instance.run()

        # Check the content of the dataflow file
        expected_content = [
            {"name": "RefSeq_dna", "version_file": "dummy_base_path/RefSeq_dna/RefSeq-release200.txt"},
            {"name": "Uniprot/SWISSPROT", "version_file": "dummy_base_path/UniprotSWISSPROT/reldate.txt"}
        ]
        check_dataflow_content(dataflow_file_path, expected_content)
    finally:
        # Cleanup: Remove the dataflow file if it exists
        if os.path.exists(dataflow_file_path):
            os.remove(dataflow_file_path)

        # Cleanup: Remove the created paths if they exist
        for source_path in [os.path.join(test_scratch_path, "RefSeq_dna"), os.path.join(test_scratch_path, "UniprotSWISSPROT")]:
            if os.path.exists(source_path):
                shutil.rmtree(source_path)
