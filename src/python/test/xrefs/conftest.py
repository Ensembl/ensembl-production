import pymysql
pymysql.install_as_MySQLdb()

import pytest
import io
import re
import os
import importlib

from datetime import datetime
from unittest.mock import MagicMock
from typing import Any, Generator, Callable, Dict

from ensembl.utils.database import UnitTestDB, DBConnection
from ensembl.xrefs.xref_update_db_model import Base as BaseUpdateORM
from ensembl.xrefs.xref_source_db_model import Base as BaseSourceORM
from ensembl.production.xrefs.parsers.BaseParser import BaseParser

# Adding custom command-line options to pytest
def pytest_addoption(parser):
    parser.addoption(
        "--test_db_url",
        action="store",
        default=os.getenv("TEST_DB_URL"),
        help="MySQL URL to use for the test databases",
    )
    parser.addoption(
        "--test_scratch_path",
        action="store",
        default=os.getenv("TEST_SCRATCH_PATH"),
        help="Path to a scratch directory to use for temporary files",
    )

# Fixture to set up a xref test database
@pytest.fixture(scope="module")
def test_xref_db(pytestconfig: pytest.Config) -> Generator[UnitTestDB, None, None]:
    # Retrieve the test DB URL
    test_db_url = pytestconfig.getoption("test_db_url")
    if not test_db_url:
        raise ValueError(f"DB URL for test database must be provided")

    # Create a unique database name using the timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    db_name = f"test_xref_update_{timestamp}"
    full_test_db_url = f"{test_db_url}/{db_name}"

    # Create all tables defined in the Base metadata
    with UnitTestDB(full_test_db_url, metadata=BaseUpdateORM.metadata, name=db_name) as test_db:
        yield test_db

# Fixture to connect to the xref test database and close connection when done
@pytest.fixture
def mock_xref_dbi(test_xref_db) -> Generator[Any, None, None]:
    conn = test_xref_db.dbc.connect()
    yield conn
    conn.close()

# Fixture to set up a source test database
@pytest.fixture(scope="module")
def test_source_db(pytestconfig: pytest.Config) -> Generator[UnitTestDB, None, None]:
    # Retrieve the test DB URL
    test_db_url = pytestconfig.getoption("test_db_url")
    if not test_db_url:
        raise ValueError(f"DB URL for test database must be provided")

    # Create a unique database name using the timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    db_name = f"test_xref_source_{timestamp}"
    full_test_db_url = f"{test_db_url}/{db_name}"

    # Create all tables defined in the Base metadata
    with UnitTestDB(full_test_db_url, metadata=BaseSourceORM.metadata, name=db_name) as test_db:
        yield test_db

# Fixture to connect to the source test database and close connection when done
@pytest.fixture
def mock_source_dbi(test_source_db) -> Generator[Any, None, None]:
    conn = test_source_db.dbc.connect()
    yield conn
    conn.close()

# @pytest.fixture
# def mock_source_db_url(test_source_db):
#     return test_source_db.dbc.url

# Common test for missing argument
@pytest.fixture
def test_parser_missing_argument() -> Callable[[BaseParser, str, int, int], None]:
    def _test_parser_missing_argument(parser_instance: BaseParser, arg_name: str, source_id: int = 1, species_id: int = 9606) -> None:
        parser_args = {
            "source_id": source_id,
            "species_id": species_id,
            "file": "dummy_file.txt",
            "xref_dbi": MagicMock(),
        }
        if arg_name in parser_args:
            del parser_args[arg_name]

        with pytest.raises(
            AttributeError, match=r"Missing required arguments: source_id(,| and) species_id(, and file)?"
        ):
            parser_instance.run(parser_args)
    return _test_parser_missing_argument

# Common test for file not found
@pytest.fixture
def test_file_not_found() -> Callable[[BaseParser, int, int], None]:
    def _test_file_not_found(parser_instance: BaseParser, source_id: int = 1, species_id: int = 9606) -> None:
        with pytest.raises(FileNotFoundError, match=f"Could not find either"):
            parser_instance.run(
                {
                    "source_id": source_id,
                    "species_id": species_id,
                    "file": "flatfiles/non_existent_file.txt",
                    "xref_dbi": MagicMock(),
                }
            )
    return _test_file_not_found

# Common test for empty file
@pytest.fixture
def test_empty_file() -> Callable[[BaseParser, str, int, int], None]:
    def _test_empty_file(parser_instance: BaseParser, source_name: str, source_id: int = 1, species_id: int = 9606) -> None:
        mock_file = io.StringIO("")
        parser_instance.get_filehandle = MagicMock(return_value=mock_file)

        with pytest.raises(IOError, match=f"{source_name} file is empty"):
            parser_instance.run(
                {
                    "source_id": source_id,
                    "species_id": species_id,
                    "file": "dummy_file.txt",
                    "xref_dbi": MagicMock(),
                }
            )
    return _test_empty_file

@pytest.fixture
def test_missing_required_source_id() -> Callable[[BaseParser, DBConnection, str, int, int, str], None]:
    def _test_missing_required_source_id(parser_instance: BaseParser, mock_dbi: DBConnection, source_name: str, source_id: int = 1, species_id: int = 9606, priority_desc: str = None) -> None:
        mock_file = io.StringIO("test file")
        parser_instance.get_filehandle = MagicMock(return_value=mock_file)

        if priority_desc is not None:
            source_name = f"{source_name} ({priority_desc})"

        with pytest.raises(
            KeyError, match=re.escape(f"No source_id for source_name={source_name}")
        ):
            parser_instance.run(
                {
                    "source_id": source_id,
                    "species_id": species_id,
                    "file": "dummy_file.txt",
                    "xref_dbi": mock_dbi,
                }
            )
    return _test_missing_required_source_id

# Common test for missing required parameter
@pytest.fixture
def test_missing_required_param() -> Callable[[str, Dict[str, Any], str], None]:
    def _test_missing_required_param(module_name: str, args: Dict[str, Any], param_name: str) -> None:
        # Remove the param name being tested from the args
        current_args = args.copy()
        if param_name in current_args:
            del current_args[param_name]

        # Import the module and create an instance
        module = importlib.import_module(f"ensembl.production.xrefs.{module_name}")
        module_class = getattr(module, module_name)
        module_object = module_class(current_args, True, True)

        with pytest.raises(
            AttributeError, match=f"Parameter '{param_name}' is required but has no value"
        ):
            module_object.run()
    return _test_missing_required_param