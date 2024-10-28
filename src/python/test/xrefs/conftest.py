import pytest
import os
import io
import re

from datetime import datetime
from unittest.mock import MagicMock
from typing import Any, Generator, Callable

from ensembl.utils.database import UnitTestDB, DBConnection
from ensembl.xrefs.xref_update_db_model import Base
from ensembl.production.xrefs.parsers.BaseParser import BaseParser

# Fixture to set up a test database
@pytest.fixture(scope="module")
def test_db() -> Generator[None, None, None]:
    # Create a unique database name using the current user and timestamp
    user = os.environ.get("USER", "testuser")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    db_name = f"{user}_test_xref_{timestamp}"
    mysql_url = f"mysql+pymysql://ensadmin:ensembl@mysql-ens-core-prod-1.ebi.ac.uk:4524/{db_name}"

    # Create all tables defined in the Base metadata
    with UnitTestDB(mysql_url, metadata=Base.metadata, name=db_name) as test_db:
        yield test_db

# Fixture to connect to the test database and close connection when done
@pytest.fixture
def mock_xref_dbi(test_db: UnitTestDB) -> Generator[Any, None, None]:
    conn = test_db.dbc.connect()
    yield conn
    conn.close()

# Common test for missing source_id
@pytest.fixture
def test_no_source_id() -> Callable[[BaseParser, int], None]:
    def _test_no_source_id(parser_instance: BaseParser, species_id: int = 9606) -> None:
        with pytest.raises(
            AttributeError, match=r"Missing required arguments: source_id(,| and) species_id(, and file)?"
        ):
            parser_instance.run(
                {
                    "species_id": species_id,
                    "file": "dummy_file.txt",
                    "xref_dbi": MagicMock(),
                }
            )
    return _test_no_source_id

# Common test for missing species_id
@pytest.fixture
def test_no_species_id() -> Callable[[BaseParser, int], None]:
    def _test_no_species_id(parser_instance: BaseParser, source_id: int = 1) -> None:
        with pytest.raises(
            AttributeError, match=r"Missing required arguments: source_id(,| and) species_id(, and file)?"
        ):
            parser_instance.run(
                {
                    "source_id": source_id,
                    "file": "dummy_file.txt",
                    "xref_dbi": MagicMock(),
                }
            )
    return _test_no_species_id

# Common test for missing file
@pytest.fixture
def test_no_file() -> Callable[[BaseParser, int, int], None]:
    def _test_no_file(parser_instance: BaseParser, source_id: int = 1, species_id: int = 9606) -> None:
        with pytest.raises(
            AttributeError, match="Missing required arguments: source_id, species_id, and file"
        ):
            parser_instance.run(
                {
                    "source_id": source_id,
                    "species_id": species_id,
                    "xref_dbi": MagicMock(),
                }
            )
    return _test_no_file

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