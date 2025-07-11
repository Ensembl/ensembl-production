import pytest
from unittest.mock import MagicMock
from typing import Callable, Dict
from sqlalchemy import text

from ensembl.production.xrefs.parsers.UniProtParser import UniProtParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count, check_synonym, check_direct_xref_link, check_dependent_xref_link, check_sequence, check_release

# Constants
SOURCE_ID_UNIPROT = 1
SOURCE_ID_SWISSPROT = 2
SOURCE_ID_TREMBL = 3
SOURCE_ID_TREMBL_NON_DISPLAY = 4
SOURCE_ID_SWISSPROT_DIRECT = 5
SOURCE_ID_TREMBL_DIRECT = 6
SOURCE_ID_ISOFORM = 7
SOURCE_ID_PDB = 8
SOURCE_ID_STRING = 9
SOURCE_ID_EMBL = 10
SOURCE_ID_BIOGRID = 11
SOURCE_ID_CHEMBL = 12
SOURCE_ID_UNIPROT_GN = 13
SOURCE_ID_PROTEIN_ID = 14
SPECIES_ID_HUMAN = 9606
SPECIES_NAME_HUMAN = "homo_sapiens"

# Fixture to create a UniProtParser instance
@pytest.fixture
def uniprot_parser() -> UniProtParser:
    return UniProtParser(True)

# Function to populate the database with sources
def populate_xref_db(mock_xref_dbi: DBConnection):
    source_data = [
        [SOURCE_ID_SWISSPROT, 'Uniprot/SWISSPROT', 10, 'sequence_mapped'],
        [SOURCE_ID_TREMBL, 'Uniprot/SPTREMBL', 10, 'sequence_mapped'],
        [SOURCE_ID_TREMBL_NON_DISPLAY, 'Uniprot/SPTREMBL', 10, 'protein_evidence_gt_2'],
        [SOURCE_ID_SWISSPROT_DIRECT, 'Uniprot/SWISSPROT', 10, 'direct'],
        [SOURCE_ID_TREMBL_DIRECT, 'Uniprot/SPTREMBL', 10, 'direct'],
        [SOURCE_ID_ISOFORM, 'Uniprot_isoform', 10, ''],
        [SOURCE_ID_PDB, 'PDB', 10, ''],
        [SOURCE_ID_STRING, 'STRING', 10, ''],
        [SOURCE_ID_EMBL, 'EMBL', 10, ''],
        [SOURCE_ID_BIOGRID, 'BioGRID', 10, ''],
        [SOURCE_ID_CHEMBL, 'ChEMBL', 10, ''],
        [SOURCE_ID_UNIPROT_GN, 'Uniprot_gn', 10, ''],
        [SOURCE_ID_PROTEIN_ID, 'protein_id', 10, ''],
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
def run_and_validate_parsing(uniprot_parser: UniProtParser, mock_xref_dbi: DBConnection, file:str, expected_xrefs: Dict[str, int], expected_deps: Dict[str, int], prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = uniprot_parser.run(
        {
            "source_id": SOURCE_ID_UNIPROT,
            "species_id": SPECIES_ID_HUMAN,
            "file": f"parsers/flatfiles/{file}.txt",
            "rel_file": "parsers/flatfiles/uniprot_release.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    sp = expected_xrefs["num_sp"]
    sptr = expected_xrefs["num_sptr"]
    sptr_non_display = expected_xrefs["num_sptr_non_display"]
    direct_sp = expected_xrefs["num_direct_sp"]
    direct_sptr = expected_xrefs["num_direct_sptr"]
    isoform = expected_xrefs["num_isoform"]
    skipped = expected_xrefs["num_skipped"]

    assert result_code == 0, f"{prefix}Errors when parsing UniProt data"
    assert (
        f"Read {sp} SwissProt xrefs, {sptr} SPTrEMBL xrefs with protein evidence codes 1-2," in result_message
    ), f"{prefix}Expected 'Read {sp} SwissProt xrefs, {sptr} SPTrEMBL xrefs with protein evidence codes 1-2,' in result_message, but got: '{result_message}'"
    assert (
        f"and {sptr_non_display} SPTrEMBL xrefs with protein evidence codes > 2 from" in result_message
    ), f"{prefix}Expected 'and {sptr_non_display} SPTrEMBL xrefs with protein evidence codes > 2 from' in result_message, but got: '{result_message}'"
    assert (
        f"Added {direct_sp} direct SwissProt xrefs and {direct_sptr} direct SPTrEMBL xrefs" in result_message
    ), f"{prefix}Expected 'Added {direct_sp} direct SwissProt xrefs and {direct_sptr} direct SPTrEMBL xrefs' in result_message, but got: '{result_message}'"
    assert (
        f"Added {isoform} direct isoform xrefs" in result_message
    ), f"{prefix}Expected 'Added {isoform} direct isoform xrefs' in result_message, but got: '{result_message}'"
    assert (
        f"Skipped {skipped} ensembl annotations as Gene names" in result_message
    ), f"{prefix}Expected 'Skipped {skipped} ensembl annotations as Gene names' in result_message, but got: '{result_message}'"

    for count_type, count in expected_deps.items():
        assert f"{count_type}\t{count}" in result_message, f"{prefix}Expected '{count_type}\t{count}' in result_meesgae, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_uniprot_missing_argument(uniprot_parser: UniProtParser, test_parser_missing_argument: Callable[[UniProtParser, str, int, int], None]) -> None:
    test_parser_missing_argument(uniprot_parser, "source_id", SOURCE_ID_UNIPROT, SPECIES_ID_HUMAN)
    test_parser_missing_argument(uniprot_parser, "species_id", SOURCE_ID_UNIPROT, SPECIES_ID_HUMAN)
    test_parser_missing_argument(uniprot_parser, "file", SOURCE_ID_UNIPROT, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the required source_id is missing
def test_uniprot_missing_required_source_id(uniprot_parser: UniProtParser, mock_xref_dbi: DBConnection, test_missing_required_source_id: Callable[[UniProtParser, DBConnection, str, int, int, str], None]) -> None:
    test_missing_required_source_id(uniprot_parser, mock_xref_dbi, 'Uniprot/SWISSPROT', SOURCE_ID_SWISSPROT, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is not found
def test_uniprot_file_not_found(uniprot_parser: UniProtParser, test_file_not_found: Callable[[UniProtParser, int, int], None]) -> None:
    test_file_not_found(uniprot_parser, SOURCE_ID_UNIPROT, SPECIES_ID_HUMAN)

# Test case to check successful parsing of valid UniProt data
def test_successful_parsing(mock_xref_dbi: DBConnection, uniprot_parser: UniProtParser) -> None:
    populate_xref_db(mock_xref_dbi)

    # Run and validate parsing for UniProt SWISSPROT file
    expected_counts = {"num_sp": 4, "num_sptr": 0, "num_sptr_non_display": 0, "num_direct_sp": 8, "num_direct_sptr": 0, "num_isoform": 6, "num_skipped": 1}
    expected_deps = {"PDB": 50, "STRING": 4, "EMBL": 34, "BioGRID": 4, "ChEMBL": 4, "protein_id": 34, "Uniprot_gn": 3}
    run_and_validate_parsing(uniprot_parser, mock_xref_dbi, "uniprot_swissprot", expected_counts, expected_deps)

    # Run and validate parsing for UniProt TREMBL file
    expected_counts = {"num_sp": 0, "num_sptr": 1, "num_sptr_non_display": 8, "num_direct_sp": 0, "num_direct_sptr": 0, "num_isoform": 0, "num_skipped": 0}
    expected_deps = {"EMBL": 49, "protein_id": 49, "Uniprot_gn": 7}
    run_and_validate_parsing(uniprot_parser, mock_xref_dbi, "uniprot_trembl", expected_counts, expected_deps)

    # Check the row counts in the xref, translation_direct_xref, dependent_xref, primary_xref, and synonym tables
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_SWISSPROT}")
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='DIRECT' AND source_id={SOURCE_ID_SWISSPROT_DIRECT}")
    check_row_count(mock_xref_dbi, "xref", 1, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_TREMBL}")
    check_row_count(mock_xref_dbi, "xref", 0, f"info_type='DIRECT' AND source_id={SOURCE_ID_TREMBL_DIRECT}")
    check_row_count(mock_xref_dbi, "xref", 8, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_TREMBL_NON_DISPLAY}")
    check_row_count(mock_xref_dbi, "xref", 49, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_PDB}")
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_STRING}")
    check_row_count(mock_xref_dbi, "xref", 83, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_EMBL}")
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_BIOGRID}")
    check_row_count(mock_xref_dbi, "xref", 4, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_CHEMBL}")
    check_row_count(mock_xref_dbi, "xref", 10, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_UNIPROT_GN}")
    check_row_count(mock_xref_dbi, "xref", 83, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_PROTEIN_ID}")
    check_row_count(mock_xref_dbi, "translation_direct_xref", 14)
    check_row_count(mock_xref_dbi, "dependent_xref", 238)
    check_row_count(mock_xref_dbi, "primary_xref", 13)
    check_row_count(mock_xref_dbi, "synonym", 16)

    # Check the link between an xref and translation_direct_xref
    check_direct_xref_link(mock_xref_dbi, "translation", "P62258", "ENSP00000461762")
    check_direct_xref_link(mock_xref_dbi, "translation", "P31946-1", "ENSP00000361930")

    # Check the link between an xref and dependent_xref
    master_xref_id = mock_xref_dbi.execute(text(f"SELECT xref_id FROM xref WHERE accession='Q4F4R7' AND source_id={SOURCE_ID_TREMBL_NON_DISPLAY}")).scalar()
    check_dependent_xref_link(mock_xref_dbi, "DQ305032", master_xref_id)
    check_dependent_xref_link(mock_xref_dbi, "AGQ46203", master_xref_id)
    master_xref_id = mock_xref_dbi.execute(text(f"SELECT xref_id FROM xref WHERE accession='P62258' AND source_id={SOURCE_ID_SWISSPROT}")).scalar()
    check_dependent_xref_link(mock_xref_dbi, "6EIH", master_xref_id)

    # Check the sequences for specific accessions
    check_sequence(mock_xref_dbi, "Q04917", SOURCE_ID_SWISSPROT, "MGDREQLLQRARLAEQAERYDDMASAMKAVTELNEPLSNEDRNLLSVAYKNVVGARRSSWEAGEGN")
    check_sequence(mock_xref_dbi, "A0A7D5YZ42", SOURCE_ID_TREMBL_NON_DISPLAY, "LSKVYGPVFTLYFGLKPIVVLHGYEAVKEALIDLGEEFSGRGIFPLAERANRGFGIVFSNGKKWKEIRHFSLMTLRNFGMGKRSIEDRVQEEARCLVEELRKTKGG")

    # Check the synonyms for specific accessions
    check_synonym(mock_xref_dbi, "P62258", SOURCE_ID_UNIPROT_GN, "YWHAE1")
    check_synonym(mock_xref_dbi, "P61981", SOURCE_ID_SWISSPROT, "P35214")
    check_synonym(mock_xref_dbi, "P61981", SOURCE_ID_SWISSPROT, "Q9UDP2")

    # Check the release info
    check_release(mock_xref_dbi, SOURCE_ID_SWISSPROT, "UniProtKB/Swiss-Prot Release 2024_03 of 29-May-2024")
    check_release(mock_xref_dbi, SOURCE_ID_TREMBL, "UniProtKB/TrEMBL Release 2024_03 of 29-May-2024")