import json
from sqlalchemy import text
from typing import List, Dict, Any

from ensembl.utils.database import DBConnection

# Helper function to check the row count in a specific table
def check_row_count(db: DBConnection, table: str, expected_count: int, where_clause: str = None) -> None:
    sql = f"SELECT COUNT(*) FROM {table}"
    if where_clause is not None:
        sql += f" WHERE {where_clause}"

    row_count = db.execute(text(sql)).scalar()
    assert (
        row_count == expected_count
    ), f"Expected {expected_count} rows in {table} table (WHERE: {where_clause or ''}), but got {row_count}"

# Helper function to check the synonym for a specific accession
def check_synonym(db: DBConnection, accession: str, source_id: int, expected_synonym: str) -> None:
    synonym = db.execute(
        text(
            f"SELECT s.synonym FROM synonym s, xref x WHERE s.xref_id=x.xref_id AND x.accession='{accession}' AND x.source_id={source_id} AND s.synonym='{expected_synonym}'"
        )
    ).scalar()
    assert (
        synonym == expected_synonym
    ), f"Expected synonym '{expected_synonym}' for accession '{accession}', but got '{synonym}'"

# Helper function to check the direct xref connection for a specific accession
def check_direct_xref_link(db: DBConnection, type: str, accession: str, expected_stable_id: str) -> None:
    stable_id = db.execute(
        text(
            f"SELECT d.ensembl_stable_id FROM {type}_direct_xref d, xref x WHERE d.general_xref_id=x.xref_id AND x.accession='{accession}' AND d.ensembl_stable_id='{expected_stable_id}'"
        )
    ).scalar()
    assert (
        stable_id == expected_stable_id
    ), f"Expected link between accession '{accession}' and EnsEMBL stable ID '{expected_stable_id}', but got '{stable_id}'"

# Helper function to check the dependent xref connection for a specific accession
def check_dependent_xref_link(db: DBConnection, accession: str, expected_master_xref_id: str) -> None:
    master_xref_id = db.execute(
        text(
            f"SELECT d.master_xref_id FROM dependent_xref d, xref x WHERE d.dependent_xref_id=x.xref_id AND x.accession='{accession}' AND d.master_xref_id={expected_master_xref_id}"
        )
    ).scalar()
    assert (
        master_xref_id == expected_master_xref_id
    ), f"Expected link between accession '{accession}' and master xref ID '{expected_master_xref_id}', but got '{master_xref_id}'"

# Helper function to check the sequence for a specific accession
def check_sequence(db: DBConnection, accession: str, source_id: int, expected_sequence: str) -> None:
    sequence = db.execute(
        text(
            f"SELECT p.sequence FROM primary_xref p, xref x WHERE p.xref_id=x.xref_id AND x.accession='{accession}' AND x.source_id={source_id}"
        )
    ).scalar()
    assert (
        sequence == expected_sequence
    ), f"Expected sequence '{expected_sequence}' for accession '{accession}', but got '{sequence}'"

# Helper function to check the description for a specific accession
def check_description(db: DBConnection, accession: str, expected_description: str) -> None:
    description = db.execute(
        text(
            f"SELECT description FROM xref WHERE accession='{accession}'"
        )
    ).scalar()
    assert (
        description == expected_description
    ), f"Expected description '{expected_description}' for accession '{accession}', but got '{description}'"

# Helper function to check the release info for a specific source_id
def check_release(db: DBConnection, source_id: str, expected_release: str) -> None:
    release = db.execute(
        text(
            f"SELECT source_release FROM source WHERE source_id={source_id}"
        )
    ).scalar()
    assert (
        release == expected_release
    ), f"Expected release info '{expected_release}' for source_id {source_id}, but got '{release}'"

# Helper function to check the dataflow content of a dataflow file
def check_dataflow_content(dataflow_file_path: str, expected_content: List[Dict[str, Any]]) -> None:
    # Get the content of the dataflow file
    actual_content = []
    with open(dataflow_file_path) as fh:
        for line in fh:
            actual_content.append(json.loads(line.strip()))

    # Sort both the expected and actual content lists
    actual_content_sorted = sorted(actual_content, key=lambda x: json.dumps(x, sort_keys=True))
    expected_content_sorted = sorted(expected_content, key=lambda x: json.dumps(x, sort_keys=True))

    # Compare the expected and actual content
    assert actual_content_sorted == expected_content_sorted, (
        f"Dataflow file content does not match expected content.\n"
        f"Expected (sorted): {expected_content_sorted}\n"
        f"Actual (sorted): {actual_content_sorted}"
    )