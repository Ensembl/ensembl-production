import pytest
import io
from unittest.mock import MagicMock
from typing import Callable
from sqlalchemy import text

from ensembl.production.xrefs.parsers.Mim2GeneParser import Mim2GeneParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count, check_dependent_xref_link

# Constants
SOURCE_ID_MIM2GENE = 1
SOURCE_ID_MIM_GENE = 2
SOURCE_ID_MIM_MORBID = 3
SOURCE_ID_ENTREZGENE = 4
SPECIES_ID_HUMAN = 9606
SPECIES_NAME_HUMAN = "homo_sapiens"

# Fixture to create a Mim2GeneParser instance
@pytest.fixture
def mim2gene_parser() -> Mim2GeneParser:
    return Mim2GeneParser(True)

# Mock for get_source_id_for_source_name
def mock_get_source_id_for_source_name(source_name: str, mock_xref_dbi: DBConnection) -> int:
    source_mapping = {
        "MIM_GENE": SOURCE_ID_MIM_GENE,
        "MIM_MORBID": SOURCE_ID_MIM_MORBID,
        "EntrezGene": SOURCE_ID_ENTREZGENE,
    }
    return source_mapping.get(source_name, SOURCE_ID_MIM2GENE)

# Function to populate the database with MIM and EntrezGene xrefs
def populate_xref_db(mock_xref_dbi: DBConnection):
    source_data = [
        [SOURCE_ID_MIM2GENE, 'MIM2GENE', 10],
        [SOURCE_ID_MIM_GENE, 'MIM_GENE', 10],
        [SOURCE_ID_MIM_MORBID, 'MIM_MORBID', 10],
        [SOURCE_ID_ENTREZGENE, 'EntrezGene', 10],
    ]
    for row in source_data:
        mock_xref_dbi.execute(
            text(
                """
                INSERT INTO source (source_id, name, ordered)
                VALUES (:source_id, :name, :ordered)
                """
            ),
            {
                "source_id": row[0],
                "name": row[1],
                "ordered": row[2],
            }
        )

    xref_data = [
        [1, '100050', SOURCE_ID_MIM_MORBID, SPECIES_ID_HUMAN, 'UNMAPPED'], # unmapped
        [2, '100640', SOURCE_ID_MIM_GENE, SPECIES_ID_HUMAN, 'UNMAPPED'], # dependent
        [3, '100100', SOURCE_ID_MIM_MORBID, SPECIES_ID_HUMAN, 'UNMAPPED'], # dependent
        [4, '142830', SOURCE_ID_MIM_MORBID, SPECIES_ID_HUMAN, 'UNMAPPED'], # unmapped
        [5, '142830', SOURCE_ID_MIM_GENE, SPECIES_ID_HUMAN, 'UNMAPPED'], # unmapped
        [6, '100660', SOURCE_ID_MIM_GENE, SPECIES_ID_HUMAN, 'UNMAPPED'], # dependent
        [7, '100300', SOURCE_ID_MIM_MORBID, SPECIES_ID_HUMAN, 'UNMAPPED'], # via synonym
        [8, '999999', SOURCE_ID_MIM_GENE, SPECIES_ID_HUMAN, 'UNMAPPED'], # not referenced
        [9, '216', SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN, 'DIRECT'], # <- 100640
        [10, '1131', SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN, 'DIRECT'], # <- 100100 
        [11, '218', SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN, 'DIRECT'], # 100660
        [12, '222222', SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN, 'DIRECT'], # not referenced <- via synonym
    ]
    for row in xref_data:
        mock_xref_dbi.execute(
            text(
                """
                INSERT INTO xref (xref_id, accession, source_id, species_id, info_type)
                VALUES (:xref_id, :accession, :source_id, :species_id, :info_type)
                """
            ),
            {
                "xref_id": row[0],
                "accession": row[1],
                "source_id": row[2],
                "species_id": row[3],
                "info_type": row[4],
            }
        )

    mock_xref_dbi.commit()

# Function to run and validate the parsing process
def run_and_validate_parsing(mim2gene_parser: Mim2GeneParser, mock_xref_dbi: DBConnection, expected_entries: int, expected_missed_omim: int, expected_entrez: int, expected_missed_master: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = mim2gene_parser.run(
        {
            "source_id": SOURCE_ID_MIM2GENE,
            "species_id": SPECIES_ID_HUMAN,
            "file": "parsers/flatfiles/mim2gene.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing Mim2Gene data"
    assert (
        f"Processed {expected_entries} entries" in result_message
    ), f"{prefix}Expected 'Processed {expected_entries} entries' in result message, but got: '{result_message}'"
    assert (
        f"{expected_missed_omim} had missing OMIM entries" in result_message
    ), f"{prefix}Expected '{expected_missed_omim} had missing OMIM entries' in result message, but got: '{result_message}'"
    assert (
        f"{expected_entrez} were dependent EntrezGene xrefs" in result_message
    ), f"{prefix}Expected '{expected_entrez} were dependent EntrezGene xrefs' in result message, but got: '{result_message}'"
    assert (
        f"{expected_missed_master} had missing master entries" in result_message
    ), f"{prefix}Expected '{expected_missed_master} had missing master entries' in result message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_mim2gene_no_source_id(mim2gene_parser: Mim2GeneParser, test_no_source_id: Callable[[Mim2GeneParser, int], None]) -> None:
    test_no_source_id(mim2gene_parser, SPECIES_ID_HUMAN)

def test_mim2gene_no_species_id(mim2gene_parser: Mim2GeneParser, test_no_species_id: Callable[[Mim2GeneParser, int], None]) -> None:
    test_no_species_id(mim2gene_parser, SOURCE_ID_MIM2GENE)

def test_mim2gene_no_file(mim2gene_parser: Mim2GeneParser, test_no_file: Callable[[Mim2GeneParser, int, int], None]) -> None:
    test_no_file(mim2gene_parser, SOURCE_ID_MIM2GENE, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is not found
def test_mim2gene_file_not_found(mim2gene_parser: Mim2GeneParser, test_file_not_found: Callable[[Mim2GeneParser, int, int], None]) -> None:
    test_file_not_found(mim2gene_parser, SOURCE_ID_MIM2GENE, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is empty
def test_mim2gene_empty_file(mim2gene_parser: Mim2GeneParser, test_empty_file: Callable[[Mim2GeneParser, str, int, int], None]) -> None:
    test_empty_file(mim2gene_parser, 'Mim2Gene', SOURCE_ID_MIM2GENE, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the required source_id is missing
def test_mim2gene_missing_required_source_id(mim2gene_parser: Mim2GeneParser, mock_xref_dbi: DBConnection, test_missing_required_source_id: Callable[[Mim2GeneParser, DBConnection, str, int, int, str], None]) -> None:
    test_missing_required_source_id(mim2gene_parser, mock_xref_dbi, 'MIM_GENE', SOURCE_ID_MIM2GENE, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the header has insufficient columns
def test_insufficient_header_columns(mim2gene_parser: Mim2GeneParser) -> None:
    mim2gene_parser.get_source_id_for_source_name = MagicMock(side_effect=mock_get_source_id_for_source_name)

    mock_file = io.StringIO("#MIM number\tGeneID\ttype\tSource\tMedGenCUI\n")
    mim2gene_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="Malformed or unexpected header in Mim2Gene file"):
        mim2gene_parser.run(
            {
                "source_id": SOURCE_ID_MIM2GENE,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Parametrized test case to check if an error is raised for various malformed headers
@pytest.mark.parametrize(
    "header", [
        ("#MIM\tGeneID\ttype\tSource\tMedGenCUI\tComment\n"),
        ("#MIM number\tGene_ID\ttype\tSource\tMedGenCUI\tComment\n"),
        ("#MIM number\tGeneID\tTYPE\tSource\tMedGenCUI\tComment\n"),
        ("#MIM number\tGeneID\ttype\tsource\tMedGenCUI\tComment\n"),
        ("#MIM number\tGeneID\ttype\tSource\tMedGen\tComment\n"),
        ("#MIM number\tGeneID\ttype\tSource\tMedGenCUI\tComments\n"),
    ],
    ids=["mim_number column", "gene_id column", "type column", "source column", "medgen_cui column", "comment column"],
)
def test_malformed_headers(mim2gene_parser: Mim2GeneParser, header: str) -> None:
    mim2gene_parser.get_source_id_for_source_name = MagicMock(side_effect=mock_get_source_id_for_source_name)

    mock_file = io.StringIO(header)
    mim2gene_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="Malformed or unexpected header in Mim2Gene file"):
        mim2gene_parser.run(
            {
                "source_id": SOURCE_ID_MIM2GENE,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check if an error is raised when the file has insufficient columns
def test_insufficient_columns(mim2gene_parser: Mim2GeneParser) -> None:
    mim2gene_parser.get_source_id_for_source_name = MagicMock(side_effect=mock_get_source_id_for_source_name)

    mock_file = io.StringIO()
    mock_file.write("#MIM number\tGeneID\ttype\tSource\tMedGenCUI\tComment\n")
    mock_file.write("100050\t-\tphenotype\t-\n")
    mock_file.seek(0)

    mim2gene_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="has an incorrect number of columns"):
        mim2gene_parser.run(
            {
                "source_id": SOURCE_ID_MIM2GENE,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check successful parsing of valid Mim2Gene data without existing mim or entrezgene xrefs
def test_successful_parsing_without_existing_xrefs(mock_xref_dbi: DBConnection, mim2gene_parser: Mim2GeneParser) -> None:
    mim2gene_parser.get_source_id_for_source_name = MagicMock(side_effect=mock_get_source_id_for_source_name)

    # Run and validate parsing for Mim2Gene file
    run_and_validate_parsing(mim2gene_parser, mock_xref_dbi, 9, 9, 0, 0)

    # Check that no xrefs were added
    check_row_count(mock_xref_dbi, "xref", 0)

# Test case to check successful parsing of valid Mim2Gene data with existing mim and entrezgene xrefs
def test_successful_parsing_with_existing_xrefs(mock_xref_dbi: DBConnection, mim2gene_parser: Mim2GeneParser) -> None:
    mim2gene_parser.get_source_id_for_source_name = MagicMock(side_effect=mock_get_source_id_for_source_name)
    populate_xref_db(mock_xref_dbi)

    # Check the row counts in the xref and dependent_xref tables before running the parser
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='UNMAPPED' AND source_id={SOURCE_ID_MIM_GENE}")
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='UNMAPPED' AND source_id={SOURCE_ID_MIM_MORBID}")
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='DIRECT' AND source_id={SOURCE_ID_ENTREZGENE}")
    check_row_count(mock_xref_dbi, "dependent_xref", 0)

    # Run and validate parsing for Mim2Gene file
    run_and_validate_parsing(mim2gene_parser, mock_xref_dbi, 9, 4, 3, 2)

    # Check the row counts in the xref and dependent_xref tables
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='UNMAPPED' AND source_id={SOURCE_ID_MIM_GENE}")
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_MIM_GENE}")
    check_row_count(mock_xref_dbi, "xref", 3, f"info_type='UNMAPPED' AND source_id={SOURCE_ID_MIM_MORBID}")
    check_row_count(mock_xref_dbi, "xref", 1, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_MIM_MORBID}")
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='DIRECT' AND source_id={SOURCE_ID_ENTREZGENE}")
    check_row_count(mock_xref_dbi, "dependent_xref", 3)

    # Check the link between an xref and dependent_xref
    check_dependent_xref_link(mock_xref_dbi, "100640", 9)
    check_dependent_xref_link(mock_xref_dbi, "100100", 10)

    # Run and validate re-parsing for Mim2Gene file
    run_and_validate_parsing(mim2gene_parser, mock_xref_dbi, 9, 4, 3, 2, "Re-parsing: ")

    # Check the row counts in the xref and dependent_xref tables
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='UNMAPPED' AND source_id={SOURCE_ID_MIM_GENE}")
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_MIM_GENE}")
    check_row_count(mock_xref_dbi, "xref", 3, f"info_type='UNMAPPED' AND source_id={SOURCE_ID_MIM_MORBID}")
    check_row_count(mock_xref_dbi, "xref", 1, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_MIM_MORBID}")
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='DIRECT' AND source_id={SOURCE_ID_ENTREZGENE}")
    check_row_count(mock_xref_dbi, "dependent_xref", 3)
