import pytest
from unittest.mock import MagicMock
from typing import Callable, Dict

from ensembl.production.xrefs.parsers.HGNCParser import HGNCParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count, check_direct_xref_link, check_dependent_xref_link, check_synonym

# Constants
SOURCE_ID_HGNC = 1
SPECIES_ID_HUMAN = 9606
SPECIES_NAME_HUMAN = "homo_sapiens"
SOURCE_ID_CCDS = 2
SOURCE_ID_ENTREZGENE = 3
SOURCE_ID_REFSEQ = 4
SOURCE_ID_ENSEMBL_MANUAL = 5
SOURCE_ID_LRG = 6
SOURCE_ID_GENECARDS = 7
SOURCE_ID_DESC_ONLY = 8

# Fixture to create an HGNCParser instance
@pytest.fixture
def hgnc_parser() -> HGNCParser:
    return HGNCParser(True)

# Mock for get_source_id_for_source_name
def mock_get_source_id_for_source_name(source_name: str, mock_xref_dbi: DBConnection, desc: str = None) -> int:
    source_mapping = {
        "ccds": SOURCE_ID_CCDS,
        "entrezgene_manual": SOURCE_ID_ENTREZGENE,
        "refseq_manual": SOURCE_ID_REFSEQ,
        "ensembl_manual": SOURCE_ID_ENSEMBL_MANUAL,
        "lrg_hgnc_notransfer": SOURCE_ID_LRG,
        "genecards": SOURCE_ID_GENECARDS,
        "desc_only": SOURCE_ID_DESC_ONLY,
    }

    if source_name == "HGNC" and desc:
        return source_mapping.get(desc, SOURCE_ID_HGNC)

    return source_mapping.get(source_name.lower(), SOURCE_ID_HGNC)

# Function to run and validate the parsing process
def run_and_validate_parsing(hgnc_parser: HGNCParser, mock_xref_dbi: DBConnection, expected_xrefs: Dict[str, int], expected_mismatch: int, expected_synonyms: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = hgnc_parser.run(
        {
            "source_id": SOURCE_ID_HGNC,
            "species_id": SPECIES_ID_HUMAN,
            "file": "parsers/flatfiles/hgnc.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing HGNC data"
    for count_type, count in expected_xrefs.items():
        assert f"{count_type}\t{count}" in result_message, f"{prefix}Expected '{count_type}\t{count}' in result_meesgae, but got: '{result_message}'"

    assert (
        f"{expected_synonyms} synonyms added" in result_message
    ), f"{prefix}Expected '{expected_synonyms} synonyms added' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_mismatch} HGNC ids could not be associated in xrefs" in result_message
    ), f"{prefix}Expected '{expected_mismatch} HGNC ids could not be associated in xrefs' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_hgnc_no_source_id(hgnc_parser: HGNCParser, test_no_source_id: Callable[[HGNCParser, int], None]) -> None:
    test_no_source_id(hgnc_parser, SPECIES_ID_HUMAN)

def test_hgnc_no_species_id(hgnc_parser: HGNCParser, test_no_species_id: Callable[[HGNCParser, int], None]) -> None:
    test_no_species_id(hgnc_parser, SOURCE_ID_HGNC)

def test_hgnc_no_file(hgnc_parser: HGNCParser, test_no_file: Callable[[HGNCParser, int, int], None]) -> None:
    test_no_file(hgnc_parser, SOURCE_ID_HGNC, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when no CCDS database is provided
def test_no_ccds_db(hgnc_parser: HGNCParser) -> None:
    with pytest.raises(
        AttributeError, match="No ensembl ccds database provided"
    ):
        hgnc_parser.run(
            {
                "source_id": SOURCE_ID_HGNC,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check if an error is raised when the file is not found
def test_hgnc_file_not_found(hgnc_parser: HGNCParser, test_file_not_found: Callable[[HGNCParser, int, int], None]) -> None:
    hgnc_parser.construct_db_url = MagicMock(return_value="dummy_db_url")
    test_file_not_found(hgnc_parser, SOURCE_ID_HGNC, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is empty
def test_hgnc_empty_file(hgnc_parser: HGNCParser, test_empty_file: Callable[[HGNCParser, str, int, int], None]) -> None:
    hgnc_parser.construct_db_url = MagicMock(return_value="dummy_db_url")
    test_empty_file(hgnc_parser, 'HGNC', SOURCE_ID_HGNC, SPECIES_ID_HUMAN)

# Test case to check successful parsing of valid HGNC data without existing ccds, refseq, or entrezgene xrefs
def test_successful_parsing_without_existing_xrefs(mock_xref_dbi: DBConnection, hgnc_parser: HGNCParser) -> None:
    # Mock all needed methods
    hgnc_parser.get_source_name_for_source_id = MagicMock(return_value="HGNC")
    hgnc_parser.get_source_id_for_source_name = MagicMock(side_effect=mock_get_source_id_for_source_name)
    hgnc_parser.construct_db_url = MagicMock(return_value="dummy_db_url")
    hgnc_parser.get_ccds_to_ens_mapping = MagicMock(return_value={})
    hgnc_parser.get_valid_codes = MagicMock(return_value={})
    hgnc_parser.get_valid_xrefs_for_dependencies = MagicMock(return_value={})

    # Run and validate parsing for HGNC file
    expected_counts = {"ccds": 0, "entrezgene_manual": 0, "refseq_manual": 0, "ensembl_manual": 19, "lrg": 2, "genecards": 19}
    run_and_validate_parsing(hgnc_parser, mock_xref_dbi, expected_counts, 1, 78)

    # Check the row counts in the xref, gene_direct_xref, dependent_xref, and synonym tables
    check_row_count(mock_xref_dbi, "xref", 19, f"info_type='DIRECT' AND source_id={SOURCE_ID_ENSEMBL_MANUAL}")
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='DIRECT' AND source_id={SOURCE_ID_LRG}")
    check_row_count(mock_xref_dbi, "xref", 19, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_GENECARDS}")
    check_row_count(mock_xref_dbi, "xref", 1, f"info_type='MISC' AND source_id={SOURCE_ID_DESC_ONLY}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 21)
    check_row_count(mock_xref_dbi, "dependent_xref", 19)
    check_row_count(mock_xref_dbi, "synonym", 78)

    # Check the link between an xref and gene_direct_xref
    check_direct_xref_link(mock_xref_dbi, "gene", "HGNC:5", "ENSG00000121410")

# Test case to check successful parsing of valid HGNC data with existing ccds, refseq, and entrezgene xrefs
def test_successful_parsing_with_existing_xrefs(mock_xref_dbi: DBConnection, hgnc_parser: HGNCParser) -> None:
    # Mock all needed methods
    hgnc_parser.get_source_name_for_source_id = MagicMock(return_value="HGNC")
    hgnc_parser.get_source_id_for_source_name = MagicMock(side_effect=mock_get_source_id_for_source_name)
    hgnc_parser.construct_db_url = MagicMock(return_value="dummy_db_url")
    hgnc_parser.get_ccds_to_ens_mapping = MagicMock(return_value={"CCDS12976": "CCDS12976", "CCDS8856": "CCDS8856", "CCDS53797": "CCDS53797"})
    hgnc_parser.get_valid_codes = MagicMock(return_value={"NM_130786": [12], "NR_026971": [34, 56], "NR_015380": [78], "NM_001088": [90]})
    hgnc_parser.get_valid_xrefs_for_dependencies = MagicMock(return_value={"503538": 123, "441376": 456, "51146": 789})

    # Run and validate parsing for HGNC file
    expected_counts = {"ccds": 3, "entrezgene_manual": 3, "refseq_manual": 5, "ensembl_manual": 19, "lrg": 2, "genecards": 19}
    run_and_validate_parsing(hgnc_parser, mock_xref_dbi, expected_counts, 1, 90)

    # Check the row counts in the xref, gene_direct_xref, dependent_xref, and synonym tables
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='DIRECT' AND source_id={SOURCE_ID_CCDS}")
    check_row_count(mock_xref_dbi, "xref", 19, f"info_type='DIRECT' AND source_id={SOURCE_ID_ENSEMBL_MANUAL}")
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='DIRECT' AND source_id={SOURCE_ID_LRG}")
    check_row_count(mock_xref_dbi, "xref", 19, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_GENECARDS}")
    check_row_count(mock_xref_dbi, "xref", 3, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_ENTREZGENE}")
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_REFSEQ}")
    check_row_count(mock_xref_dbi, "xref", 1, f"info_type='MISC' AND source_id={SOURCE_ID_DESC_ONLY}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 24)
    check_row_count(mock_xref_dbi, "dependent_xref", 27)
    check_row_count(mock_xref_dbi, "synonym", 90)

    # Check the link between an xref and gene_direct_xref
    check_direct_xref_link(mock_xref_dbi, "gene", "HGNC:13666", "CCDS8856")
    check_direct_xref_link(mock_xref_dbi, "gene", "HGNC:20", "LRG_359")

    # Check the link between an xref and dependent_xref
    check_dependent_xref_link(mock_xref_dbi, "HGNC:5", 12)
    check_dependent_xref_link(mock_xref_dbi, "HGNC:27057", 56)
    check_dependent_xref_link(mock_xref_dbi, "HGNC:17968", 789)

    # Check the synonyms for specific accessions
    check_synonym(mock_xref_dbi, "HGNC:8", SOURCE_ID_ENSEMBL_MANUAL, "A2MP")
    check_synonym(mock_xref_dbi, "HGNC:37133", SOURCE_ID_ENTREZGENE, "FLJ23569")
    check_synonym(mock_xref_dbi, "HGNC:37133", SOURCE_ID_REFSEQ, "FLJ23569")

    # Run and validate re-parsing for HGNC file
    run_and_validate_parsing(hgnc_parser, mock_xref_dbi, expected_counts, 1, 90, "Re-parsing: ")

    # Check the row counts in the xref, gene_direct_xref, dependent_xref, and synonym tables
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='DIRECT' AND source_id={SOURCE_ID_CCDS}")
    check_row_count(mock_xref_dbi, "xref", 19, f"info_type='DIRECT' AND source_id={SOURCE_ID_ENSEMBL_MANUAL}")
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='DIRECT' AND source_id={SOURCE_ID_LRG}")
    check_row_count(mock_xref_dbi, "xref", 19, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_GENECARDS}")
    check_row_count(mock_xref_dbi, "xref", 3, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_ENTREZGENE}")
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_REFSEQ}")
    check_row_count(mock_xref_dbi, "xref", 1, f"info_type='MISC' AND source_id={SOURCE_ID_DESC_ONLY}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 24)
    check_row_count(mock_xref_dbi, "dependent_xref", 27)
    check_row_count(mock_xref_dbi, "synonym", 90)

