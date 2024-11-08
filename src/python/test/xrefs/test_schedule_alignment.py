import pytest
import os
import shutil
from typing import Any, Dict, Callable, Optional
from test_helpers import check_dataflow_content

from ensembl.production.xrefs.ScheduleAlignment import ScheduleAlignment

DEFAULT_ARGS = {
    "species_name": "homo_sapiens",
    "release": 999,
    "ensembl_fasta": "dummy_ensembl_fasta.fa",
    "xref_fasta": "dummy_xref_fasta.fa",
    "seq_type": "peptide",
    "xref_db_url": "mysql://user:pass@host/xref_db",
    "base_path": "dummy_base_path",
    "method": "--bestn 1",
    "query_cutoff": 100,
    "target_cutoff": 100,
    "source_id": 1,
    "source_name": "RefSeq_peptide",
    "job_index": 1,
    "chunk_size": 4000
}

# Fixture to create a ScheduleAlignment instance
@pytest.fixture
def schedule_alignment() -> Callable[[Optional[Dict[str, Any]]], ScheduleAlignment]:
    def _create_schedule_alignment(args: Optional[Dict[str, Any]] = None) -> ScheduleAlignment:
        # Use provided args or default to default_args
        args = args or DEFAULT_ARGS

        return ScheduleAlignment(args, True, True)
    return _create_schedule_alignment

# Test case to check if an error is raised when a mandatory parameter is missing
def test_schedule_alignment_missing_required_param(test_missing_required_param: Callable[[str, Dict[str, Any], str], None]):
    test_missing_required_param("ScheduleAlignment", DEFAULT_ARGS, "species_name")
    test_missing_required_param("ScheduleAlignment", DEFAULT_ARGS, "release")
    test_missing_required_param("ScheduleAlignment", DEFAULT_ARGS, "ensembl_fasta")
    test_missing_required_param("ScheduleAlignment", DEFAULT_ARGS, "xref_fasta")
    test_missing_required_param("ScheduleAlignment", DEFAULT_ARGS, "seq_type")
    test_missing_required_param("ScheduleAlignment", DEFAULT_ARGS, "xref_db_url")
    test_missing_required_param("ScheduleAlignment", DEFAULT_ARGS, "base_path")
    test_missing_required_param("ScheduleAlignment", DEFAULT_ARGS, "method")
    test_missing_required_param("ScheduleAlignment", DEFAULT_ARGS, "query_cutoff")
    test_missing_required_param("ScheduleAlignment", DEFAULT_ARGS, "target_cutoff")
    test_missing_required_param("ScheduleAlignment", DEFAULT_ARGS, "source_id")
    test_missing_required_param("ScheduleAlignment", DEFAULT_ARGS, "source_name")
    test_missing_required_param("ScheduleAlignment", DEFAULT_ARGS, "job_index")

# Test case to check successful run
def test_successful_run(schedule_alignment: ScheduleAlignment, pytestconfig: pytest.Config):
    # Setup for test parameters and create a ScheduleAlignment instance
    test_scratch_path = pytestconfig.getoption("test_scratch_path")
    args = DEFAULT_ARGS.copy()
    args["base_path"] = test_scratch_path
    args["dataflow_output_path"] = test_scratch_path
    schedule_alignment_instance = schedule_alignment(args)

    dataflow_file_path = os.path.join(test_scratch_path, "dataflow_alignment.json")
    try:
        # Create the appropriate paths and copy a fasta file
        ensembl_path = schedule_alignment_instance.get_path(test_scratch_path, "homo_sapiens", 999, "ensembl")
        shutil.copy("flatfiles/peptides.fa", ensembl_path)
        ensembl_file_path = os.path.join(ensembl_path, "peptides.fa")
        schedule_alignment_instance.set_param("ensembl_fasta", ensembl_file_path)

        # Run the ScheduleAlignment instance
        schedule_alignment_instance.run()

        # Check that an alignment path was created
        alignment_path = os.path.join(test_scratch_path, "homo_sapiens", "999", "alignment")
        assert os.path.exists(alignment_path), f"Expected path {alignment_path} not created"

        # Check if the dataflow file is created
        assert os.path.exists(dataflow_file_path), f"Expected file {dataflow_file_path} not found"

        # Check the content of the dataflow file
        expected_content = [
            {
                "species_name": "homo_sapiens", "align_method": "--bestn 1", "query_cutoff": 100, "target_cutoff": 100, "max_chunks": 3, "chunk": 1,
                "job_index": 1, "source_file": "dummy_xref_fasta.fa", "target_file": ensembl_file_path, "xref_db_url": "mysql://user:pass@host/xref_db",
                "map_file": os.path.join(alignment_path, "peptide_alignment_1_1_of_3.map"), "source_id": 1, "source_name": "RefSeq_peptide", "seq_type": "peptide"
            },
            {
                "species_name": "homo_sapiens", "align_method": "--bestn 1", "query_cutoff": 100, "target_cutoff": 100, "max_chunks": 3, "chunk": 2,
                "job_index": 1, "source_file": "dummy_xref_fasta.fa", "target_file": ensembl_file_path, "xref_db_url": "mysql://user:pass@host/xref_db",
                "map_file": os.path.join(alignment_path, "peptide_alignment_1_2_of_3.map"), "source_id": 1, "source_name": "RefSeq_peptide", "seq_type": "peptide"
            },
            {
                "species_name": "homo_sapiens", "align_method": "--bestn 1", "query_cutoff": 100, "target_cutoff": 100, "max_chunks": 3, "chunk": 3,
                "job_index": 1, "source_file": "dummy_xref_fasta.fa", "target_file": ensembl_file_path, "xref_db_url": "mysql://user:pass@host/xref_db",
                "map_file": os.path.join(alignment_path, "peptide_alignment_1_3_of_3.map"), "source_id": 1, "source_name": "RefSeq_peptide", "seq_type": "peptide"
            }
        ]
        check_dataflow_content(dataflow_file_path, expected_content)
    finally:
        # Cleanup: Remove the dataflow file if it exists
        if os.path.exists(dataflow_file_path):
            os.remove(dataflow_file_path)

        # Cleanup: Remove the homo_sapiens folder if it exists
        ensembl_path = os.path.join(test_scratch_path, "homo_sapiens")
        if os.path.exists(ensembl_path):
            shutil.rmtree(ensembl_path)