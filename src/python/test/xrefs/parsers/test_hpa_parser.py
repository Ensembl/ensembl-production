import pytest
import io
from unittest.mock import MagicMock
from typing import Callable

from ensembl.production.xrefs.parsers.HPAParser import HPAParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count, check_direct_xref_link

# Constants
SOURCE_ID_HPA = 1
SPECIES_ID_HUMAN = 9606
EXPECTED_NUMBER_OF_COLUMNS = 4

# Fixture to create an HPAParser instance
@pytest.fixture
def hpa_parser() -> HPAParser:
    return HPAParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(hpa_parser: HPAParser, mock_xref_dbi: DBConnection, expected_xrefs: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = hpa_parser.run(
        {
            "source_id": SOURCE_ID_HPA,
            "species_id": SPECIES_ID_HUMAN,
            "file": "parsers/flatfiles/hpa.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing HPA data"
    assert (
        f"{expected_xrefs} direct xrefs successfully parsed" in result_message
    ), f"{prefix}Expected '{expected_xrefs} direct xrefs successfully parsed' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_hpa_missing_argument(hpa_parser: HPAParser, test_parser_missing_argument: Callable[[HPAParser, str, int, int], None]) -> None:
    test_parser_missing_argument(hpa_parser, "source_id", SOURCE_ID_HPA, SPECIES_ID_HUMAN)
    test_parser_missing_argument(hpa_parser, "species_id", SOURCE_ID_HPA, SPECIES_ID_HUMAN)
    test_parser_missing_argument(hpa_parser, "file", SOURCE_ID_HPA, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is not found
def test_hpa_file_not_found(hpa_parser: HPAParser, test_file_not_found: Callable[[HPAParser, int, int], None]) -> None:
    test_file_not_found(hpa_parser, SOURCE_ID_HPA, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is empty
def test_hpa_empty_file(hpa_parser: HPAParser, test_empty_file: Callable[[HPAParser, str, int, int], None]) -> None:
    test_empty_file(hpa_parser, 'HPA', SOURCE_ID_HPA, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the header has insufficient columns
def test_insufficient_header_columns(hpa_parser: HPAParser) -> None:
    mock_file = io.StringIO("antibody,antibody_id\n")
    hpa_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="Malformed or unexpected header in HPA file"):
        hpa_parser.run(
            {
                "source_id": SOURCE_ID_HPA,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Parametrized test case to check if an error is raised for various malformed headers
@pytest.mark.parametrize(
    "header", [
        ("Antibodies,antibody_id,ensembl_peptide_id,link\n"),
        ("Antibody,antibodyId,ensembl_peptide_id,link\n"),
        ("Antibody,antibody_id,ensembl peptide id,link\n"),
        ("Antibody,antibody_id,ensembl_peptide_id,links\n")
    ],
    ids=["antibody column", "antibody_id column", "ensembl_id column", "link column"],
)
def test_malformed_headers(hpa_parser: HPAParser, header: str) -> None:
    mock_file = io.StringIO(header)
    hpa_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="Malformed or unexpected header in HPA file"):
        hpa_parser.run(
            {
                "source_id": SOURCE_ID_HPA,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check if an error is raised when the file has insufficient columns
def test_insufficient_columns(hpa_parser: HPAParser) -> None:
    mock_file = io.StringIO()
    mock_file.write("Antibody,antibody_id,ensembl_peptide_id,link\n")
    mock_file.write("CAB000001,1,ENSP00000363822\n")
    mock_file.seek(0)

    hpa_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="has an incorrect number of columns"):
        hpa_parser.run(
            {
                "source_id": SOURCE_ID_HPA,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check successful parsing of valid HPA data
def test_successful_parsing(mock_xref_dbi: DBConnection, hpa_parser: HPAParser) -> None:
    # Run and validate parsing for HPA file
    run_and_validate_parsing(hpa_parser, mock_xref_dbi, 10)

    # Check the row counts in the xref and direct_xref tables
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='DIRECT' AND source_id={SOURCE_ID_HPA}")
    check_row_count(mock_xref_dbi, "translation_direct_xref", 10)

    # Check the link between an xref and translation_direct_xref
    check_direct_xref_link(mock_xref_dbi, "translation", "2", "ENSP00000224784")

    # Run and validate re-parsing of the HPA file
    run_and_validate_parsing(hpa_parser, mock_xref_dbi, 10, "Re-parsing: ")

    # Re-check the row counts in the xref and direct_xref tables after re-parsing
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='DIRECT' AND source_id={SOURCE_ID_HPA}")
    check_row_count(mock_xref_dbi, "translation_direct_xref", 10)