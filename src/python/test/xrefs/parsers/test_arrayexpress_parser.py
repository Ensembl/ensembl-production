import pytest
from unittest.mock import MagicMock
from typing import Callable
from types import SimpleNamespace

from ensembl.production.xrefs.parsers.ArrayExpressParser import ArrayExpressParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count, check_direct_xref_link

# Constants
SOURCE_ID_ARRAYEXPRESS = 1
SPECIES_ID_HUMAN = 9606
SPECIES_NAME_HUMAN = "homo_sapiens"

# Fixture to create an ArrayExpressParser instance
@pytest.fixture
def arrayexpress_parser() -> ArrayExpressParser:
    return ArrayExpressParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(arrayexpress_parser: ArrayExpressParser, mock_xref_dbi: DBConnection, expected_xrefs: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = arrayexpress_parser.run(
        {
            "source_id": SOURCE_ID_ARRAYEXPRESS,
            "species_id": SPECIES_ID_HUMAN,
            "species_name": SPECIES_NAME_HUMAN,
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing ArrayExpress data"
    assert (
        f"Added {expected_xrefs} DIRECT xrefs" in result_message
    ), f"{prefix}Expected 'Added {expected_xrefs} DIRECT xrefs' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id and species_id
def test_arrayexpress_no_source_id(arrayexpress_parser: ArrayExpressParser, test_no_source_id: Callable[[ArrayExpressParser, int], None]) -> None:
    test_no_source_id(arrayexpress_parser, SPECIES_ID_HUMAN)

def test_arrayexpress_no_species_id(arrayexpress_parser: ArrayExpressParser, test_no_species_id: Callable[[ArrayExpressParser, int], None]) -> None:
    test_no_species_id(arrayexpress_parser, SOURCE_ID_ARRAYEXPRESS)

# Test case to check if parsing is skipped when no species name can be found
def test_no_species_name(mock_xref_dbi: DBConnection, arrayexpress_parser: ArrayExpressParser) -> None:
    result_code, result_message = arrayexpress_parser.run(
        {
            "source_id": SOURCE_ID_ARRAYEXPRESS,
            "species_id": SPECIES_ID_HUMAN,
            "file": "dummy_file.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"Errors when parsing ArrayExpress data"
    assert (
        "Skipped. Could not find species ID to name mapping" in result_message
    ), f"Expected 'Skipped. Could not find species ID to name mapping' in result_message, but got: '{result_message}'"

# Test case to check if an error is raised when no ArrayExpress database is provided
def test_no_arrayexpress_db(arrayexpress_parser: ArrayExpressParser) -> None:
    arrayexpress_parser.get_arrayexpress_db_url = MagicMock(return_value=None)

    with pytest.raises(
        AttributeError, match="Could not find ArrayExpress DB. Missing or unsupported project value."
    ):
        arrayexpress_parser.run(
            {
                "source_id": SOURCE_ID_ARRAYEXPRESS,
                "species_id": SPECIES_ID_HUMAN,
                "species_name": SPECIES_NAME_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check successful parsing of valid ArrayExpress data
def test_successful_parsing(mock_xref_dbi: DBConnection, arrayexpress_parser: ArrayExpressParser) -> None:
    # Mock all needed methods
    arrayexpress_parser.get_arrayexpress_db_url = MagicMock(return_value="mock_arrayexpress_db_url")
    arrayexpress_data = [
        {"stable_id": "ENSG00000139618"},
        {"stable_id": "ENSG00000157764"},
        {"stable_id": "ENSG00000198786"},
        {"stable_id": "ENSG00000248378"},
        {"stable_id": "ENSG00000248379"},
    ]
    arrayexpress_data_obj = [SimpleNamespace(**item) for item in arrayexpress_data]
    arrayexpress_parser.get_arrayexpress_data = MagicMock(return_value=arrayexpress_data_obj)

    # Run and validate parsing for ArrayExpress data
    run_and_validate_parsing(arrayexpress_parser, mock_xref_dbi, 5)

    # Check the row counts in the xref and gene_direct_xref tables
    check_row_count(mock_xref_dbi, "xref", 5, f"info_type='DIRECT' AND source_id={SOURCE_ID_ARRAYEXPRESS}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 5)

    # Check the link between an xref and gene_direct_xref
    check_direct_xref_link(mock_xref_dbi, "gene", "ENSG00000139618", "ENSG00000139618")
    check_direct_xref_link(mock_xref_dbi, "gene", "ENSG00000157764", "ENSG00000157764")
    check_direct_xref_link(mock_xref_dbi, "gene", "ENSG00000198786", "ENSG00000198786")

    # Run and validate re-parsing for ArrayExpress data
    run_and_validate_parsing(arrayexpress_parser, mock_xref_dbi, 5, "Re-parsing: ")

    # Check the row counts in the xref and gene_direct_xref tables
    check_row_count(mock_xref_dbi, "xref", 5, f"info_type='DIRECT' AND source_id={SOURCE_ID_ARRAYEXPRESS}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 5)