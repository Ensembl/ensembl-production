import pytest
from unittest.mock import MagicMock
from typing import Callable

from ensembl.production.xrefs.parsers.MGIParser import MGIParser
from ensembl.utils.database import DBConnection
from test.xrefs.test_helpers import check_row_count, check_synonym, check_direct_xref_link

# Constants
SOURCE_ID_MGI = 1
SPECIES_ID_MOUSE = 10090

# Fixture to create an MGIParser instance
@pytest.fixture
def mgi_parser() -> MGIParser:
    return MGIParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(mgi_parser: MGIParser, mock_xref_dbi: DBConnection, expected_direct_xrefs: int, expected_synonyms: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = mgi_parser.run(
        {
            "source_id": SOURCE_ID_MGI,
            "species_id": SPECIES_ID_MOUSE,
            "file": "parsers/flatfiles/mgi.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing MGI data"
    assert (
        f"{expected_direct_xrefs} direct MGI xrefs added" in result_message
    ), f"{prefix}Expected '{expected_direct_xrefs} direct MGI xrefs added' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_synonyms} synonyms added" in result_message
    ), f"{prefix}Expected '{expected_synonyms} synonyms added' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_mgi_missing_argument(mgi_parser: MGIParser, test_parser_missing_argument: Callable[[MGIParser, str, int, int], None]) -> None:
    test_parser_missing_argument(mgi_parser, "source_id", SOURCE_ID_MGI, SPECIES_ID_MOUSE)
    test_parser_missing_argument(mgi_parser, "species_id", SOURCE_ID_MGI, SPECIES_ID_MOUSE)
    test_parser_missing_argument(mgi_parser, "file", SOURCE_ID_MGI, SPECIES_ID_MOUSE)

# Test case to check if an error is raised when the file is not found
def test_mgi_file_not_found(mgi_parser: MGIParser, test_file_not_found: Callable[[MGIParser, int, int], None]) -> None:
    test_file_not_found(mgi_parser, SOURCE_ID_MGI, SPECIES_ID_MOUSE)

# Test case to check if an error is raised when the file is empty
def test_mgi_empty_file(mgi_parser: MGIParser, test_empty_file: Callable[[MGIParser, str, int, int], None]) -> None:
    test_empty_file(mgi_parser, 'MGI', SOURCE_ID_MGI, SPECIES_ID_MOUSE)

# Test case to check successful parsing of valid MGI data
def test_successful_parsing(mock_xref_dbi: DBConnection, mgi_parser: MGIParser) -> None:
    # Mock the synonym hash to return some test synonyms
    mgi_parser.get_ext_synonyms = MagicMock(return_value={"MGI:1926146": ["Ecrg4", "augurin"]})

    # Run and validate parsing for MGI file
    run_and_validate_parsing(mgi_parser, mock_xref_dbi, 10, 2)

    # Check the row counts in the xref and synonym tables
    check_row_count(mock_xref_dbi, "xref", 10, f"info_type='DIRECT' AND source_id={SOURCE_ID_MGI}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 10)
    check_row_count(mock_xref_dbi, "synonym", 2)

    # Check the link between an xref and gene_direct_xref
    check_direct_xref_link(mock_xref_dbi, "gene", "MGI:1914753", "ENSMUSG00000103746")

    # Check the synonyms for specific accessions
    check_synonym(mock_xref_dbi, "MGI:1926146", SOURCE_ID_MGI, "Ecrg4")
    check_synonym(mock_xref_dbi, "MGI:1926146", SOURCE_ID_MGI, "augurin")

    # Run and validate re-parsing for MGI file
    run_and_validate_parsing(mgi_parser, mock_xref_dbi, 10, 2, "Re-parsing: ")

    # Check the row counts in the xref and synonym tables again
    check_row_count(mock_xref_dbi, "xref", 10, f"info_type='DIRECT' AND source_id={SOURCE_ID_MGI}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 10)
    check_row_count(mock_xref_dbi, "synonym", 2)
