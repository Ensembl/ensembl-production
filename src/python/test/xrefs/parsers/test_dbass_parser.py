import pytest
import io
from unittest.mock import MagicMock
from typing import Callable

from ensembl.production.xrefs.parsers.DBASSParser import DBASSParser
from ensembl.utils.database import DBConnection
from test.xrefs.test_helpers import check_row_count, check_synonym, check_direct_xref_link

# Constants
SOURCE_ID_DBASS3 = 1
SOURCE_ID_DBASS5 = 2
SPECIES_ID_HUMAN = 9606
EXPECTED_NUMBER_OF_COLUMNS = 23

# Fixture to create a DBASSParser instance
@pytest.fixture
def dbass_parser() -> DBASSParser:
    return DBASSParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(dbass_parser: DBASSParser, mock_xref_dbi: DBConnection, source_id: int, file: str, expected_direct_xrefs: int, expected_skipped_xrefs: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = dbass_parser.run(
        {
            "source_id": source_id,
            "species_id": SPECIES_ID_HUMAN,
            "file": f"parsers/flatfiles/{file}.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing {file.upper()} data"
    assert (
        f"{expected_direct_xrefs} direct xrefs successfully processed" in result_message
    ), f"{prefix}Expected '{expected_direct_xrefs} direct xrefs successfully processed' in result_message, but got: '{result_message}'"
    assert (
        f"Skipped {expected_skipped_xrefs} unmapped xrefs" in result_message
    ), f"{prefix}Expected 'Skipped {expected_skipped_xrefs} unmapped xrefs' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_dbass_missing_argument(dbass_parser: DBASSParser, test_parser_missing_argument: Callable[[DBASSParser, str, int, int], None]) -> None:
    test_parser_missing_argument(dbass_parser, "source_id", SOURCE_ID_DBASS3, SPECIES_ID_HUMAN)
    test_parser_missing_argument(dbass_parser, "species_id", SOURCE_ID_DBASS3, SPECIES_ID_HUMAN)
    test_parser_missing_argument(dbass_parser, "file", SOURCE_ID_DBASS3, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is not found
def test_dbass_file_not_found(dbass_parser: DBASSParser, test_file_not_found: Callable[[DBASSParser, int, int], None]) -> None:
    test_file_not_found(dbass_parser, SOURCE_ID_DBASS3, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is empty
def test_dbass_empty_file(dbass_parser: DBASSParser, test_empty_file: Callable[[DBASSParser, str, int, int], None]) -> None:
    test_empty_file(dbass_parser, 'DBASS', SOURCE_ID_DBASS3, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the header has insufficient columns
def test_insufficient_header_columns(dbass_parser: DBASSParser) -> None:
    mock_file = io.StringIO("Id,GeneSymbol,GeneFullName,EnsemblReference\n")
    dbass_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="Malformed or unexpected header in DBASS file"):
        dbass_parser.run(
            {
                "source_id": SOURCE_ID_DBASS3,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Parametrized test case to check if an error is raised for various malformed headers
@pytest.mark.parametrize(
    "header", [
        ("GeneId,GeneSymbol,GeneFullName,EnsemblReference,Phenotype,OmimReference,Mutation,Location,AuthenticAberrantDistance,ReadingFrameChange,NucleotideSequence,InTerminalExon,Comment,MutationCoordinates,AberrantSpliceSiteCoordinates,MaximumEntropyModelAuthentic,MaximumEntropyModelCryptic,FirstOrderMarkovModelAuthentic,FirstOrderMarkovModelCryptic,WeightMatrixModelAuthentic,WeightMatrixModelCryptic,PubMedReference,ReferenceText\n"),
        ("Id,GeneSymbols,GeneFullName,EnsemblReference,Phenotype,OmimReference,Mutation,Location,AuthenticAberrantDistance,ReadingFrameChange,NucleotideSequence,InTerminalExon,Comment,MutationCoordinates,AberrantSpliceSiteCoordinates,MaximumEntropyModelAuthentic,MaximumEntropyModelCryptic,FirstOrderMarkovModelAuthentic,FirstOrderMarkovModelCryptic,WeightMatrixModelAuthentic,WeightMatrixModelCryptic,PubMedReference,ReferenceText\n"),
        ("Id,GeneSymbol,GeneFullName,EnsemblRef,Phenotype,OmimReference,Mutation,Location,AuthenticAberrantDistance,ReadingFrameChange,NucleotideSequence,InTerminalExon,Comment,MutationCoordinates,AberrantSpliceSiteCoordinates,MaximumEntropyModelAuthentic,MaximumEntropyModelCryptic,FirstOrderMarkovModelAuthentic,FirstOrderMarkovModelCryptic,WeightMatrixModelAuthentic,WeightMatrixModelCryptic,PubMedReference,ReferenceText\n"),
    ],
    ids=["first column", "second column", "fourth column"],
)
def test_malformed_headers(dbass_parser: DBASSParser, header: str) -> None:
    mock_file = io.StringIO(header)
    dbass_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="Malformed or unexpected header in DBASS file"):
        dbass_parser.run(
            {
                "source_id": SOURCE_ID_DBASS3,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check if an error is raised when the file has insufficient columns
def test_insufficient_columns(dbass_parser: DBASSParser) -> None:
    mock_file = io.StringIO()
    mock_file.write(
        "Id,GeneSymbol,GeneFullName,EnsemblReference,Phenotype,OmimReference,Mutation,Location,AuthenticAberrantDistance,ReadingFrameChange,NucleotideSequence,InTerminalExon,Comment,MutationCoordinates,AberrantSpliceSiteCoordinates,MaximumEntropyModelAuthentic,MaximumEntropyModelCryptic,FirstOrderMarkovModelAuthentic,FirstOrderMarkovModelCryptic,WeightMatrixModelAuthentic,WeightMatrixModelCryptic,PubMedReference,ReferenceText\n"
    )
    mock_file.write("1,GNAS complex locus,ENSG00000087460,Hereditary osteodystrophy,103580\n")
    mock_file.seek(0)

    dbass_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="has an incorrect number of columns"):
        dbass_parser.run(
            {
                "source_id": SOURCE_ID_DBASS3,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check successful parsing
def test_successful_parsing(mock_xref_dbi: DBConnection, dbass_parser: DBASSParser) -> None:
    # Run and validate parsing for DBASS3 and DBASS5 files
    run_and_validate_parsing(dbass_parser, mock_xref_dbi, SOURCE_ID_DBASS3, "dbass3", 6, 1)
    run_and_validate_parsing(dbass_parser, mock_xref_dbi, SOURCE_ID_DBASS5, "dbass5", 6, 0)

    # Check the row counts in the xref, gene_direct_xref, and synonym tables
    check_row_count(mock_xref_dbi, "xref", 6, f"info_type='DIRECT' AND source_id={SOURCE_ID_DBASS3}")
    check_row_count(mock_xref_dbi, "xref", 6, f"info_type='DIRECT' AND source_id={SOURCE_ID_DBASS5}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 12)
    check_row_count(mock_xref_dbi, "synonym", 3)

    # Check the link between an xref and gene_direct_xref
    check_direct_xref_link(mock_xref_dbi, "gene", "2", "ENSG00000130164")

    # Check the synonyms for specific accessions
    check_synonym(mock_xref_dbi, "2", SOURCE_ID_DBASS3, "LDLT")
    check_synonym(mock_xref_dbi, "3", SOURCE_ID_DBASS3, "LDLT")
    check_synonym(mock_xref_dbi, "4", SOURCE_ID_DBASS3, "LDLT")

    # Run and validate re-parsing for DBASS3 file
    run_and_validate_parsing(dbass_parser, mock_xref_dbi, SOURCE_ID_DBASS3, "dbass3", 6, 1, "Re-parsing: ")

    # Check the row counts in the xref, gene_direct_xref, and synonym tables
    check_row_count(mock_xref_dbi, "xref", 6, f"info_type='DIRECT' AND source_id={SOURCE_ID_DBASS3}")
    check_row_count(mock_xref_dbi, "xref", 6, f"info_type='DIRECT' AND source_id={SOURCE_ID_DBASS5}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 12)
    check_row_count(mock_xref_dbi, "synonym", 3)
