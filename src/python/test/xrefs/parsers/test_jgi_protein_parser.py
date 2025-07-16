import pytest
import os
from typing import Callable

from ensembl.production.xrefs.parsers.JGI_ProteinParser import JGI_ProteinParser
from ensembl.utils.database import DBConnection
from test.xrefs.test_helpers import check_row_count

TEST_DIR = os.path.dirname(__file__)
FLATFILES_DIR = os.path.join(TEST_DIR, "flatfiles")

# Constants
SOURCE_ID_JGI = 1
SPECIES_ID_C_INTESTINALIS = 7719

# Fixture to create a JGI_ProteinParser instance
@pytest.fixture
def jgi_protein_parser() -> JGI_ProteinParser:
    return JGI_ProteinParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(jgi_protein_parser: JGI_ProteinParser, mock_xref_dbi: DBConnection, expected_xrefs: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = jgi_protein_parser.run(
        {
            "source_id": SOURCE_ID_JGI,
            "species_id": SPECIES_ID_C_INTESTINALIS,
            "file": os.path.join(FLATFILES_DIR, "jgi_protein.fasta"),
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing JGI data"
    assert f"{expected_xrefs} JGI_ xrefs successfully parsed" in result_message, f"{prefix}Expected '{expected_xrefs} JGI_ xrefs successfully parsed' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_jgi_missing_argument(jgi_protein_parser: JGI_ProteinParser, test_parser_missing_argument: Callable[[JGI_ProteinParser, str, int, int], None]) -> None:
    test_parser_missing_argument(jgi_protein_parser, "source_id", SOURCE_ID_JGI, SPECIES_ID_C_INTESTINALIS)
    test_parser_missing_argument(jgi_protein_parser, "species_id", SOURCE_ID_JGI, SPECIES_ID_C_INTESTINALIS)
    test_parser_missing_argument(jgi_protein_parser, "file", SOURCE_ID_JGI, SPECIES_ID_C_INTESTINALIS)

# Test case to check if an error is raised when the file is not found
def test_jgi_file_not_found(jgi_protein_parser: JGI_ProteinParser, test_file_not_found: Callable[[JGI_ProteinParser, int, int], None]) -> None:
    test_file_not_found(jgi_protein_parser, SOURCE_ID_JGI, SPECIES_ID_C_INTESTINALIS)

# Test case to check if an error is raised when the file is empty
def test_jgi_empty_file(jgi_protein_parser: JGI_ProteinParser, test_empty_file: Callable[[JGI_ProteinParser, str, int, int], None]) -> None:
    test_empty_file(jgi_protein_parser, 'JGIProtein', SOURCE_ID_JGI, SPECIES_ID_C_INTESTINALIS)

# Test case to check successful parsing
def test_successful_parsing(mock_xref_dbi: DBConnection, jgi_protein_parser: JGI_ProteinParser) -> None:
    # Run and validate parsing for JGI Protein file
    run_and_validate_parsing(jgi_protein_parser, mock_xref_dbi, 9)

    # Check the row counts in the xref and primary_xref tables
    check_row_count(mock_xref_dbi, "xref", 9, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_JGI}")
    check_row_count(mock_xref_dbi, "primary_xref", 9)