import pytest
import os
from typing import Callable

from ensembl.production.xrefs.parsers.XenopusJamboreeParser import XenopusJamboreeParser
from ensembl.utils.database import DBConnection
from test.xrefs.test_helpers import check_row_count, check_direct_xref_link, check_description

TEST_DIR = os.path.dirname(__file__)
FLATFILES_DIR = os.path.join(TEST_DIR, "flatfiles")

# Constants
SOURCE_ID_XENOPUS_JAMBOREE = 1
SPECIES_ID_XENOPUS = 8364

# Fixture to create a XenopusJamboreeParser instance
@pytest.fixture
def xenopus_jamboree_parser() -> XenopusJamboreeParser:
    return XenopusJamboreeParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(xenopus_jamboree_parser: XenopusJamboreeParser, mock_xref_dbi: DBConnection, expected_xrefs: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = xenopus_jamboree_parser.run(
        {
            "source_id": SOURCE_ID_XENOPUS_JAMBOREE,
            "species_id": SPECIES_ID_XENOPUS,
            "file": os.path.join(FLATFILES_DIR, "xenopus_jamboree.txt"),
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing Xenopus Jamboree data"
    assert (
        f"{expected_xrefs} XenopusJamboree xrefs successfully parsed" in result_message
    ), f"{prefix}Expected '{expected_xrefs} XenopusJamboree xrefs successfully parsed' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_xenopus_jamboree_missing_argument(xenopus_jamboree_parser: XenopusJamboreeParser, test_parser_missing_argument: Callable[[XenopusJamboreeParser, str, int, int], None]) -> None:
    test_parser_missing_argument(xenopus_jamboree_parser, "source_id", SOURCE_ID_XENOPUS_JAMBOREE, SPECIES_ID_XENOPUS)
    test_parser_missing_argument(xenopus_jamboree_parser, "species_id", SOURCE_ID_XENOPUS_JAMBOREE, SPECIES_ID_XENOPUS)
    test_parser_missing_argument(xenopus_jamboree_parser, "file", SOURCE_ID_XENOPUS_JAMBOREE, SPECIES_ID_XENOPUS)

# Test case to check if an error is raised when the file is not found
def test_xenopus_jamboree_file_not_found(xenopus_jamboree_parser: XenopusJamboreeParser, test_file_not_found: Callable[[XenopusJamboreeParser, int, int], None]) -> None:
    test_file_not_found(xenopus_jamboree_parser, SOURCE_ID_XENOPUS_JAMBOREE, SPECIES_ID_XENOPUS)

# Test case to check if an error is raised when the file is empty
def test_xenopus_jamboree_empty_file(xenopus_jamboree_parser: XenopusJamboreeParser, test_empty_file: Callable[[XenopusJamboreeParser, str, int, int], None]) -> None:
    test_empty_file(xenopus_jamboree_parser, 'XenopusJamboree', SOURCE_ID_XENOPUS_JAMBOREE, SPECIES_ID_XENOPUS)

# Test case to check successful parsing of valid Xenopus Jamboree data
def test_successful_parsing(mock_xref_dbi: DBConnection, xenopus_jamboree_parser: XenopusJamboreeParser) -> None:
    # Run and validate parsing for Xenopus Jamboree file
    run_and_validate_parsing(xenopus_jamboree_parser, mock_xref_dbi, 12)

    # Check the row counts in the xref and gene_direct_xref tables
    check_row_count(mock_xref_dbi, "xref", 12, f"info_type='DIRECT' AND source_id={SOURCE_ID_XENOPUS_JAMBOREE}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 12)

    # Check the link between an xref and gene_direct_xref
    check_direct_xref_link(mock_xref_dbi, "gene", "XB-GENE-478064", "ENSXETG00000005286")
    check_direct_xref_link(mock_xref_dbi, "gene", "XB-GENE-478141", "ENSXETG00000025664")

    # Check if provenance information correctly removed from descriptions
    check_description(mock_xref_dbi, "XB-GENE-940866", "receptor (chemosensory) transporter protein 3 gene C")

    # Check if "X of Y" labels correctly removed from descriptions
    check_description(mock_xref_dbi, "XB-GENE-981482", "conserved hypothetical olfactory receptor")

    # Run and validate re-parsing for Xenopus Jamboree file
    run_and_validate_parsing(xenopus_jamboree_parser, mock_xref_dbi, 12, "Re-parsing: ")

    # Check the row counts in the xref and gene_direct_xref tables
    check_row_count(mock_xref_dbi, "xref", 12, f"info_type='DIRECT' AND source_id={SOURCE_ID_XENOPUS_JAMBOREE}")
    check_row_count(mock_xref_dbi, "gene_direct_xref", 12)