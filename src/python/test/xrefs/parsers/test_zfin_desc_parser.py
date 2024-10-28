import pytest
from typing import Callable

from ensembl.production.xrefs.parsers.ZFINDescParser import ZFINDescParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count

# Constants
SOURCE_ID_ZFIN = 1
SPECIES_ID_ZEBRAFISH = 7955

# Fixture to create a ZFINDescParser instance
@pytest.fixture
def zfin_desc_parser() -> ZFINDescParser:
    return ZFINDescParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(zfin_desc_parser: ZFINDescParser, mock_xref_dbi: DBConnection, expected_xrefs: int, expected_withdrawn: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = zfin_desc_parser.run(
        {
            "source_id": SOURCE_ID_ZFIN,
            "species_id": SPECIES_ID_ZEBRAFISH,
            "file": "parsers/flatfiles/zfin_desc.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing ZFINDesc data"
    assert (
        f"{expected_xrefs} ZFINDesc xrefs added" in result_message
    ), f"{prefix}Expected '{expected_xrefs} ZFINDesc xrefs added' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_withdrawn} withdrawn entries ignored" in result_message
    ), f"{prefix}Expected '{expected_withdrawn} withdrawn entries ignored' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_zfin_desc_no_source_id(zfin_desc_parser: ZFINDescParser, test_no_source_id: Callable[[ZFINDescParser, int], None]) -> None:
    test_no_source_id(zfin_desc_parser, SPECIES_ID_ZEBRAFISH)

def test_zfin_desc_no_species_id(zfin_desc_parser: ZFINDescParser, test_no_species_id: Callable[[ZFINDescParser, int], None]) -> None:
    test_no_species_id(zfin_desc_parser, SOURCE_ID_ZFIN)

def test_zfin_desc_no_file(zfin_desc_parser: ZFINDescParser, test_no_file: Callable[[ZFINDescParser, int, int], None]) -> None:
    test_no_file(zfin_desc_parser, SOURCE_ID_ZFIN, SPECIES_ID_ZEBRAFISH)

# Test case to check if an error is raised when the file is not found
def test_zfin_desc_file_not_found(zfin_desc_parser: ZFINDescParser, test_file_not_found: Callable[[ZFINDescParser, int, int], None]) -> None:
    test_file_not_found(zfin_desc_parser, SOURCE_ID_ZFIN, SPECIES_ID_ZEBRAFISH)

# Test case to check if an error is raised when the file is empty
def test_zfin_desc_empty_file(zfin_desc_parser: ZFINDescParser, test_empty_file: Callable[[ZFINDescParser, str, int, int], None]) -> None:
    test_empty_file(zfin_desc_parser, 'ZFINDesc', SOURCE_ID_ZFIN, SPECIES_ID_ZEBRAFISH)

# Test case to check successful parsing of valid ZFINDesc data
def test_successful_parsing(mock_xref_dbi: DBConnection, zfin_desc_parser: ZFINDescParser) -> None:
    # Run and validate parsing for ZFINDesc file
    run_and_validate_parsing(zfin_desc_parser, mock_xref_dbi, 6, 3)

    # Check the row counts in the xref table
    check_row_count(mock_xref_dbi, "xref", 6, f"info_type='MISC' AND source_id={SOURCE_ID_ZFIN}")