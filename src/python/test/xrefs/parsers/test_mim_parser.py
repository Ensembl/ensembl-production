import pytest
import os
from unittest.mock import MagicMock, patch
from typing import Callable

from ensembl.production.xrefs.parsers.MIMParser import MIMParser
from ensembl.utils.database import DBConnection
from test.xrefs.test_helpers import check_row_count, check_synonym

TEST_DIR = os.path.dirname(__file__)
FLATFILES_DIR = os.path.join(TEST_DIR, "flatfiles")

# Constants
SOURCE_ID_MIM = 1
SOURCE_ID_MIM_GENE = 2
SOURCE_ID_MIM_MORBID = 3
SPECIES_ID_HUMAN = 9606

# Fixture to create a MIMParser instance
@pytest.fixture
def mim_parser() -> MIMParser:
    return MIMParser(True)

# Mock for get_source_id_for_source_name
def mock_get_source_id_for_source_name(source_name: str, mock_xref_dbi: DBConnection) -> int:
    if source_name == "MIM_GENE":
        return SOURCE_ID_MIM_GENE
    elif source_name == "MIM_MORBID":
        return SOURCE_ID_MIM_MORBID
    else:
        return SOURCE_ID_MIM

# Function to run and validate the parsing process
def run_and_validate_parsing(mim_parser: MIMParser, mock_xref_dbi: DBConnection, expected_genemap_xrefs: int, expected_phenotype_xrefs: int, expected_synonyms: int, expected_removed_entries: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = mim_parser.run(
        {
            "source_id": SOURCE_ID_MIM,
            "species_id": SPECIES_ID_HUMAN,
            "file": os.path.join(FLATFILES_DIR, "mim.txt"),
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing MIM data"
    assert (
        f"{expected_genemap_xrefs} genemap and {expected_phenotype_xrefs} phenotype MIM xrefs added" in result_message
    ), f"{prefix}Expected '{expected_genemap_xrefs} genemap and {expected_phenotype_xrefs} phenotype MIM xrefs added' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_synonyms} synonyms (defined by MOVED TO) added" in result_message
    ), f"{prefix}Expected '{expected_synonyms} synonyms (defined by MOVED TO) added' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_removed_entries} entries removed" in result_message
    ), f"{prefix}Expected '{expected_removed_entries} entries removed' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_mim_missing_argument(mim_parser: MIMParser, test_parser_missing_argument: Callable[[MIMParser, str, int, int], None]) -> None:
    test_parser_missing_argument(mim_parser, "source_id", SOURCE_ID_MIM, SPECIES_ID_HUMAN)
    test_parser_missing_argument(mim_parser, "species_id", SOURCE_ID_MIM, SPECIES_ID_HUMAN)
    test_parser_missing_argument(mim_parser, "file", SOURCE_ID_MIM, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the required source_id is missing
def test_mim_missing_required_source_id(mim_parser: MIMParser, mock_xref_dbi: DBConnection, test_missing_required_source_id: Callable[[MIMParser, DBConnection, str, int, int, str], None]) -> None:
    test_missing_required_source_id(mim_parser, mock_xref_dbi, 'MIM_GENE', SOURCE_ID_MIM, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is not found
def test_mim_file_not_found(mim_parser: MIMParser, test_file_not_found: Callable[[MIMParser, int, int], None]) -> None:
    test_file_not_found(mim_parser, SOURCE_ID_MIM, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the TI field is missing
def test_missing_ti_field(mim_parser: MIMParser) -> None:
    mock_file_content = [
        "*RECORD*\n*FIELD*\nNO\n100050\n"
    ]
    mim_parser.get_source_id_for_source_name = MagicMock(side_effect=mock_get_source_id_for_source_name)

    with patch.object(MIMParser, 'get_file_sections', return_value=mock_file_content):
        with pytest.raises(ValueError, match="Failed to extract TI field from record"):
            mim_parser.run(
                {
                    "source_id": SOURCE_ID_MIM,
                    "species_id": SPECIES_ID_HUMAN,
                    "file": "dummy_file.txt",
                    "xref_dbi": MagicMock(),
                }
            )

# Test case to check if an error is raised when the TI field has an invalid format
def test_invalid_ti_field(mim_parser: MIMParser) -> None:
    mock_file_content = [
        "*RECORD*\n*FIELD*\nNO\n100050\n*FIELD*\nTI\nAARSKOG SYNDROME, AUTOSOMAL DOMINANT\n*FIELD*\nTX\n\nDESCRIPTION\n\nAarskog syndrome is characterized by short stature and facial, limb,\n\n*THEEND*\n"
    ]
    mim_parser.get_source_id_for_source_name = MagicMock(side_effect=mock_get_source_id_for_source_name)

    with patch.object(MIMParser, 'get_file_sections', return_value=mock_file_content):
        with pytest.raises(ValueError, match="Failed to extract record type and description from TI field"):
            mim_parser.run(
                {
                    "source_id": SOURCE_ID_MIM,
                    "species_id": SPECIES_ID_HUMAN,
                    "file": "dummy_file.txt",
                    "xref_dbi": MagicMock(),
                }
            )

# Test case to check successful parsing of valid MIM data
def test_successful_parsing(mock_xref_dbi: DBConnection, mim_parser: MIMParser) -> None:
    mim_parser.get_source_id_for_source_name = MagicMock(side_effect=mock_get_source_id_for_source_name)

    # Run and validate parsing for MIM file
    run_and_validate_parsing(mim_parser, mock_xref_dbi, 2, 4, 2, 1)

    # Check the row counts in the xref and synonym tables
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='UNMAPPED' AND source_id={SOURCE_ID_MIM_GENE}")
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='UNMAPPED' AND source_id={SOURCE_ID_MIM_MORBID}")
    check_row_count(mock_xref_dbi, "synonym", 4)

    # Check the synonyms for specific accessions
    check_synonym(mock_xref_dbi, "200150", SOURCE_ID_MIM_GENE, "100500")
    check_synonym(mock_xref_dbi, "200150", SOURCE_ID_MIM_MORBID, "100650")

    # Check for re-parsing of the same file
    run_and_validate_parsing(mim_parser, mock_xref_dbi, 2, 4, 2, 1, "Re-parsing: ")

    # Re-check the row counts in the xref and synonym tables after re-parsing
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='UNMAPPED' AND source_id={SOURCE_ID_MIM_GENE}")
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='UNMAPPED' AND source_id={SOURCE_ID_MIM_MORBID}")
    check_row_count(mock_xref_dbi, "synonym", 4)
