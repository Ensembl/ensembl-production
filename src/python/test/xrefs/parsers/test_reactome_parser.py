import pytest
import os
from unittest.mock import MagicMock
from typing import Callable
from sqlalchemy import text

from ensembl.production.xrefs.parsers.ReactomeParser import ReactomeParser
from ensembl.utils.database import DBConnection
from test.xrefs.test_helpers import check_row_count, check_direct_xref_link, check_dependent_xref_link, check_release

TEST_DIR = os.path.dirname(__file__)
FLATFILES_DIR = os.path.join(TEST_DIR, "flatfiles")

# Constants
SOURCE_ID_REACTOME = 1
SOURCE_ID_REACTOME_DIRECT = 2
SOURCE_ID_REACTOME_UNIPROT = 3
SOURCE_ID_REACTOME_GENE = 4
SOURCE_ID_REACTOME_TRANSCRIPT = 5
SPECIES_ID_HUMAN = 9606
SPECIES_NAME_HUMAN = "homo_sapiens"

# Fixture to create a ReactomeParser instance
@pytest.fixture
def reactome_parser() -> ReactomeParser:
    return ReactomeParser(True)

# Function to populate the database with sources
def populate_xref_db(mock_xref_dbi: DBConnection):
    source_data = [
        [SOURCE_ID_REACTOME, 'reactome', 10, ''],
        [SOURCE_ID_REACTOME_TRANSCRIPT, 'reactome_transcript', 10, ''],
        [SOURCE_ID_REACTOME_GENE, 'reactome_gene', 10, ''],
        [SOURCE_ID_REACTOME_DIRECT, 'reactome', 10, 'direct'],
        [SOURCE_ID_REACTOME_UNIPROT, 'reactome', 10, 'uniprot'],
    ]
    for row in source_data:
        mock_xref_dbi.execute(
            text(
                """
                INSERT INTO source (source_id, name, ordered, priority_description)
                VALUES (:source_id, :name, :ordered, :priority_description)
                """
            ),
            {
                "source_id": row[0],
                "name": row[1],
                "ordered": row[2],
                "priority_description": row[3],
            }
        )

    mock_xref_dbi.commit()

# Function to run and validate the parsing process
def run_and_validate_parsing(reactome_parser: ReactomeParser, mock_xref_dbi: DBConnection, file: str, expected_processed: int, expected_dependent: int, expected_direct: int, expected_errors: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = reactome_parser.run(
        {
            "source_id": SOURCE_ID_REACTOME,
            "species_id": SPECIES_ID_HUMAN,
            "species_name": SPECIES_NAME_HUMAN,
            "file": os.path.join(FLATFILES_DIR, f"{file}.txt"),
            "rel_file": os.path.join(FLATFILES_DIR, "reactome_release.txt"),
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing Reactome data"
    assert (
        f"{expected_processed} Reactome entries processed" in result_message
    ), f"{prefix}Expected '{expected_processed} Reactome entries processed' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_dependent} dependent xrefs added" in result_message
    ), f"{prefix}Expected '{expected_dependent} dependent xrefs added' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_direct} direct xrefs added" in result_message
    ), f"{prefix}Expected '{expected_direct} direct xrefs added' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_errors} not found" in result_message
    ), f"{prefix}Expected '{expected_errors} not found' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_reactome_missing_argument(reactome_parser: ReactomeParser, test_parser_missing_argument: Callable[[ReactomeParser, str, int, int], None]) -> None:
    test_parser_missing_argument(reactome_parser, "source_id", SOURCE_ID_REACTOME, SPECIES_ID_HUMAN)
    test_parser_missing_argument(reactome_parser, "species_id", SOURCE_ID_REACTOME, SPECIES_ID_HUMAN)
    test_parser_missing_argument(reactome_parser, "file", SOURCE_ID_REACTOME, SPECIES_ID_HUMAN)

# Test case to check if parsing is skipped when no species name can be found
def test_no_species_name(mock_xref_dbi: DBConnection, reactome_parser: ReactomeParser) -> None:
    result_code, result_message = reactome_parser.run(
        {
            "source_id": SOURCE_ID_REACTOME,
            "species_id": SPECIES_ID_HUMAN,
            "file": "dummy_file.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"Errors when parsing Reactome data"
    assert (
        "Skipped. Could not find species ID to name mapping" in result_message
    ), f"Expected 'Skipped. Could not find species ID to name mapping' in result_message, but got: '{result_message}'"

# Test case to check if an error is raised when the required source_id is missing
def test_reactome_missing_required_source_id(reactome_parser: ReactomeParser, mock_xref_dbi: DBConnection, test_missing_required_source_id: Callable[[ReactomeParser, DBConnection, str, int, int, str], None]) -> None:
    reactome_parser.species_id_to_names = MagicMock(return_value={SPECIES_ID_HUMAN: [SPECIES_NAME_HUMAN]})
    test_missing_required_source_id(reactome_parser, mock_xref_dbi, 'reactome', SOURCE_ID_REACTOME, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is not found
def test_reactome_file_not_found(reactome_parser: ReactomeParser, test_file_not_found: Callable[[ReactomeParser, int, int], None]) -> None:
    reactome_parser.species_id_to_names = MagicMock(return_value={SPECIES_ID_HUMAN: [SPECIES_NAME_HUMAN]})
    test_file_not_found(reactome_parser, SOURCE_ID_REACTOME, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is empty
def test_reactome_empty_file(reactome_parser: ReactomeParser, test_empty_file: Callable[[ReactomeParser, str, int, int], None]) -> None:
    reactome_parser.species_id_to_names = MagicMock(return_value={SPECIES_ID_HUMAN: [SPECIES_NAME_HUMAN]})
    test_empty_file(reactome_parser, 'Reactome', SOURCE_ID_REACTOME, SPECIES_ID_HUMAN)

# Test case to check successful parsing of valid Reactome data
# def test_successful_parsing(mock_xref_dbi: DBConnection, reactome_parser: ReactomeParser) -> None:
#     populate_xref_db(mock_xref_dbi)

#     # Run and validate parsing for Uniprot and Ensembl Reactome files
#     run_and_validate_parsing(reactome_parser, mock_xref_dbi, "reactome_UniProt", 8, 0, 0, 0)
#     run_and_validate_parsing(reactome_parser, mock_xref_dbi, "reactome_ensembl", 14, 0, 13, 1)

#     # Check the row counts in the xref, direct_xref, and dependent_xref tables
#     check_row_count(mock_xref_dbi, "xref", 6, f"info_type='DIRECT' AND source_id={SOURCE_ID_REACTOME_GENE}")
#     check_row_count(mock_xref_dbi, "xref", 4, f"info_type='DIRECT' AND source_id={SOURCE_ID_REACTOME_TRANSCRIPT}")
#     check_row_count(mock_xref_dbi, "xref", 3, f"info_type='DIRECT' AND source_id={SOURCE_ID_REACTOME_DIRECT}")
#     check_row_count(mock_xref_dbi, "gene_direct_xref", 6)
#     check_row_count(mock_xref_dbi, "transcript_direct_xref", 4)
#     check_row_count(mock_xref_dbi, "translation_direct_xref", 3)
#     check_row_count(mock_xref_dbi, "dependent_xref", 0)

#     # Check the link between an xref and direct_xref tables
#     check_direct_xref_link(mock_xref_dbi, "gene", "R-HSA-1643685", "ENSG00000000419")
#     check_direct_xref_link(mock_xref_dbi, "transcript", "R-HSA-199991", "ENST00000000233")
#     check_direct_xref_link(mock_xref_dbi, "translation", "R-HSA-199991", "ENSP00000000233")

#     # Add uniptot xrefs
#     reactome_parser.get_acc_to_xref_ids = MagicMock(return_value={"A0A075B6P5": [12], "A0A075B6S6" : [34, 56], "A0A087WPF7": [78], "A0A096LNF2": [90]})
 
#     # Run and validate re-parsing for Uniprot and Ensembl Reactome files
#     run_and_validate_parsing(reactome_parser, mock_xref_dbi, "reactome_UniProt", 8, 6, 0, 0, "Re-parsing: ")
#     run_and_validate_parsing(reactome_parser, mock_xref_dbi, "reactome_ensembl", 14, 0, 13, 1, "Re-parsing: ")

#     # Check the row counts in the xref, direct_xref, and dependent_xref tables
#     check_row_count(mock_xref_dbi, "xref", 6, f"info_type='DIRECT' AND source_id={SOURCE_ID_REACTOME_GENE}")
#     check_row_count(mock_xref_dbi, "xref", 4, f"info_type='DIRECT' AND source_id={SOURCE_ID_REACTOME_TRANSCRIPT}")
#     check_row_count(mock_xref_dbi, "xref", 3, f"info_type='DIRECT' AND source_id={SOURCE_ID_REACTOME_DIRECT}")
#     check_row_count(mock_xref_dbi, "xref", 4, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_REACTOME_UNIPROT}")
#     check_row_count(mock_xref_dbi, "gene_direct_xref", 6)
#     check_row_count(mock_xref_dbi, "transcript_direct_xref", 4)
#     check_row_count(mock_xref_dbi, "translation_direct_xref", 3)
#     check_row_count(mock_xref_dbi, "dependent_xref", 5)

#     # Check the link between an xref and dependent_xref
#     check_dependent_xref_link(mock_xref_dbi, "R-HSA-1280218", 34)
#     check_dependent_xref_link(mock_xref_dbi, "R-HSA-1280218", 56)
#     check_dependent_xref_link(mock_xref_dbi, "R-HSA-166663", 90)

#     # Check the release info
#     check_release(mock_xref_dbi, SOURCE_ID_REACTOME, "88")
