import pytest
import io
from unittest.mock import MagicMock
from typing import Callable

from ensembl.production.xrefs.parsers.VGNCParser import VGNCParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count, check_direct_xref_link, check_synonym

# Constants
SOURCE_ID_VGNC = 1
SPECIES_ID_P_TROGLODYTES = 9598

# Fixture to create a VGNCParser instance
@pytest.fixture
def vgnc_parser() -> VGNCParser:
    return VGNCParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(vgnc_parser: VGNCParser, mock_xref_dbi: DBConnection, expected_xrefs: int, expected_synonyms: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = vgnc_parser.run(
        {
            "source_id": SOURCE_ID_VGNC,
            "species_id": SPECIES_ID_P_TROGLODYTES,
            "file": "parsers/flatfiles/vgnc.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing VGNC data"
    assert (
        f"Loaded a total of {expected_xrefs} VGNC xrefs and added {expected_synonyms} synonyms" in result_message
    ), f"{prefix}Expected 'Loaded a total of {expected_xrefs} VGNC xrefs and added {expected_synonyms} synonyms' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_vgnc_no_source_id(vgnc_parser: VGNCParser, test_no_source_id: Callable[[VGNCParser, int], None]) -> None:
    test_no_source_id(vgnc_parser, SPECIES_ID_P_TROGLODYTES)

def test_vgnc_no_species_id(vgnc_parser: VGNCParser, test_no_species_id: Callable[[VGNCParser, int], None]) -> None:
    test_no_species_id(vgnc_parser, SOURCE_ID_VGNC)

def test_vgnc_no_file(vgnc_parser: VGNCParser, test_no_file: Callable[[VGNCParser, int, int], None]) -> None:
    test_no_file(vgnc_parser, SOURCE_ID_VGNC, SPECIES_ID_P_TROGLODYTES)

# Test case to check if an error is raised when the file is not found
def test_vgnc_file_not_found(vgnc_parser: VGNCParser, test_file_not_found: Callable[[VGNCParser, int, int], None]) -> None:
    test_file_not_found(vgnc_parser, SOURCE_ID_VGNC, SPECIES_ID_P_TROGLODYTES)

# Test case to check if an error is raised when the file is empty
def test_vgnc_empty_file(vgnc_parser: VGNCParser, test_empty_file: Callable[[VGNCParser, str, int, int], None]) -> None:
    test_empty_file(vgnc_parser, 'VGNC', SOURCE_ID_VGNC, SPECIES_ID_P_TROGLODYTES)

# Test case to check if an error is raised when required columns are missing
def test_missing_columns(vgnc_parser: VGNCParser, mock_xref_dbi: DBConnection) -> None:
    mock_file = io.StringIO("taxon_id\tvgnc_id\tsymbol\tname\tlocus_group\tlocus_type\tstatus\tlocation\tlocation_sortable:\talias_symbol\talias_name\tprev_symbol\tprev_name\tgene_family\tgene_family_id\tdate_approved_reserved\tdate_symbol_changed\tdate_name_changed\tdate_modified\tentrez_id\tuniprot_ids\n")
    vgnc_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="Can't find required columns in VGNC file"):
        vgnc_parser.run(
            {
                "source_id": SOURCE_ID_VGNC,
                "species_id": SPECIES_ID_P_TROGLODYTES,
                "file": "dummy_file.txt",
                "xref_dbi": mock_xref_dbi,
            }
        )

# Test case to check successful parsing of valid VGNC data
def test_successful_parsing(mock_xref_dbi: DBConnection, vgnc_parser: VGNCParser) -> None:
    vgnc_parser.species_id_to_taxonomy = MagicMock(return_value={})

    # Run and validate parsing for VGNC file
    run_and_validate_parsing(vgnc_parser, mock_xref_dbi, 6, 2)

    # Check the row counts in the xref, gene_direct_xref, and synonym tables
    check_row_count(mock_xref_dbi, "xref", 6, f"info_type='DIRECT' AND source_id={SOURCE_ID_VGNC}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 6)
    check_row_count(mock_xref_dbi, "synonym", 2)

    # Check the link between an xref and gene_direct_xref
    check_direct_xref_link(mock_xref_dbi, "gene", "VGNC:14660", "ENSPTRG00000013870")

    # Check the synonyms for specific accessions
    check_synonym(mock_xref_dbi, "VGNC:14659", SOURCE_ID_VGNC, "TEST_SYNONYM")
    check_synonym(mock_xref_dbi, "VGNC:3738", SOURCE_ID_VGNC, "DIP2")

    # Run and validate re-parsing for VGNC file
    run_and_validate_parsing(vgnc_parser, mock_xref_dbi, 6, 2)

    # Check the row counts in the xref, gene_direct_xref, and synonym tables
    check_row_count(mock_xref_dbi, "xref", 6, f"info_type='DIRECT' AND source_id={SOURCE_ID_VGNC}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 6)
    check_row_count(mock_xref_dbi, "synonym", 2)
