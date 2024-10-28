import pytest
from unittest.mock import MagicMock
from typing import Callable

from ensembl.production.xrefs.parsers.miRBaseParser import miRBaseParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count, check_sequence

# Constants
SOURCE_ID_MIRBASE = 1
SPECIES_ID_C_ELEGANS = 6239
SPECIES_NAME_C_ELEGANS = "caenorhabditis_elegans"
SPECIES_ID_HUMAN = 9606
SPECIES_NAME_HUMAN = "homo_sapiens"

# Fixture to create a miRBaseParser instance
@pytest.fixture
def mirbase_parser() -> miRBaseParser:
    return miRBaseParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(mirbase_parser: miRBaseParser, mock_xref_dbi: DBConnection, expected_xrefs: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = mirbase_parser.run(
        {
            "source_id": SOURCE_ID_MIRBASE,
            "species_id": SPECIES_ID_C_ELEGANS,
            "species_name": SPECIES_NAME_C_ELEGANS,
            "file": "parsers/flatfiles/mirbase.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing miRBase data"
    assert (
        f"Read {expected_xrefs} xrefs from" in result_message
    ), f"{prefix}Expected 'Read {expected_xrefs} xrefs from' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_mirbase_no_source_id(mirbase_parser: miRBaseParser, test_no_source_id: Callable[[miRBaseParser, int], None]) -> None:
    test_no_source_id(mirbase_parser, SPECIES_ID_C_ELEGANS)

def test_mirbase_no_species_id(mirbase_parser: miRBaseParser, test_no_species_id: Callable[[miRBaseParser, int], None]) -> None:
    test_no_species_id(mirbase_parser, SOURCE_ID_MIRBASE)

def test_mirbase_no_file(mirbase_parser: miRBaseParser, test_no_file: Callable[[miRBaseParser, int, int], None]) -> None:
    test_no_file(mirbase_parser, SOURCE_ID_MIRBASE, SPECIES_ID_C_ELEGANS)

# Test case to check if an error is raised when the file is not found
def test_mirbase_file_not_found(mirbase_parser: miRBaseParser, test_file_not_found: Callable[[miRBaseParser, int, int], None]) -> None:
    mirbase_parser.species_id_to_names = MagicMock(return_value={SPECIES_ID_C_ELEGANS: [SPECIES_NAME_C_ELEGANS]})
    test_file_not_found(mirbase_parser, SOURCE_ID_MIRBASE, SPECIES_ID_C_ELEGANS)

# Test case to check if parsing is skipped when no species name can be found
def test_no_species_name(mock_xref_dbi: DBConnection, mirbase_parser: miRBaseParser) -> None:
    mirbase_parser.species_id_to_names = MagicMock(return_value={SPECIES_ID_HUMAN: [SPECIES_NAME_HUMAN]})

    result_code, result_message = mirbase_parser.run(
        {
            "source_id": SOURCE_ID_MIRBASE,
            "species_id": SPECIES_ID_C_ELEGANS,
            "file": "dummy_file.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"Errors when parsing miRBase data"
    assert (
        "Skipped. Could not find species ID to name mapping" in result_message
    ), f"Expected 'Skipped. Could not find species ID to name mapping' in result_message, but got: '{result_message}'"

# Test case to check if no xrefs are added when the species name provided is not in the file
def test_no_xrefs_added(mock_xref_dbi: DBConnection, mirbase_parser: miRBaseParser) -> None:
    mirbase_parser.species_id_to_names = MagicMock(return_value={})

    result_code, result_message = mirbase_parser.run(
        {
            "source_id": SOURCE_ID_MIRBASE,
            "species_id": SPECIES_ID_HUMAN,
            "species_name": SPECIES_NAME_HUMAN,
            "file": f"parsers/flatfiles/mirbase.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"Errors when parsing miRBase data"
    assert "No xrefs added" in result_message, f"Expected 'No xrefs added' in result_message, but got: '{result_message}'"

# Test case to check successful parsing of valid miRBase data
def test_successful_parsing(mock_xref_dbi: DBConnection, mirbase_parser: miRBaseParser) -> None:
    mirbase_parser.species_id_to_names = MagicMock(return_value={})

    # Run and validate parsing for miRBase file
    run_and_validate_parsing(mirbase_parser, mock_xref_dbi, 6)

    # Check the row counts in the xref and synonym tables
    check_row_count(mock_xref_dbi, "xref", 6, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_MIRBASE}")
    check_row_count(mock_xref_dbi, "primary_xref", 6)

    # Check the sequences for specific accessions
    check_sequence(mock_xref_dbi, "MI0000002", SOURCE_ID_MIRBASE, "ATGCTTCCGGCCTGTTCCCTGAGACCTCAAGTGTGAGTGTACTATTGATGCTTCACACCTGGGCTCTCCGGGTACCAGGACGGTTTGAGCAGAT")
    check_sequence(mock_xref_dbi, "MI0000006", SOURCE_ID_MIRBASE, "TCTCGGATCAGATCGAGCCATTGCTGGTTTCTTCCACAGTGGTACTTTCCATTAGAACTATCACCGGGTGGAAACTAGCAGTGGCTCGATCTTTTCC")

    # Run and validate parsing for miRBase file
    run_and_validate_parsing(mirbase_parser, mock_xref_dbi, 6, "Re-parsing: ")

    # Check the row counts in the xref and synonym tables
    check_row_count(mock_xref_dbi, "xref", 6, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_MIRBASE}")
    check_row_count(mock_xref_dbi, "primary_xref", 6)
