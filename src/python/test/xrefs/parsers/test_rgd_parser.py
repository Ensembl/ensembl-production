import pytest
from unittest.mock import MagicMock
from typing import Callable

from ensembl.production.xrefs.parsers.RGDParser import RGDParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count, check_direct_xref_link, check_dependent_xref_link, check_synonym

# Constants
SOURCE_ID_RGD = 1
SOURCE_ID_DIRECT = 2
SPECIES_ID_RAT = 10116

# Fixture to create an RGDParser instance
@pytest.fixture
def rgd_parser() -> RGDParser:
    return RGDParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(rgd_parser: RGDParser, mock_xref_dbi: DBConnection, expected_dependent_xrefs: int, expected_direct_xrefs: int, expected_mismatch: int, expected_synonyms: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = rgd_parser.run(
        {
            "source_id": SOURCE_ID_RGD,
            "species_id": SPECIES_ID_RAT,
            "file": "parsers/flatfiles/rgd.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing RGD data"
    assert (
        f"{expected_dependent_xrefs} xrefs successfully loaded and dependent on refseq" in result_message
    ), f"{prefix}Expected '{expected_dependent_xrefs} xrefs successfully loaded and dependent on refseq' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_mismatch} xrefs added but with NO dependencies" in result_message
    ), f"{prefix}Expected '{expected_mismatch} xrefs added but with NO dependencies' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_direct_xrefs} direct xrefs successfully loaded" in result_message
    ), f"{prefix}Expected '{expected_direct_xrefs} direct xrefs successfully loaded' in result_message, but got: '{result_message}'"
    assert (
        f"Added {expected_synonyms} synonyms, including duplicates" in result_message
    ), f"{prefix}Expected 'Added {expected_synonyms} synonyms, including duplicates' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_rgd_missing_argument(rgd_parser: RGDParser, test_parser_missing_argument: Callable[[RGDParser, str, int, int], None]) -> None:
    test_parser_missing_argument(rgd_parser, "source_id", SOURCE_ID_RGD, SPECIES_ID_RAT)
    test_parser_missing_argument(rgd_parser, "species_id", SOURCE_ID_RGD, SPECIES_ID_RAT)
    test_parser_missing_argument(rgd_parser, "file", SOURCE_ID_RGD, SPECIES_ID_RAT)

# Test case to check if an error is raised when the file is not found
def test_rgd_file_not_found(rgd_parser: RGDParser, test_file_not_found: Callable[[RGDParser, int, int], None]) -> None:
    rgd_parser.get_source_id_for_source_name = MagicMock(return_value=SOURCE_ID_DIRECT)
    test_file_not_found(rgd_parser, SOURCE_ID_RGD, SPECIES_ID_RAT)

# Test case to check if an error is raised when the file is empty
def test_rgd_empty_file(rgd_parser: RGDParser, test_empty_file: Callable[[RGDParser, str, int, int], None]) -> None:
    rgd_parser.get_source_id_for_source_name = MagicMock(return_value=SOURCE_ID_DIRECT)
    test_empty_file(rgd_parser, 'RGD', SOURCE_ID_RGD, SPECIES_ID_RAT)

# Test case to check if an error is raised when the required source_id is missing
def test_rgd_missing_required_source_id(rgd_parser: RGDParser, mock_xref_dbi: DBConnection, test_missing_required_source_id: Callable[[RGDParser, DBConnection, str, int, int, str], None]) -> None:
    test_missing_required_source_id(rgd_parser, mock_xref_dbi, 'RGD', SOURCE_ID_RGD, SPECIES_ID_RAT)

# Test case to check successful parsing of valid RGD data without existing refseqs
def test_successful_parsing_without_refseqs(mock_xref_dbi: DBConnection, rgd_parser: RGDParser) -> None:
    rgd_parser.get_source_id_for_source_name = MagicMock(return_value=SOURCE_ID_DIRECT)

    # Run and validate parsing for RGD file without existing refseqs
    run_and_validate_parsing(rgd_parser, mock_xref_dbi, 0, 5, 2, 6)

    # Check the row counts in the xref, gene_direct_xref, dependent_xref, and synonym tables
    check_row_count(mock_xref_dbi, "xref", 3, f"info_type='DIRECT' AND source_id={SOURCE_ID_DIRECT}")
    check_row_count(mock_xref_dbi, "xref", 0, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_RGD}")
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='MISC' AND source_id={SOURCE_ID_RGD}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 5)
    check_row_count(mock_xref_dbi, "dependent_xref", 0)
    check_row_count(mock_xref_dbi, "synonym", 4)

    # Check the link between an xref and gene_direct_xref
    check_direct_xref_link(mock_xref_dbi, "gene", "2004", "ENSRNOG00000028896")

# Test case to check successful parsing of valid RGD data with refseqs
def test_successful_parsing_with_refseqs(mock_xref_dbi: DBConnection, rgd_parser: RGDParser) -> None:
    rgd_parser.get_source_id_for_source_name = MagicMock(return_value=SOURCE_ID_DIRECT)
    rgd_parser.get_acc_to_xref_ids = MagicMock(return_value={"NM_052979": [12, 34], "XM_039101774" : [56], "XM_063281326": [78]})

    # Run and validate parsing for RGD file with existing refseqs
    run_and_validate_parsing(rgd_parser, mock_xref_dbi, 3, 5, 1, 12)

    # Check the row counts in the xref, gene_direct_xref, dependent_xref, and synonym tables
    check_row_count(mock_xref_dbi, "xref", 3, f"info_type='DIRECT' AND source_id={SOURCE_ID_DIRECT}")
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_RGD}")
    check_row_count(mock_xref_dbi, "xref", 1, f"info_type='MISC' AND source_id={SOURCE_ID_RGD}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 5)
    check_row_count(mock_xref_dbi, "dependent_xref", 3)
    check_row_count(mock_xref_dbi, "synonym", 8)

    # Check the link between an xref and gene_direct_xref
    check_direct_xref_link(mock_xref_dbi, "gene", "2012", "ENSRNOG00000009845")

    # Check the link between an xref and dependent_xref
    check_dependent_xref_link(mock_xref_dbi, "2003", 12)
    check_dependent_xref_link(mock_xref_dbi, "2003", 34)
    check_dependent_xref_link(mock_xref_dbi, "2007", 56)

    # Check the synonyms for specific accessions
    check_synonym(mock_xref_dbi, "2003", SOURCE_ID_DIRECT, "ASP")
    check_synonym(mock_xref_dbi, "2007", SOURCE_ID_RGD, "PMP70, 70-kDa peroxisomal membrane protein")

    # Run and validate re-parsing for RGD file
    run_and_validate_parsing(rgd_parser, mock_xref_dbi, 3, 5, 1, 12, "Re-parsing: ")

    # Check the row counts in the xref, gene_direct_xref, dependent_xref, and synonym tables
    check_row_count(mock_xref_dbi, "xref", 3, f"info_type='DIRECT' AND source_id={SOURCE_ID_DIRECT}")
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_RGD}")
    check_row_count(mock_xref_dbi, "xref", 1, f"info_type='MISC' AND source_id={SOURCE_ID_RGD}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 5)
    check_row_count(mock_xref_dbi, "dependent_xref", 3)
    check_row_count(mock_xref_dbi, "synonym", 8)
