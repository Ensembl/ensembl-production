import pytest
from unittest.mock import MagicMock
from typing import Callable

from ensembl.production.xrefs.parsers.RFAMParser import RFAMParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count, check_direct_xref_link

# Constants
SOURCE_ID_RFAM = 1
SPECIES_ID_HUMAN = 9606
SPECIES_NAME_HUMAN = "homo_sapiens"

# Fixture to create an RFAMParser instance
@pytest.fixture
def rfam_parser() -> RFAMParser:
    return RFAMParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(rfam_parser: RFAMParser, mock_xref_dbi: DBConnection, expected_xrefs: int, expected_direct_xrefs: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = rfam_parser.run(
        {
            "source_id": SOURCE_ID_RFAM,
            "species_id": SPECIES_ID_HUMAN,
            "species_name": SPECIES_NAME_HUMAN,
            "file": "parsers/flatfiles/rfam.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing RFAM data"
    assert (
        f"Added {expected_xrefs} RFAM xrefs and {expected_direct_xrefs} direct xrefs" in result_message
    ), f"{prefix}Expected 'Added {expected_xrefs} RFAM xrefs and {expected_direct_xrefs} direct xrefs' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_rfam_no_source_id(rfam_parser: RFAMParser, test_no_source_id: Callable[[RFAMParser, int], None]) -> None:
    test_no_source_id(rfam_parser, SPECIES_ID_HUMAN)

def test_rfam_no_species_id(rfam_parser: RFAMParser, test_no_species_id: Callable[[RFAMParser, int], None]) -> None:
    test_no_species_id(rfam_parser, SOURCE_ID_RFAM)

def test_rfam_no_file(rfam_parser: RFAMParser, test_no_file: Callable[[RFAMParser, int, int], None]) -> None:
    test_no_file(rfam_parser, SOURCE_ID_RFAM, SPECIES_ID_HUMAN)

# Test case to check if parsing is skipped when no species name can be found
def test_no_species_name(mock_xref_dbi: DBConnection, rfam_parser: RFAMParser) -> None:
    result_code, result_message = rfam_parser.run(
        {
            "source_id": SOURCE_ID_RFAM,
            "species_id": SPECIES_ID_HUMAN,
            "file": "dummy_file.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"Errors when parsing RFAM data"
    assert (
        "Skipped. Could not find species ID to name mapping" in result_message
    ), f"Expected 'Skipped. Could not find species ID to name mapping' in result_message, but got: '{result_message}'"

# Test case to check if an error is raised when no RFAM database is provided
def test_no_rfam_db(rfam_parser: RFAMParser) -> None:
    rfam_parser.get_db_from_registry = MagicMock(return_value=None)

    with pytest.raises(
        AttributeError, match="Could not find RFAM DB."
    ):
        rfam_parser.run(
            {
                "source_id": SOURCE_ID_RFAM,
                "species_id": SPECIES_ID_HUMAN,
                "species_name": SPECIES_NAME_HUMAN,
                "file": "dummy_file.txt",
                "ensembl_release": "100",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check if an error is raised when the file is not found
def test_rfam_file_not_found(rfam_parser: RFAMParser, test_file_not_found: Callable[[RFAMParser, int, int], None]) -> None:
    rfam_parser.species_id_to_names = MagicMock(return_value={SPECIES_ID_HUMAN: [SPECIES_NAME_HUMAN]})
    rfam_parser.get_rfam_db_url = MagicMock(return_value="mock_rfam_db_url")
    rfam_parser.get_rfam_transcript_stable_ids = MagicMock(return_value={})
    test_file_not_found(rfam_parser, SOURCE_ID_RFAM, SPECIES_ID_HUMAN)

# Test case to check successful parsing of valid RFAM data without existing RFAM xrefs in RFAM DB
def test_successful_parsing_without_existing_rfam_data(mock_xref_dbi: DBConnection, rfam_parser: RFAMParser) -> None:
    rfam_parser.get_rfam_db_url = MagicMock(return_value="mock_rfam_db_url")
    rfam_parser.get_rfam_transcript_stable_ids = MagicMock(return_value={})

    # Run and validate parsing for MIM file
    run_and_validate_parsing(rfam_parser, mock_xref_dbi, 0, 0)

    # Check the row counts in the xref and transcript_direct_xref tables
    check_row_count(mock_xref_dbi, "xref", 0)
    check_row_count(mock_xref_dbi, "transcript_direct_xref", 0)

# Test case to check successful parsing of valid RFAM data with existing RFAM xrefs in RFAM DB
def test_successful_parsing_with_existing_rfam_data(mock_xref_dbi: DBConnection, rfam_parser: RFAMParser) -> None:
    # Run parsing without existing values in RFAM DB
    rfam_parser.get_rfam_db_url = MagicMock(return_value="mock_rfam_db_url")
    rfam_parser.get_rfam_transcript_stable_ids = MagicMock(return_value={
        "RF00001": ["ENST00000516887", "ENST00000516971", "ENST00000622298", "ENST00000674448"],
        "RF00002": ["ENST00000363564", "ENST00000515896"],
        "RF00003": ["ENST00000353977"],
        "RF00006": ["ENST00000362552", "ENST00000363120", "ENST00000365241", "ENST00000365645", "ENST00000516091"]
    })

    # Run and validate parsing for RFAM file
    run_and_validate_parsing(rfam_parser, mock_xref_dbi, 4, 12)

    # Check the row counts in the xref and transcript_direct_xref tables
    check_row_count(mock_xref_dbi, "xref", 4)
    check_row_count(mock_xref_dbi, "transcript_direct_xref", 12)

    # Check the link between an xref and transcript_direct_xref
    check_direct_xref_link(mock_xref_dbi, "transcript", "RF00002", "ENST00000515896")
    check_direct_xref_link(mock_xref_dbi, "transcript", "RF00006", "ENST00000362552")
    check_direct_xref_link(mock_xref_dbi, "transcript", "RF00006", "ENST00000365645")

    # Run and validate re-parsing for RFAM file
    run_and_validate_parsing(rfam_parser, mock_xref_dbi, 4, 12, "Re-parsing: ")

    # Check the row counts in the xref and transcript_direct_xref tables
    check_row_count(mock_xref_dbi, "xref", 4)
    check_row_count(mock_xref_dbi, "transcript_direct_xref", 12)