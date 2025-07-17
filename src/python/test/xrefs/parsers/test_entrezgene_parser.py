import pytest
import io
import os
from unittest.mock import MagicMock
from typing import Callable

from ensembl.production.xrefs.parsers.EntrezGeneParser import EntrezGeneParser
from ensembl.utils.database import DBConnection
from test.xrefs.test_helpers import check_row_count, check_synonym

TEST_DIR = os.path.dirname(__file__)
FLATFILES_DIR = os.path.join(TEST_DIR, "flatfiles")

# Constants
SOURCE_ID_ENTREZGENE = 1
SOURCE_ID_WIKIGENE = 2
SPECIES_ID_HUMAN = 9606
EXPECTED_NUMBER_OF_COLUMNS = 16

# Fixture to create an EntrezGeneParser instance
@pytest.fixture
def entrezgene_parser() -> EntrezGeneParser:
    return EntrezGeneParser(True)

# Function to run and validate the parsing process
def run_and_validate_parsing(entrezgene_parser: EntrezGeneParser, mock_xref_dbi: DBConnection, expected_entrez_xrefs: int, expected_wiki_xrefs: int, expected_synonyms: int, prefix: str = None) -> None:
    if prefix is None:
        prefix = ""

    result_code, result_message = entrezgene_parser.run(
        {
            "source_id": SOURCE_ID_ENTREZGENE,
            "species_id": SPECIES_ID_HUMAN,
            "file": os.path.join(FLATFILES_DIR, "entrezgene.txt"),
            "xref_dbi": mock_xref_dbi,
        }
    )

    assert result_code == 0, f"{prefix}Errors when parsing EntrezGene data"
    assert (
        f"{expected_entrez_xrefs} EntrezGene Xrefs and {expected_wiki_xrefs} WikiGene Xrefs added with {expected_synonyms} synonyms" in result_message
    ), f"{prefix}Expected '{expected_entrez_xrefs} EntrezGene Xrefs and {expected_wiki_xrefs} WikiGene Xrefs added with {expected_synonyms} synonyms' in result_message, but got: '{result_message}'"

# Test cases to check if mandatory parser arguments are passed: source_id, species_id, and file
def test_entrezgene_missing_argument(entrezgene_parser: EntrezGeneParser, test_parser_missing_argument: Callable[[EntrezGeneParser, str, int, int], None]) -> None:
    test_parser_missing_argument(entrezgene_parser, "source_id", SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN)
    test_parser_missing_argument(entrezgene_parser, "species_id", SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN)
    test_parser_missing_argument(entrezgene_parser, "file", SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is not found
def test_entrezgene_file_not_found(entrezgene_parser: EntrezGeneParser, test_file_not_found: Callable[[EntrezGeneParser, int, int], None]) -> None:
    test_file_not_found(entrezgene_parser, SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file is empty
def test_entrezgene_empty_file(entrezgene_parser: EntrezGeneParser, test_empty_file: Callable[[EntrezGeneParser, str, int, int], None]) -> None:
    test_empty_file(entrezgene_parser, 'EntrezGene', SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the header has insufficient columns
def test_insufficient_header_columns(entrezgene_parser: EntrezGeneParser) -> None:
    mock_file = io.StringIO("#tax_id\tgeneid\tsymbol\n")
    entrezgene_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="Malformed or unexpected header in EntrezGene file"):
        entrezgene_parser.run(
            {
                "source_id": SOURCE_ID_ENTREZGENE,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Parametrized test case to check if an error is raised for various malformed headers
@pytest.mark.parametrize(
    "header", [
        ("tax_ids\tGeneID\tSymbol\tLocusTag\tSynonyms\tdbXrefs\tchromosome\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneIDs\tSymbol\tLocusTag\tSynonyms\tdbXrefs\tchromosome\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbols\tLocusTag\tSynonyms\tdbXrefs\tchromosome\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbol\tLocuTag\tSynonyms\tdbXrefs\tchromosome\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbol\tLocusTag\tSyn\tdbXrefs\tchromosome\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbol\tLocusTag\tSynonyms\tdb_Xrefs\tchromosome\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbol\tLocusTag\tSynonyms\tdbXrefs\tchr\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbol\tLocusTag\tSynonyms\tdbXrefs\tchromosome\tmapp_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbol\tLocusTag\tSynonyms\tdbXrefs\tchromosome\tmap_location\tdescription:\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbol\tLocusTag\tSynonyms\tdbXrefs\tchromosome\tmap_location\tdescription\ttype__of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbol\tLocusTag\tSynonyms\tdbXrefs\tchromosome\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomen_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbol\tLocusTag\tSynonyms\tdbXrefs\tchromosome\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name\tNomenclature_status\tOther_designations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbol\tLocusTag\tSynonyms\tdbXrefs\tchromosome\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tstatus\tOther_designations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbol\tLocusTag\tSynonyms\tdbXrefs\tchromosome\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tdesignations\tModification_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbol\tLocusTag\tSynonyms\tdbXrefs\tchromosome\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tMod_date\tFeature_type\n"),
        ("#tax_id\tGeneID\tSymbol\tLocusTag\tSynonyms\tdbXrefs\tchromosome\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tModification_date\tFeaturetype\n"),
    ],
    ids=[
        "tax_id column", "gene_id column", "symbol column", "locus_tag column", "synonyms column",
        "db_xrefs column", "chromosome column", "map_location column", "description column",
        "type_of_gene column", "symbol_nomen_auth column", "full_name column", "nomen_status column",
        "other_designations column", "mofification_date column", "feature_type column"
    ],
)
def test_malformed_headers(entrezgene_parser: EntrezGeneParser, header: str) -> None:
    mock_file = io.StringIO(header)
    entrezgene_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="Malformed or unexpected header in EntrezGene file"):
        entrezgene_parser.run(
            {
                "source_id": SOURCE_ID_ENTREZGENE,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check if an error is raised when the required source_id is missing
def test_entrezgene_missing_required_source_id(entrezgene_parser: EntrezGeneParser, mock_xref_dbi: DBConnection, test_missing_required_source_id: Callable[[EntrezGeneParser, DBConnection, str, int, int, str], None]) -> None:
    test_missing_required_source_id(entrezgene_parser, mock_xref_dbi, 'WikiGene', SOURCE_ID_ENTREZGENE, SPECIES_ID_HUMAN)

# Test case to check if an error is raised when the file has insufficient columns
def test_insufficient_columns(entrezgene_parser: EntrezGeneParser) -> None:
    mock_file = io.StringIO()
    mock_file.write("#tax_id\tGeneID\tSymbol\tLocusTag\tSynonyms\tdbXrefs\tchromosome\tmap_location\tdescription\ttype_of_gene\tSymbol_from_nomenclature_authority\tFull_name_from_nomenclature_authority\tNomenclature_status\tOther_designations\tModification_date\tFeature_type\n")
    mock_file.write("9606\t1\tA1BG\t-\tA1B|ABG|GAB|HYST2477\n")
    mock_file.seek(0)

    entrezgene_parser.get_filehandle = MagicMock(return_value=mock_file)

    with pytest.raises(ValueError, match="has an incorrect number of columns"):
        entrezgene_parser.run(
            {
                "source_id": SOURCE_ID_ENTREZGENE,
                "species_id": SPECIES_ID_HUMAN,
                "file": "dummy_file.txt",
                "xref_dbi": MagicMock(),
            }
        )

# Test case to check successful parsing of valid EntrezGene data
def test_successful_parsing(mock_xref_dbi: DBConnection, entrezgene_parser: EntrezGeneParser) -> None:
    entrezgene_parser.get_source_id_for_source_name = MagicMock(return_value=SOURCE_ID_WIKIGENE)

    # Run and validate parsing for EntrezGene file
    run_and_validate_parsing(entrezgene_parser, mock_xref_dbi, 10, 10, 26)

    # Check the row counts in the xref and synonym tables
    check_row_count(mock_xref_dbi, "xref", 10, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_ENTREZGENE}")
    check_row_count(mock_xref_dbi, "xref", 10, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_WIKIGENE}")
    check_row_count(mock_xref_dbi, "synonym", 26)

    # Check the synonyms for specific accessions
    check_synonym(mock_xref_dbi, "2", SOURCE_ID_ENTREZGENE, "A2MD")
    check_synonym(mock_xref_dbi, "2", SOURCE_ID_ENTREZGENE, "CPAMD5")
    check_synonym(mock_xref_dbi, "2", SOURCE_ID_ENTREZGENE, "FWP007")
    check_synonym(mock_xref_dbi, "2", SOURCE_ID_ENTREZGENE, "S863-7")

    # Run and validate parsing for EntrezGene file
    run_and_validate_parsing(entrezgene_parser, mock_xref_dbi, 10, 10, 26, "Re-parsing: ")

    # Check the row counts in the xref and synonym tables
    check_row_count(mock_xref_dbi, "xref", 10, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_ENTREZGENE}")
    check_row_count(mock_xref_dbi, "xref", 10, f"info_type='DEPENDENT' AND source_id={SOURCE_ID_WIKIGENE}")
    check_row_count(mock_xref_dbi, "synonym", 26)
