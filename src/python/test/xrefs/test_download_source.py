import pytest
import os
import shutil
import datetime
from typing import Any, Dict, Callable, Optional
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count

from ensembl.production.xrefs.DownloadSource import DownloadSource

DEFAULT_ARGS = {
    "base_path": "dummy_base_path",
    "parser": "dummy_parser",
    "name": "dummy_name",
    "priority": 1,
    "source_db_url": "mysql://user:pass@host/db",
    "file": "dummy_file",
    "skip_download": False,
}

# Fixture to create a DownloadSource instance
@pytest.fixture
def download_source() -> Callable[[Optional[Dict[str, Any]]], DownloadSource]:
    def _create_download_source(args: Optional[Dict[str, Any]] = None) -> DownloadSource:
        # Use provided args or default to default_args
        args = args or DEFAULT_ARGS

        return DownloadSource(args, True, True)
    return _create_download_source

# Test case to check if an error is raised when a mandatory parameter is missing
def test_download_source_missing_required_param(test_missing_required_param: Callable[[str, Dict[str, Any], str], None]):
    test_missing_required_param("DownloadSource", DEFAULT_ARGS, "base_path")
    test_missing_required_param("DownloadSource", DEFAULT_ARGS, "parser")
    test_missing_required_param("DownloadSource", DEFAULT_ARGS, "name")
    test_missing_required_param("DownloadSource", DEFAULT_ARGS, "priority")
    test_missing_required_param("DownloadSource", DEFAULT_ARGS, "source_db_url")
    test_missing_required_param("DownloadSource", DEFAULT_ARGS, "file")
    test_missing_required_param("DownloadSource", DEFAULT_ARGS, "skip_download")

# Test case to check if an error is raised when an invalid URL scheme is provided
def test_invalid_url_scheme(download_source: DownloadSource, pytestconfig):
    # Setup for test parameters and create a ScheduleDownload instance
    test_scratch_path = pytestconfig.getoption("test_scratch_path")
    args = DEFAULT_ARGS.copy()
    args["base_path"] = test_scratch_path
    args["file"] = "wrong://dummy_file"
    download_source_instance = download_source(args)

    try:
        # Run the DownloadSource instance
        with pytest.raises(
            AttributeError, match="Invalid URL scheme wrong"
        ):
            download_source_instance.run()
    finally:
        # Cleanup: Remove the created path if it exists
        dummy_source_path = os.path.join(test_scratch_path, "dummy_name")
        if os.path.exists(dummy_source_path):
            shutil.rmtree(dummy_source_path)

# TO DO: Add test cases to check for ftp and copy cases + downloading version files

# Test case to check successful run
def test_successful_run(mock_source_dbi: DBConnection, download_source: DownloadSource, pytestconfig: pytest.Config):
    # Setup for test parameters and create a ScheduleDownload instance
    test_scratch_path = pytestconfig.getoption("test_scratch_path")
    args = {
        "base_path": test_scratch_path,
        "parser": "DBASSParser",
        "name": "DBASS3",
        "priority": 1,
        "source_db_url": mock_source_dbi.engine.url,
        "file": "https://www.dbass.soton.ac.uk/Dbass3/DownloadCsv",
        "skip_download": False,
    }
    download_source_instance = download_source(args)

    try:
        # Run the DownloadSource instance
        download_source_instance.run()

        # Check if the file was downloaded
        file_path = os.path.join(test_scratch_path, "DBASS3", "DownloadCsv")
        assert os.path.exists(file_path), "DBASS3 file not downloaded into the correct path"

        # Check if the source was added to the source table
        check_row_count(mock_source_dbi, "source", 1)
        check_row_count(mock_source_dbi, "version", 1)

        # Get the last modified time of the file
        timestamp = os.path.getmtime(file_path)
        last_modified = datetime.datetime.fromtimestamp(timestamp)

        # Run the DownloadSource instance again
        download_source_instance.run()

        # Check that the file was downloaded again
        timestamp = os.path.getmtime(file_path)
        new_last_modified = datetime.datetime.fromtimestamp(timestamp)
        assert new_last_modified > last_modified, "DBASS3 file not downloaded again"
        last_modified = new_last_modified

        # Set the skip_download parameter to True
        download_source_instance.set_param("skip_download", True)

        # Run the DownloadSource instance again
        download_source_instance.run()

        # Check that the file was not downloaded again
        timestamp = os.path.getmtime(file_path)
        new_last_modified = datetime.datetime.fromtimestamp(timestamp)
        assert new_last_modified == last_modified, "DBASS3 file downloaded again"
    finally:
        # Cleanup: Remove the created file and path if it exists
        source_path = os.path.join(test_scratch_path, "DBASS3")
        if os.path.exists(source_path):
            shutil.rmtree(source_path)