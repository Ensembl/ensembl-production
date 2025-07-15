import pytest
from unittest.mock import MagicMock
from typing import Callable
from sqlalchemy import text

from ensembl.production.xrefs.parsers.ZFINParser import ZFINParser
from ensembl.utils.database import DBConnection
from test.xrefs.test_helpers import check_row_count, check_direct_xref_link, check_dependent_xref_link, check_synonym, check_description

# Constants
SOURCE_ID_ZFIN = 1
SOURCE_ID_DIRECT = 2
SOURCE_ID_DEPENDENT = 3
SOURCE_ID_DESCRIPTION = 4
SOURCE_ID_UNIPROT = 5
SOURCE_ID_REFSEQ = 6
SPECIES_ID_ZEBRAFISH = 7955

# Fixture to create a ZFINParser instance
@pytest.fixture
def zfin_parser() -> ZFINParser:
    return ZFINParser(True)

# Function to populate the database with ZFIN Desc, Uniprot, and RefSeq xrefs
def populate_xref_db(mock_xref_dbi: DBConnection):
    source_data = [
        [SOURCE_ID_DESCRIPTION, 'ZFIN_ID', 10, 'description_only'],
        [SOURCE_ID_DIRECT, 'ZFIN_ID', 1, 'direct'],
        [SOURCE_ID_DEPENDENT, 'ZFIN_ID', 2, 'uniprot/refseq'],
        [SOURCE_ID_UNIPROT, 'Uniprot/SWISSPROT', 20, ''],
        [SOURCE_ID_REFSEQ, 'RefSeq_dna', 15, ''],
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
                "priority_description": row[3]
            }
        )

    xref_data = [
        [1, 'ZDB-GENE-000125-4', SOURCE_ID_DESCRIPTION, SPECIES_ID_ZEBRAFISH, 'MISC', 'deltaC'],
        [2, 'ZDB-GENE-000201-9', SOURCE_ID_DESCRIPTION, SPECIES_ID_ZEBRAFISH, 'MISC', 'anosmin 1a'],
        [3, 'ZDB-GENE-000128-18', SOURCE_ID_DESCRIPTION, SPECIES_ID_ZEBRAFISH, 'MISC', 'anoctamin 1'],
        [4, 'A0A8M9PP76', SOURCE_ID_UNIPROT, SPECIES_ID_ZEBRAFISH, 'SEQUENCE_MATCH', ''],
        [5, 'B2GNV2', SOURCE_ID_UNIPROT, SPECIES_ID_ZEBRAFISH, 'SEQUENCE_MATCH', ''],
        [6, 'Q9PTU1', SOURCE_ID_UNIPROT, SPECIES_ID_ZEBRAFISH, 'SEQUENCE_MATCH', ''],
        [7, 'NP_571533', SOURCE_ID_REFSEQ, SPECIES_ID_ZEBRAFISH, 'SEQUENCE_MATCH', ''],
        [8, 'NM_131458', SOURCE_ID_REFSEQ, SPECIES_ID_ZEBRAFISH, 'SEQUENCE_MATCH', ''],
    ]
    for row in xref_data:
        mock_xref_dbi.execute(
            text(
                """
                INSERT INTO xref (xref_id, accession, source_id, species_id, info_type, description)
                VALUES (:xref_id, :accession, :source_id, :species_id, :info_type, :description)
                """
            ),
            {
                "xref_id": row[0],
                "accession": row[1],
                "source_id": row[2],
                "species_id": row[3],
                "info_type": row[4],
                "description": row[5]
            }
        )

    mock_xref_dbi.commit()

# Function to run and validate the parsing process
def run_and_validate_parsing(zfin_parser: ZFINParser, mock_xref_dbi: DBConnection, expected_direct_xrefs: int, expected_uniprot_xrefs: int, expected_refseq_xref: int, expected_mismatch: int, expected_synonyms: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = zfin_parser.run(
        {
            "source_id": SOURCE_ID_ZFIN,
            "species_id": SPECIES_ID_ZEBRAFISH,
            "file": "parsers/flatfiles/zfin/dummy_file.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing ZFIN data"
    assert (
        f"{expected_direct_xrefs} direct ZFIN xrefs added and" in result_message
    ), f"{prefix}Expected '{expected_direct_xrefs} direct ZFIN xrefs added and' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_uniprot_xrefs} dependent xrefs from UniProt added" in result_message
    ), f"{prefix}Expected '{expected_uniprot_xrefs} dependent xrefs from UniProt added' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_refseq_xref} dependent xrefs from RefSeq added" in result_message
    ), f"{prefix}Expected '{expected_refseq_xref} dependent xrefs from RefSeq added' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_mismatch} dependents ignored" in result_message
    ), f"{prefix}Expected '{expected_mismatch} dependents ignored' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_synonyms} synonyms loaded" in result_message
    ), f"{prefix}Expected '{expected_synonyms} synonyms loaded' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_zfin_missing_argument(zfin_parser: ZFINParser, test_parser_missing_argument: Callable[[ZFINParser, str, int, int], None]) -> None:
    test_parser_missing_argument(zfin_parser, "source_id", SOURCE_ID_ZFIN, SPECIES_ID_ZEBRAFISH)
    test_parser_missing_argument(zfin_parser, "species_id", SOURCE_ID_ZFIN, SPECIES_ID_ZEBRAFISH)
    test_parser_missing_argument(zfin_parser, "file", SOURCE_ID_ZFIN, SPECIES_ID_ZEBRAFISH)

# Test case to check if an error is raised when the required source_id is missing
def test_zfin_missing_required_source_id(zfin_parser: ZFINParser, mock_xref_dbi: DBConnection, test_missing_required_source_id: Callable[[ZFINParser, DBConnection, str, int, int, str], None]) -> None:
    test_missing_required_source_id(zfin_parser, mock_xref_dbi, 'ZFIN_ID', SOURCE_ID_ZFIN, SPECIES_ID_ZEBRAFISH, 'direct')

# Test case to check if an error is raised when the file is not found
def test_zfin_file_not_found(zfin_parser: ZFINParser, test_file_not_found: Callable[[ZFINParser, int, int], None]) -> None:
    test_file_not_found(zfin_parser, SOURCE_ID_ZFIN, SPECIES_ID_ZEBRAFISH)

# Test case to check if an error is raised when the file is empty
def test_dbass_empty_file(zfin_parser: ZFINParser, test_empty_file: Callable[[ZFINParser, str, int, int], None]) -> None:
    test_empty_file(zfin_parser, 'ZFIN Ensembl', SOURCE_ID_ZFIN, SPECIES_ID_ZEBRAFISH)

# Test case to check successful parsing
def test_successful_parsing(mock_xref_dbi: DBConnection, zfin_parser: ZFINParser) -> None:
    populate_xref_db(mock_xref_dbi)

    # Check the row counts in the xref before running the parser
    check_row_count(mock_xref_dbi, "xref", 3, f"info_type='MISC' AND source_id={SOURCE_ID_DESCRIPTION}")
    check_row_count(mock_xref_dbi, "xref", 3, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_UNIPROT}")
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_REFSEQ}")

    # Run and validate parsing for ZFIN files
    run_and_validate_parsing(zfin_parser, mock_xref_dbi, 10, 3, 2, 9, 5)

    # Check the row counts in the xref, dependent_xref, and synonym tables
    check_row_count(mock_xref_dbi, "xref", 10, f"info_type='DIRECT' AND source_id={SOURCE_ID_DIRECT}")
    check_row_count(mock_xref_dbi, "xref", 3, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_DEPENDENT}")
    check_row_count(mock_xref_dbi, "dependent_xref", 5)
    check_row_count(mock_xref_dbi, "synonym", 7)

    # Check the link between an xref and gene_direct_xref
    check_direct_xref_link(mock_xref_dbi, "gene", "ZDB-GENE-000125-4", "ENSDARG00000002336")

    # Check the link between an xref and dependent_xref
    check_dependent_xref_link(mock_xref_dbi, "ZDB-GENE-000128-18", 5)
    check_dependent_xref_link(mock_xref_dbi, "ZDB-GENE-000128-18", 6)
    check_dependent_xref_link(mock_xref_dbi, "ZDB-GENE-000201-96", 7)

    # Check the synonyms for specific accessions
    check_synonym(mock_xref_dbi, "ZDB-GENE-000125-12", SOURCE_ID_DIRECT, "Df(LG03)")
    check_synonym(mock_xref_dbi, "ZDB-GENE-000128-18", SOURCE_ID_DEPENDENT, "Tg(NBT:MAPT-GFP)")

    # Check the descriptions for specific accessions
    check_description(mock_xref_dbi, "ZDB-GENE-000125-4", "deltaC")
    check_description(mock_xref_dbi, "ZDB-GENE-000201-9", "anosmin 1a")
    check_description(mock_xref_dbi, "ZDB-GENE-000128-18", "anoctamin 1")
