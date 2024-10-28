import pytest
import io
from unittest.mock import MagicMock
from typing import Callable

from ensembl.production.xrefs.parsers.MGIDescParser import MGIDescParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count, check_synonym

# Constants
SOURCE_ID_MGI_DESC = 1
SPECIES_ID_MOUSE = 10090
EXPECTED_NUMBER_OF_COLUMNS = 12

# Fixture to create an MGIDescParser instance
@pytest.fixture
def mgi_desc_parser() -> MGIDescParser:
    return MGIDescParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(mgi_desc_parser: MGIDescParser, mock_xref_dbi: DBConnection, expected_xrefs: int, expected_synonyms: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = mgi_desc_parser.run(
        {
            "source_id": SOURCE_ID_MGI_DESC,
            "species_id": SPECIES_ID_MOUSE,
            "file": "parsers/flatfiles/mgi_desc.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing MGI Description data"
    assert (
        f"{expected_xrefs} MGI Description Xrefs added" in result_message
    ), f"{prefix}Expected '{expected_xrefs} MGI Description Xrefs added' in result_message, but got: '{result_message}'"
    assert (
        f"{expected_synonyms} synonyms added" in result_message
    ), f"{prefix}Expected '{expected_synonyms} synonyms added' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_mgi_desc_no_source_id(mgi_desc_parser: MGIDescParser, test_no_source_id: Callable[[MGIDescParser, int], None]) -> None:
    test_no_source_id(mgi_desc_parser, SPECIES_ID_MOUSE)

def test_mgi_desc_no_species_id(mgi_desc_parser: MGIDescParser, test_no_species_id: Callable[[MGIDescParser, int], None]) -> None:
    test_no_species_id(mgi_desc_parser, SOURCE_ID_MGI_DESC)

def test_mgi_desc_no_file(mgi_desc_parser: MGIDescParser, test_no_file: Callable[[MGIDescParser, int, int], None]) -> None:
    test_no_file(mgi_desc_parser, SOURCE_ID_MGI_DESC, SPECIES_ID_MOUSE)

# Test case to check if an error is raised when the file is not found
def test_mgi_desc_file_not_found(mgi_desc_parser: MGIDescParser, test_file_not_found: Callable[[MGIDescParser, int, int], None]) -> None:
    test_file_not_found(mgi_desc_parser, SOURCE_ID_MGI_DESC, SPECIES_ID_MOUSE)

# Test case to check if an error is raised when the file is empty
def test_mgi_desc_empty_file(mgi_desc_parser: MGIDescParser, test_empty_file: Callable[[MGIDescParser, str, int, int], None]) -> None:
    test_empty_file(mgi_desc_parser, 'MGI_desc', SOURCE_ID_MGI_DESC, SPECIES_ID_MOUSE)

# Test case to check if an error is raised when the header has insufficient columns
def test_insufficient_header_columns(mgi_desc_parser: MGIDescParser) -> None:
    mock_file = io.StringIO("mgi accession id\tchr\tcm position\n")
    mgi_desc_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="Malformed or unexpected header in MGI_desc file"):
        mgi_desc_parser.run(
            {
                "source_id": SOURCE_ID_MGI_DESC,
                "species_id": SPECIES_ID_MOUSE,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Parametrized test case to check if an error is raised for various malformed headers
@pytest.mark.parametrize(
    "header", [
        ("MGI_accession_ID\tChr\tcM Position\tgenome coordinate start\tgenome coordinate end\tstrand\tMarker Symbol\tStatus\tMarker Name\tMarker Type\tFeature Type\tMarker Synonyms (pipe-separated)\n"),
        ("MGI Accession ID\tChromosome\tcM Position\tgenome coordinate start\tgenome coordinate end\tstrand\tMarker Symbol\tStatus\tMarker Name\tMarker Type\tFeature Type\tMarker Synonyms (pipe-separated)\n"),
        ("MGI Accession ID\tChr\tcM Pos\tgenome coordinate start\tgenome coordinate end\tstrand\tMarker Symbol\tStatus\tMarker Name\tMarker Type\tFeature Type\tMarker Synonyms (pipe-separated)\n"),
        ("MGI Accession ID\tChr\tcM Position\tgenome coord start\tgenome coordinate end\tstrand\tMarker Symbol\tStatus\tMarker Name\tMarker Type\tFeature Type\tMarker Synonyms (pipe-separated)\n"),
        ("MGI Accession ID\tChr\tcM Position\tgenome coordinate start\tgenome coord end\tstrand\tMarker Symbol\tStatus\tMarker Name\tMarker Type\tFeature Type\tMarker Synonyms (pipe-separated)\n"),
        ("MGI Accession ID\tChr\tcM Position\tgenome coordinate start\tgenome coordinate end\tchr strand\tMarker Symbol\tStatus\tMarker Name\tMarker Type\tFeature Type\tMarker Synonyms (pipe-separated)\n"),
        ("MGI Accession ID\tChr\tcM Position\tgenome coordinate start\tgenome coordinate end\tstrand\tSymbol\tStatus\tMarker Name\tMarker Type\tFeature Type\tMarker Synonyms (pipe-separated)\n"),
        ("MGI Accession ID\tChr\tcM Position\tgenome coordinate start\tgenome coordinate end\tstrand\tMarker Symbol\tMarker Status\tMarker Name\tMarker Type\tFeature Type\tMarker Synonyms (pipe-separated)\n"),
        ("MGI Accession ID\tChr\tcM Position\tgenome coordinate start\tgenome coordinate end\tstrand\tMarker Symbol\tStatus\tName\tMarker Type\tFeature Type\tMarker Synonyms (pipe-separated)\n"),
        ("MGI Accession ID\tChr\tcM Position\tgenome coordinate start\tgenome coordinate end\tstrand\tMarker Symbol\tStatus\tMarker Name\tMarker_Type\tFeature Type\tMarker Synonyms (pipe-separated)\n"),
        ("MGI Accession ID\tChr\tcM Position\tgenome coordinate start\tgenome coordinate end\tstrand\tMarker Symbol\tStatus\tMarker Name\tMarker Type\tFeature Types\tMarker Synonyms (pipe-separated)\n"),
        ("MGI Accession ID\tChr\tcM Position\tgenome coordinate start\tgenome coordinate end\tstrand\tMarker Symbol\tStatus\tMarker Name\tMarker Type\tFeature Type\tMarker Synonyms\n"),
    ],
    ids=[
        "accession column", "chromosome column", "position column", "coord start column",
        "coord end column", "strand column", "symbol column", "status column", "name column",
        "marker type column", "feature type column", "synonyms column"
    ],
)
def test_malformed_headers(mgi_desc_parser: MGIDescParser, header: str) -> None:
    mock_file = io.StringIO(header)
    mgi_desc_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="Malformed or unexpected header in MGI_desc file"):
        mgi_desc_parser.run(
            {
                "source_id": SOURCE_ID_MGI_DESC,
                "species_id": SPECIES_ID_MOUSE,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check if an error is raised when the file has insufficient columns
def test_insufficient_columns(mgi_desc_parser: MGIDescParser) -> None:
    mock_file = io.StringIO()
    mock_file.write("MGI Accession ID\tChr\tcM Position\tgenome coordinate start\tgenome coordinate end\tstrand\tMarker Symbol\tStatus\tMarker Name\tMarker Type\tFeature Type\tMarker Synonyms (pipe-separated)\n")
    mock_file.write("MGI:1341858\t5\tsyntenic\n")
    mock_file.seek(0)

    mgi_desc_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="has an incorrect number of columns"):
        mgi_desc_parser.run(
            {
                "source_id": SOURCE_ID_MGI_DESC,
                "species_id": SPECIES_ID_MOUSE,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check successful parsing of valid MGI Description data
def test_successful_parsing(mock_xref_dbi: DBConnection, mgi_desc_parser: MGIDescParser) -> None:
    # Run and validate parsing for MGI Description file
    run_and_validate_parsing(mgi_desc_parser, mock_xref_dbi, 10, 2)

    # Check the row counts in the xref and synonym tables
    check_row_count(mock_xref_dbi, "xref", 10, f"info_type='MISC' AND source_id={SOURCE_ID_MGI_DESC}")
    check_row_count(mock_xref_dbi, "synonym", 2)

    # Check the synonyms for specific accessions
    check_synonym(mock_xref_dbi, "MGI:1926146", SOURCE_ID_MGI_DESC, "Ecrg4")

    # Run and validate re-parsing for MGI Description file
    run_and_validate_parsing(mgi_desc_parser, mock_xref_dbi, 10, 2, "Re-parsing: ")

    # Check the row counts in the xref and synonym tables again
    check_row_count(mock_xref_dbi, "xref", 10, f"info_type='MISC' AND source_id={SOURCE_ID_MGI_DESC}")
    check_row_count(mock_xref_dbi, "synonym", 2)

