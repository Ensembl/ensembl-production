import pytest
import io
import json
import os
from datetime import datetime
from unittest.mock import MagicMock, patch
from typing import Any, Dict, Callable, Optional
from sqlalchemy import create_engine, text
from sqlalchemy.engine.url import make_url
from test.xrefs.test_helpers import check_dataflow_content

from ensembl.production.xrefs.ScheduleDownload import ScheduleDownload

TEST_DIR = os.path.dirname(__file__)
FLATFILES_DIR = os.path.join(TEST_DIR, "flatfiles")

DEFAULT_ARGS = {
    "config_file": "dummy_config.json",
    "source_db_url": "mysql://user:pass@host/db",
    "reuse_db": False,
}

# Fixture to create a ScheduleDownload instance
@pytest.fixture
def schedule_download() -> Callable[[Optional[Dict[str, Any]]], ScheduleDownload]:
    def _create_schedule_download(args: Optional[Dict[str, Any]] = None) -> ScheduleDownload:
        # Use provided args or default to default_args
        args = args or DEFAULT_ARGS

        return ScheduleDownload(args, True, True)
    return _create_schedule_download

# Test case to check if an error is raised when a mandatory parameter is missing
def test_schedule_download_missing_required_param(test_missing_required_param: Callable[[str, Dict[str, Any], str], None]):
    test_missing_required_param("ScheduleDownload", DEFAULT_ARGS, "config_file")
    test_missing_required_param("ScheduleDownload", DEFAULT_ARGS, "source_db_url")
    test_missing_required_param("ScheduleDownload", DEFAULT_ARGS, "reuse_db")

# Test case to check if an error is raised when the config file has an invalid json format
def test_invalid_config_file(schedule_download: ScheduleDownload):
    # Create a ScheduleDownload instance
    schedule_download_instance = schedule_download()

    # Create an invalid json file
    mock_file = io.StringIO('[{"name": "source1", "parser": "parser1", "priority": 1, "file": "file1",}]')
    with patch("ensembl.production.xrefs.ScheduleDownload.open", return_value=mock_file, create=True):
        # Mock the create_source_db method
        schedule_download_instance.create_source_db = MagicMock()

        # Run the ScheduleDownload instance
        with pytest.raises(json.decoder.JSONDecodeError):
            schedule_download_instance.run()

# Test case to check if an error is raised when the config file is empty
def test_empty_config_file(schedule_download: ScheduleDownload):
    # Create a ScheduleDownload instance
    schedule_download_instance = schedule_download()

    # Create an empty json file
    mock_file = io.StringIO('[]')
    with patch("ensembl.production.xrefs.ScheduleDownload.open", return_value=mock_file, create=True):
        # Mock the create_source_db method
        schedule_download_instance.create_source_db = MagicMock()

        # Run the ScheduleDownload instance
        with pytest.raises(
            ValueError, match="No sources found in config file dummy_config.json. Need sources to run pipeline"
        ):
            schedule_download_instance.run()

# TO DO: Add test case for reuse_db set to True

# Test case to check successful run
def test_successful_run(schedule_download: ScheduleDownload, pytestconfig):
    # Setup for test parameters and create a ScheduleDownload instance
    test_scratch_path = pytestconfig.getoption("test_scratch_path")
    test_mysql_url = pytestconfig.getoption("test_db_url")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    user_name = os.getenv("USER", "default_user")
    test_db_name = f"{user_name}_test_xref_source_db_{timestamp}"
    args = {
        "config_file": os.path.join(FLATFILES_DIR, "sources_download.json"),
        "source_db_url": f"{test_mysql_url}/{test_db_name}",
        "reuse_db": False,
        "dataflow_output_path": test_scratch_path
    }
    schedule_download_instance = schedule_download(args)

    # Create a db engine for connection
    test_engine = create_engine(make_url(test_mysql_url), isolation_level="AUTOCOMMIT")

    dataflow_file_path = os.path.join(test_scratch_path, "dataflow_sources.json")
    try:
        # Run the ScheduleDownload instance
        schedule_download_instance.run()

        # Check if the source db was created
        with test_engine.connect() as conn:
            result = conn.execute(text("SHOW DATABASES"))
            db_names = [row[0] for row in result.fetchall()]
            assert test_db_name in db_names, f"Expected database {test_db_name} not found"

        # Check if the dataflow file is created
        assert os.path.exists(dataflow_file_path), f"Expected file {dataflow_file_path} not found"

        # Check the content of the dataflow file
        expected_content = [
            {"parser": "ArrayExpressParser", "name": "ArrayExpress", "priority": 1, "db": "core", "file": "Database"},
            {"parser": "ChecksumParser", "name": "RNACentral", "priority": 1, "db": "checksum", "file": "https://ftp.ebi.ac.uk/pub/databases/RNAcentral/current_release/md5/md5.tsv.gz"}
        ]
        check_dataflow_content(dataflow_file_path, expected_content)
    finally:
        # Cleanup: Drop the test database if it exists
        with test_engine.connect() as conn:
            conn.execute(text(f"DROP DATABASE IF EXISTS {test_db_name}"))

        # Cleanup: Remove the dataflow file if it exists
        if os.path.exists(dataflow_file_path):
            os.remove(dataflow_file_path)
