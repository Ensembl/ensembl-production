import pytest
from unittest.mock import MagicMock
from typing import Callable, Dict
from sqlalchemy import text

from ensembl.production.xrefs.parsers.RefSeqParser import RefSeqParser
from ensembl.utils.database import DBConnection
from test_helpers import check_row_count, check_dependent_xref_link, check_sequence, check_release

# Constants
SOURCE_ID_REFSEQ = 1
SOURCE_ID_REFSEQ_MRNA = 2
SOURCE_ID_REFSEQ_NCRNA = 3
SOURCE_ID_REFSEQ_MRNA_PREDICTED = 4
SOURCE_ID_REFSEQ_NCRNA_PREDICTED = 5
SOURCE_ID_REFSEQ_PEPTIDE = 6
SOURCE_ID_REFSEQ_PEPTIDE_PREDICTED = 7
SOURCE_ID_ENTREZGENE = 8
SOURCE_ID_WIKIGENE = 9
SPECIES_ID_HUMAN = 9606
SPECIES_NAME_HUMAN = "homo_sapiens"

# Fixture to create a RefSeqParser instance
@pytest.fixture
def refseq_parser() -> RefSeqParser:
    return RefSeqParser(True)

# Function to populate the database with EntrezGene and WikiGene xrefs
def populate_xref_db(mock_xref_dbi: DBConnection):
    source_data = [
        [SOURCE_ID_REFSEQ_MRNA, 'RefSeq_mRNA', 10, 'refseq'],
        [SOURCE_ID_REFSEQ_MRNA_PREDICTED, 'RefSeq_mRNA_predicted', 10, 'refseq'],
        [SOURCE_ID_REFSEQ_NCRNA, 'RefSeq_ncRNA', 10, ''],
        [SOURCE_ID_REFSEQ_NCRNA_PREDICTED, 'RefSeq_ncRNA_predicted', 10, ''],
        [SOURCE_ID_REFSEQ_PEPTIDE, 'RefSeq_peptide', 10, ''],
        [SOURCE_ID_REFSEQ_PEPTIDE_PREDICTED, 'RefSeq_peptide_predicted', 10, ''],
        [SOURCE_ID_ENTREZGENE, 'EntrezGene', 10, ''],
        [SOURCE_ID_WIKIGENE, 'WikiGene', 10, ''],
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

    xref_data = [
        [1, '105373289', SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN, 'DEPENDENT', 'LOC105373289'],
        [2, '105373289', SOURCE_ID_WIKIGENE, SPECIES_ID_HUMAN, 'DEPENDENT', 'LOC105373289'],
        [3, '100128640', SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN, 'DEPENDENT', 'ACVR2B-AS1'],
        [4, '100128640', SOURCE_ID_WIKIGENE, SPECIES_ID_HUMAN, 'DEPENDENT', 'ACVR2B-AS1'],
        [5, '102465874', SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN, 'DEPENDENT', 'MIR8075'],
        [6, '102465874', SOURCE_ID_WIKIGENE, SPECIES_ID_HUMAN, 'DEPENDENT', 'MIR8075'],
        [7, '401447', SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN, 'DEPENDENT', 'USP17L1'],
        [8, '401447', SOURCE_ID_WIKIGENE, SPECIES_ID_HUMAN, 'DEPENDENT', 'USP17L1'],
        [9, '728393', SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN, 'DEPENDENT', 'USP17L27'],
        [10, '728393', SOURCE_ID_WIKIGENE, SPECIES_ID_HUMAN, 'DEPENDENT', 'USP17L27'],
    ]
    for row in xref_data:
        mock_xref_dbi.execute(
            text(
                """
                INSERT INTO xref (xref_id, accession, source_id, species_id, info_type, label)
                VALUES (:xref_id, :accession, :source_id, :species_id, :info_type, :label)
                """
            ),
            {
                "xref_id": row[0],
                "accession": row[1],
                "source_id": row[2],
                "species_id": row[3],
                "info_type": row[4],
                "label": row[5],
            }
        )

    mock_xref_dbi.commit()

# Mock for get_source_id_for_source_name
def mock_get_source_id_for_source_name(source_name: str, mock_xref_dbi: DBConnection, desc: str = None) -> int:
    source_mapping = {
        "RefSeq_peptide": SOURCE_ID_REFSEQ_PEPTIDE,
        "RefSeq_mRNA": SOURCE_ID_REFSEQ_MRNA,
        "RefSeq_ncRNA": SOURCE_ID_REFSEQ_NCRNA,
        "RefSeq_peptide_predicted": SOURCE_ID_REFSEQ_PEPTIDE_PREDICTED,
        "RefSeq_mRNA_predicted": SOURCE_ID_REFSEQ_MRNA_PREDICTED,
        "RefSeq_ncRNA_predicted": SOURCE_ID_REFSEQ_NCRNA_PREDICTED,
        "EntrezGene": SOURCE_ID_ENTREZGENE,
        "WikiGene": SOURCE_ID_WIKIGENE,
    }
    return source_mapping.get(source_name, SOURCE_ID_REFSEQ)

# Function to run and validate the parsing process
def run_and_validate_parsing(refseq_parser: RefSeqParser, mock_xref_dbi: DBConnection, file:str, expected_xrefs: Dict[str, int], prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = refseq_parser.run(
        {
            "source_id": SOURCE_ID_REFSEQ,
            "species_id": SPECIES_ID_HUMAN,
            "species_name": SPECIES_NAME_HUMAN,
            "file": f"parsers/flatfiles/{file}.txt",
            "rel_file": "parsers/flatfiles/refseq_release.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    mrna = expected_xrefs["num_mrna"]
    mrna_pred = expected_xrefs["num_pred_mrna"]
    ncrna = expected_xrefs["num_ncrna"]
    ncrna_pred = expected_xrefs["num_pred_ncrna"]
    peptide = expected_xrefs["num_peptide"]
    peptide_pred = expected_xrefs["num_pred_peptide"]
    entrez = expected_xrefs["num_entrez"]
    wiki = expected_xrefs["num_wiki"]

    assert result_code == 0, f"{prefix}Errors when parsing RefSeq GPFF data"
    assert (
        f"Added {mrna} mRNA xrefs, {mrna_pred} predicted mRNA xrefs," in result_message
    ), f"{prefix}Expected 'Added {mrna} mRNA xrefs, {mrna_pred} predicted mRNA xrefs,' in result_message, but got: '{result_message}'"
    assert (
        f"{ncrna} ncRNA xrefs, {ncrna_pred} predicted ncRNA xrefs," in result_message
    ), f"{prefix}Expected '{ncrna} ncRNA xrefs, {ncrna_pred} predicted ncRNA xrefs,' in result_message, but got: '{result_message}'"
    assert (
        f"{peptide} peptide xrefs, and {peptide_pred} predicted peptide xrefs" in result_message
    ), f"{prefix}Expected '{peptide} peptide xrefs, and {peptide_pred} predicted peptide xref' in result_message, but got: '{result_message}'"
    assert (
        f"EntrezGene\t{entrez}" in result_message
    ), f"{prefix}Expected 'EntrezGene\t{entrez}' in result_message, but got: '{result_message}'"
    assert (
        f"WikiGene\t{wiki}" in result_message
    ), f"{prefix}Expected 'WikiGene\t{wiki}' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_refseq_missing_argument(refseq_parser: RefSeqParser, test_parser_missing_argument: Callable[[RefSeqParser, str, int, int], None]) -> None:
    test_parser_missing_argument(refseq_parser, "source_id", SOURCE_ID_REFSEQ, SPECIES_ID_HUMAN)
    test_parser_missing_argument(refseq_parser, "species_id", SOURCE_ID_REFSEQ, SPECIES_ID_HUMAN)
    test_parser_missing_argument(refseq_parser, "file", SOURCE_ID_REFSEQ, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the required source_id is missing
def test_refseq_missing_required_source_id(refseq_parser: RefSeqParser, mock_xref_dbi: DBConnection, test_missing_required_source_id: Callable[[RefSeqParser, DBConnection, str, int, int, str], None]) -> None:
    test_missing_required_source_id(refseq_parser, mock_xref_dbi, 'RefSeq_peptide', SOURCE_ID_REFSEQ, SPECIES_ID_HUMAN)

# Test case to check if parsing is skipped when no species name can be found
def test_no_species_name(mock_xref_dbi: DBConnection, refseq_parser: RefSeqParser) -> None:
    refseq_parser.get_source_id_for_source_name = MagicMock(side_effect=mock_get_source_id_for_source_name)

    result_code, result_message = refseq_parser.run(
        {
            "source_id": SOURCE_ID_REFSEQ,
            "species_id": SPECIES_ID_HUMAN,
            "file": "dummy_file.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"Errors when parsing RefSeq data"
    assert (
        "Skipped. Could not find species ID to name mapping" in result_message
    ), f"Expected 'Skipped. Could not find species ID to name mapping' in result_message, but got: '{result_message}'"

# Test case to check if parsing is skipped if file type is not supported
def test_invalid_file_type(mock_xref_dbi: DBConnection, refseq_parser: RefSeqParser) -> None:
    refseq_parser.get_source_id_for_source_name = MagicMock(side_effect=mock_get_source_id_for_source_name)

    result_code, result_message = refseq_parser.run(
        {
            "source_id": SOURCE_ID_REFSEQ,
            "species_id": SPECIES_ID_HUMAN,
            "species_name": SPECIES_NAME_HUMAN,
            "file": "dummy_file.txt",
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"Errors when parsing RefSeq data"
    assert (
        "Skipped. Could not work out sequence type" in result_message
    ), f"Expected 'Skipped. Could not work out sequence type' in result_message, but got: '{result_message}'"

# Test case to check if an error is raised when the file is not found
def test_refseq_file_not_found(refseq_parser: RefSeqParser, test_file_not_found: Callable[[RefSeqParser, int, int], None]) -> None:
    refseq_parser.get_source_id_for_source_name = MagicMock(side_effect=mock_get_source_id_for_source_name)
    refseq_parser.species_id_to_names = MagicMock(return_value={SPECIES_ID_HUMAN: [SPECIES_NAME_HUMAN]})
    refseq_parser.type_from_file = MagicMock(return_value="dna")

    test_file_not_found(refseq_parser, SOURCE_ID_REFSEQ, SPECIES_ID_HUMAN)

# Test case to check successful parsing of valid RefSeq GPFF data
def test_successful_parsing(mock_xref_dbi: DBConnection, refseq_parser: RefSeqParser) -> None:
    populate_xref_db(mock_xref_dbi)

    # Check the row counts in the xref table before running the parser
    check_row_count(mock_xref_dbi, "xref", 5, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_ENTREZGENE}")
    check_row_count(mock_xref_dbi, "xref", 5, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_WIKIGENE}")
    check_row_count(mock_xref_dbi, "dependent_xref", 0)

    # Run and validate parsing for RefSeq dna and peptide files
    expected_counts = {"num_mrna": 5, "num_pred_mrna": 2, "num_ncrna": 2, "num_pred_ncrna": 1, "num_peptide": 0, "num_pred_peptide": 0, "num_entrez": 5, "num_wiki": 5}
    run_and_validate_parsing(refseq_parser, mock_xref_dbi, "refseq_rna", expected_counts)
    expected_counts = {"num_mrna": 0, "num_pred_mrna": 0, "num_ncrna": 0, "num_pred_ncrna": 0, "num_peptide": 5, "num_pred_peptide": 3, "num_entrez": 2, "num_wiki": 2}
    run_and_validate_parsing(refseq_parser, mock_xref_dbi, "refseq_protein", expected_counts)

    # Check the row counts in the xref, dependent_xref, and primary_xref tables
    check_row_count(mock_xref_dbi, "xref", 5, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_REFSEQ_MRNA}")
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_REFSEQ_MRNA_PREDICTED}")
    check_row_count(mock_xref_dbi, "xref", 2, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_REFSEQ_NCRNA}")
    check_row_count(mock_xref_dbi, "xref", 1, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_REFSEQ_NCRNA_PREDICTED}")
    check_row_count(mock_xref_dbi, "xref", 5, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_REFSEQ_PEPTIDE}")
    check_row_count(mock_xref_dbi, "xref", 3, f"info_type='SEQUENCE_MATCH' AND source_id={SOURCE_ID_REFSEQ_PEPTIDE_PREDICTED}")
    check_row_count(mock_xref_dbi, "xref", 5, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_ENTREZGENE}")
    check_row_count(mock_xref_dbi, "xref", 5, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_WIKIGENE}")
    check_row_count(mock_xref_dbi, "dependent_xref", 16)
    check_row_count(mock_xref_dbi, "primary_xref", 18)

    # Check the link between an xref and dependent_xref
    master_xref_id = mock_xref_dbi.execute(text(f"SELECT xref_id FROM xref WHERE accession='NR_168385' AND source_id={SOURCE_ID_REFSEQ_NCRNA}")).scalar()
    check_dependent_xref_link(mock_xref_dbi, "105373289", master_xref_id)
    master_xref_id = mock_xref_dbi.execute(text(f"SELECT xref_id FROM xref WHERE accession='NP_001229259' AND source_id={SOURCE_ID_REFSEQ_PEPTIDE}")).scalar()
    check_dependent_xref_link(mock_xref_dbi, "728393", master_xref_id)
    master_xref_id = mock_xref_dbi.execute(text(f"SELECT xref_id FROM xref WHERE accession='NM_001242328' AND source_id={SOURCE_ID_REFSEQ_MRNA}")).scalar()
    check_dependent_xref_link(mock_xref_dbi, "728393", master_xref_id)

    # Check the sequences for specific accessions
    check_sequence(mock_xref_dbi, "NM_039939", SOURCE_ID_REFSEQ_MRNA, "taaatgtcttactgcttttactgttccctcctagagtccattctttactctaggagggaatagtaaaagcagtaagacattta")
    check_sequence(mock_xref_dbi, "NP_001355183", SOURCE_ID_REFSEQ_PEPTIDE, "mllmvvsmacvglflvqragphmggqdkpflsawpsavvprgghvtlrchyrhrfnnfmlykedrihvpifhgrifqegfnmspvttahagnytcrgshphsptgwsapsnpmvimvtgnhrwcsnkkkcccngpracreqk")

    # Check the release info
    check_release(mock_xref_dbi, SOURCE_ID_REFSEQ_MRNA, "NCBI Reference Sequence (RefSeq) Database Release 224, May 6, 2024")