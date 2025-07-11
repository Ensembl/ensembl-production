import pytest
import io
from unittest.mock import MagicMock
from typing import Callable

from ensembl.production.xrefs.parsers.UCSCParser import UCSCParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count

# Constants
SOURCE_ID_UCSC = 1
SPECIES_ID_HUMAN = 9606

# Fixture to create a UCSCParser instance
@pytest.fixture
def ucsc_parser() -> UCSCParser:
    return UCSCParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(ucsc_parser: UCSCParser, mock_xref_dbi: DBConnection, expected_xrefs: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = ucsc_parser.run(
        {
            "source_id": SOURCE_ID_UCSC,
            "species_id": SPECIES_ID_HUMAN,
            "file": "parsers/flatfiles/ucsc.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing UCSC data"
    assert (
        f"Loaded a total of {expected_xrefs} UCSC xrefs" in result_message
    ), f"{prefix}Expected 'Loaded a total of {expected_xrefs} UCSC xrefs' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_ucsc_missing_argument(ucsc_parser: UCSCParser, test_parser_missing_argument: Callable[[UCSCParser, str, int, int], None]) -> None:
    test_parser_missing_argument(ucsc_parser, "source_id", SOURCE_ID_UCSC, SPECIES_ID_HUMAN)
    test_parser_missing_argument(ucsc_parser, "species_id", SOURCE_ID_UCSC, SPECIES_ID_HUMAN)
    test_parser_missing_argument(ucsc_parser, "file", SOURCE_ID_UCSC, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is not found
def test_ucsc_file_not_found(ucsc_parser: UCSCParser, test_file_not_found: Callable[[UCSCParser, int, int], None]) -> None:
    test_file_not_found(ucsc_parser, SOURCE_ID_UCSC, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is empty
def test_ucsc_empty_file(ucsc_parser: UCSCParser, test_empty_file: Callable[[UCSCParser, str, int, int], None]) -> None:
    test_empty_file(ucsc_parser, 'UCSC', SOURCE_ID_UCSC, SPECIES_ID_HUMAN)

# Parametrized test case to check if an error is raised for various missing keys
@pytest.mark.parametrize(
    "line", [
        ("ENST00000619216.1\tchr1\t-\t17368\t17436\t17368\t17368\t1\t17368,\t17436,\t\t\n"),
        ("ENST00000619216.1\t \t-\t17368\t17436\t17368\t17368\t1\t17368,\t17436,\t\tuc031tla.1\n"),
        ("ENST00000619216.1\tchr1\t\t17368\t17436\t17368\t17368\t1\t17368,\t17436,\t\tuc031tla.1\n"),
        ("ENST00000619216.1\tchr1\t-\t\t17436\t17368\t17368\t1\t17368,\t17436,\t\tuc031tla.1\n"),
        ("ENST00000619216.1\tchr1\t-\t17368\t\t17368\t17368\t1\t17368,\t17436,\t\tuc031tla.1\n"),
        ("ENST00000619216.1\tchr1\t-\t17368\t17436\t17368\t17368\t1\t\t17436,\t\tuc031tla.1\n"),
        ("ENST00000619216.1\tchr1\t-\t17368\t17436\t17368\t17368\t1\t17368,\t  \t\tuc031tla.1\n"),
    ],
    ids=["accession column", "chromosome column", "strand column", "txStart column", "txEnd column", "exonStarts column", "exonEnds column"],
)
def test_missing_keys(ucsc_parser: UCSCParser, line: str) -> None:
    mock_file = io.StringIO(line)
    ucsc_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="Missing required key for xref"):
        ucsc_parser.run(
            {
                "source_id": SOURCE_ID_UCSC,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check successful parsing of valid UCSC data
def test_successful_parsing(mock_xref_dbi: DBConnection, ucsc_parser: UCSCParser) -> None:
    # Run and validate parsing for UCSC file
    run_and_validate_parsing(ucsc_parser, mock_xref_dbi, 10)

    # Check the row counts in the coordinate_xref table
    check_row_count(mock_xref_dbi, "coordinate_xref", 10)