import pytest
from unittest.mock import MagicMock, patch
from typing import Callable
from types import SimpleNamespace

from ensembl.production.xrefs.parsers.CCDSParser import CCDSParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count, check_direct_xref_link

# Constants
SOURCE_ID_CCDS = 1
SPECIES_ID_HUMAN = 9606

# Fixture to create a CCDSParser instance
@pytest.fixture
def ccds_parser() -> CCDSParser:
    return CCDSParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(ccds_parser: CCDSParser, mock_xref_dbi: DBConnection, expected_xrefs: int, expected_direct_xrefs: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = ccds_parser.run(
        {
            "source_id": SOURCE_ID_CCDS,
            "species_id": SPECIES_ID_HUMAN,
            "extra_db_url": "mock_ccds_db_url",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing CCDS data"
    assert (
        f"Parsed CCDS identifiers, added {expected_xrefs} xrefs and {expected_direct_xrefs} direct_xrefs" in result_message
    ), f"{prefix}Expected 'Parsed CCDS identifiers, added {expected_xrefs} xrefs and {expected_direct_xrefs} direct_xrefs' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id and species_id
def test_ccds_missing_argument(ccds_parser: CCDSParser, test_parser_missing_argument: Callable[[CCDSParser, str, int, int], None]) -> None:
    test_parser_missing_argument(ccds_parser, "source_id", SOURCE_ID_CCDS, SPECIES_ID_HUMAN)
    test_parser_missing_argument(ccds_parser, "species_id", SOURCE_ID_CCDS, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when no CCDS database is provided
def test_no_ccds_db(ccds_parser: CCDSParser) -> None:
    result_code, result_message = ccds_parser.run(
        {
            "source_id": SOURCE_ID_CCDS,
            "species_id": SPECIES_ID_HUMAN,
            "xref_dbi": MagicMock(),
        }
    )

    assert result_code == 1, f"Errors when parsing CCDS data"
    assert (
        "Could not find CCDS DB." in result_message
    ), f"Expected 'Could not find CCDS DB.' in result_message, but got: '{result_message}'"

# Test case to check successful parsing of valid CCDS data
def test_successful_parsing(mock_xref_dbi: DBConnection, ccds_parser: CCDSParser) -> None:
    # Mock all needed methods
    ccds_data = [
        {"stable_id": "CCDS2.2", "dbprimary_acc": "ENST00000342066"},
        {"stable_id": "CCDS3.1", "dbprimary_acc": "ENST00000327044"},
        {"stable_id": "CCDS4.1", "dbprimary_acc": "ENST00000379410"},
        {"stable_id": "CCDS5.1", "dbprimary_acc": "ENST00000379410"},
        {"stable_id": "CCDS7.2", "dbprimary_acc": "ENST00000421241"},
        {"stable_id": "CCDS7.2", "dbprimary_acc": "ENST00000379319"},
    ]
    ccds_data_obj = [SimpleNamespace(**item) for item in ccds_data]
    ccds_parser.get_ccds_data = MagicMock(return_value=ccds_data_obj)

    # Run and validate parsing for ArrayExpress data
    run_and_validate_parsing(ccds_parser, mock_xref_dbi, 5, 6)

    # Check the row counts in the xref and transcript_direct_xref tables
    check_row_count(mock_xref_dbi, "xref", 5, f"info_type='DIRECT' AND source_id={SOURCE_ID_CCDS}")
    check_row_count(mock_xref_dbi, "transcript_direct_xref", 6)

    # Check the link between an xref and gene_direct_xref
    check_direct_xref_link(mock_xref_dbi, "transcript", "ENST00000327044", "CCDS3.1")
    check_direct_xref_link(mock_xref_dbi, "transcript", "ENST00000421241", "CCDS7.2")
    check_direct_xref_link(mock_xref_dbi, "transcript", "ENST00000379319", "CCDS7.2")

    # Run and validate re-parsing for ArrayExpress data
    run_and_validate_parsing(ccds_parser, mock_xref_dbi, 5, 6, "Re-parsing: ")

    # Check the row counts in the xref and transcript_direct_xref tables
    check_row_count(mock_xref_dbi, "xref", 5, f"info_type='DIRECT' AND source_id={SOURCE_ID_CCDS}")
    check_row_count(mock_xref_dbi, "transcript_direct_xref", 6)