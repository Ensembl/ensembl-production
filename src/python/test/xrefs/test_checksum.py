import pytest
import os
import shutil
import datetime
from typing import Any, Dict, Callable, Optional
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count

from ensembl.production.xrefs.Checksum import Checksum

DEFAULT_ARGS = {
    "base_path": "dummy_base_path",
    "source_db_url": "mysql://user:pass@host/db",
    "skip_download": False,
}

# Fixture to create a Checksum instance
@pytest.fixture
def checksum() -> Callable[[Optional[Dict[str, Any]]], Checksum]:
    def _create_checksum(args: Optional[Dict[str, Any]] = None) -> Checksum:
        # Use provided args or default to default_args
        args = args or DEFAULT_ARGS

        return Checksum(args, True, True)
    return _create_checksum

# Test case to check if an error is raised when a mandatory parameter is missing
def test_checksum_missing_required_param(test_missing_required_param: Callable[[str, Dict[str, Any], str], None]):
    test_missing_required_param("Checksum", DEFAULT_ARGS, "base_path")
    test_missing_required_param("Checksum", DEFAULT_ARGS, "source_db_url")
    test_missing_required_param("Checksum", DEFAULT_ARGS, "skip_download")

# Test case to check successful run
def test_successful_run(mock_source_dbi: DBConnection, checksum: Checksum, pytestconfig: pytest.Config):
    # Setup for test parameters and create a Checksum instance
    test_scratch_path = pytestconfig.getoption("test_scratch_path")
    args = {
        "base_path": test_scratch_path,
        "source_db_url": mock_source_dbi.engine.url,
        "skip_download": False,
    }
    checksum_instance = checksum(args)

    checksum_path = os.path.join(test_scratch_path, "Checksum")
    checksum_file = os.path.join(checksum_path, "checksum.txt")
    try:
        # Run the Checksum instance without checksum source files
        checksum_instance.run()

        # Check that the Checksum folder was created
        assert os.path.exists(test_scratch_path), "Checksum folder was not created"

        # Check that no checksum.txt file was created
        assert not os.path.exists(checksum_file), "File checksum.txt was created"

        # Copy some checksum files into the Checksum folder
        shutil.copy("flatfiles/RNACentral-md5.tsv.gz", checksum_path)
        shutil.copy("flatfiles/UniParc-upidump.lis", checksum_path)

        # Run the Checksum instance again
        checksum_instance.run()

        # Check that the checksum.txt file was created and is not empty
        assert os.path.exists(checksum_file), "File checksum.txt was not created"
        assert os.path.getsize(checksum_file) > 0, "File checksum.txt is empty"

        # Get the last modified time and size of the file
        timestamp = os.path.getmtime(checksum_file)
        last_modified = datetime.datetime.fromtimestamp(timestamp)
        size = os.path.getsize(checksum_file)

        # Check that the checksum rows were added
        check_row_count(mock_source_dbi, "checksum_xref", 30)

        # Run the Checksum instance again
        checksum_instance.run()

        # Check that the checksum.txt file was created again
        timestamp = os.path.getmtime(checksum_file)
        new_last_modified = datetime.datetime.fromtimestamp(timestamp)
        assert new_last_modified > last_modified, "File checksum.txt was created again"
        assert os.path.getsize(checksum_file) == size, "File checksum.txt does not have the same size"
        last_modified = new_last_modified

        # Check that the checksum rows are still the same
        check_row_count(mock_source_dbi, "checksum_xref", 30)

        # Set the skip_download parameter to True
        checksum_instance.set_param("skip_download", True)

        # Run the Checksum instance again
        checksum_instance.run()

        # Check that the checksum.txt file was not created again
        timestamp = os.path.getmtime(checksum_file)
        new_last_modified = datetime.datetime.fromtimestamp(timestamp)
        assert new_last_modified == last_modified, "File checksum.txt was created again"

        # Check that the checksum rows are still the same
        check_row_count(mock_source_dbi, "checksum_xref", 30)
    finally:
        # Cleanup: Remove the Checksum folder if it exists
        if os.path.exists(checksum_path):
            shutil.rmtree(checksum_path)