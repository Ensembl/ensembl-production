import pytest
import os
import re
from typing import Any, Dict, Callable, Optional, List
from sqlalchemy import create_engine, text
from sqlalchemy.engine.url import make_url
from test.xrefs.test_helpers import check_dataflow_content

from ensembl.production.xrefs.ScheduleSpecies import ScheduleSpecies

DEFAULT_ARGS = {
    "run_all": False,
    "registry_url": "http://dummy_registry",
    "release": 999,
    "metasearch_url": "http://dummy_metasearch",
}

# Fixture to create a ScheduleSpecies instance
@pytest.fixture
def schedule_species() -> Callable[[Optional[Dict[str, Any]]], ScheduleSpecies]:
    def _create_schedule_species(args: Optional[Dict[str, Any]] = None) -> ScheduleSpecies:
        # Use provided args or default to default_args
        args = args or DEFAULT_ARGS

        return ScheduleSpecies(args, True, True)
    return _create_schedule_species

# Function to create dbs in the registry
def create_dbs_in_registry(registry_url: str, dbs: Dict[str, Dict[str, Any]]) -> List[str]:
    dbs_to_cleanup = []

    test_engine = create_engine(make_url(registry_url), isolation_level="AUTOCOMMIT")
    with test_engine.connect() as conn:
        # Get all dbs in the registry first
        existing_dbs = conn.execute(text(f"SHOW DATABASES")).fetchall()
        existing_dbs = [db[0] for db in existing_dbs]

        # Create the dbs that are not already in the registry
        for db_name, db_meta in dbs.items():
            if db_name not in existing_dbs:
                conn.execute(text(f"CREATE DATABASE {db_name}"))
                dbs_to_cleanup.append(db_name)

                release = db_meta.get("release")
                division = db_meta.get("division")

                # Connect to the db itself and create a table
                db_engine = create_engine(make_url(f"{registry_url}/{db_name}"), isolation_level="AUTOCOMMIT")
                with db_engine.connect() as db_conn:
                    db_conn.execute(text("CREATE TABLE dna (seq_region_id INT(10) PRIMARY KEY, sequence VARCHAR(255) NOT NULL)"))
                    db_conn.execute(text("CREATE TABLE meta (meta_id INT(10) AUTO_INCREMENT PRIMARY KEY, species_id INT(10) DEFAULT 1, meta_key VARCHAR(40) NOT NULL, meta_value VARCHAR(255) NOT NULL)"))
                    db_conn.execute(text(f"INSERT INTO meta (meta_key, meta_value) VALUES ('schema_version', '{release}')"))
                    if division:
                        db_conn.execute(text(f"INSERT INTO meta (meta_key, meta_value) VALUES ('species.division', '{division}')"))

    return dbs_to_cleanup

# Function to cleanup dbs in the registry
def cleanup_dbs_in_registry(registry_url: str, dbs: List[str]) -> None:
    test_engine = create_engine(make_url(registry_url), isolation_level="AUTOCOMMIT")
    with test_engine.connect() as conn:
        for db in dbs:
            conn.execute(text(f"DROP DATABASE IF EXISTS {db}"))

def clean_registry_url(registry_url: str) -> str:
    match = re.search(r"^(.*)://(.*)", registry_url)
    if match:
        registry_url = match.group(2)
    match = re.search(r"(.*)/(.*)$", registry_url)
    if match:
        registry_url = match.group(1)

    return registry_url

# Test case to check if an error is raised when a mandatory parameter is missing
def test_schedule_species_missing_required_param(test_missing_required_param: Callable[[str, Dict[str, Any], str], None]):
    test_missing_required_param("ScheduleSpecies", DEFAULT_ARGS, "run_all")
    test_missing_required_param("ScheduleSpecies", DEFAULT_ARGS, "registry_url")
    test_missing_required_param("ScheduleSpecies", DEFAULT_ARGS, "release")

# Test case to check if an error is raised when no species or division are provided
def test_invalid_input(schedule_species: ScheduleSpecies):
    # Create a ScheduleSpecies instance
    schedule_species_instance = schedule_species()

    with pytest.raises(ValueError, match="Must provide species or division with run_all set to False"):
        schedule_species_instance.run()

# Test case to check if an error is raised when no dbs are found (empty registry)
# def test_no_dbs_found(schedule_species: ScheduleSpecies):
#     # Create a ScheduleSpecies instance
#     args = DEFAULT_ARGS.copy()
#     args["run_all"] = True
#     schedule_species_instance = schedule_species(args)

#     with pytest.raises(LookupError, match="Could not find any matching dbs in registry dummy_registry"):
#         schedule_species_instance.run()

# Test case to check if an error is raised when a species db is present more than once
# def test_duplicate_species_dbs(schedule_species: ScheduleSpecies, pytestconfig):
#     # Create a ScheduleSpecies instance
#     test_mysql_url = pytestconfig.getoption("test_db_url")
#     args = DEFAULT_ARGS.copy()
#     args["registry_url"] = test_mysql_url
#     args["run_all"] = True
#     schedule_species_instance = schedule_species(args)

#     # Create the dbs in the registry
#     dbs = {
#         "bos_taurus_core_999_1" : {"release": 999},
#         "bos_taurus_core_999_1_temp": {"release": 999},
#     }
#     created_dbs = create_dbs_in_registry(test_mysql_url, dbs)

#     clean_url = clean_registry_url(test_mysql_url)
#     try:
#         with pytest.raises(ValueError, match=f"Database {clean_url}/bos_taurus_core_999_1 already loaded for species bos_taurus, cannot load second database {clean_url}/bos_taurus_core_999_1_temp"):
#             schedule_species_instance.run()
#     finally:
#         # Cleanup the dbs in the registry
#         cleanup_dbs_in_registry(test_mysql_url, created_dbs)

# Test case to check if an error is raised when a requested species is not found
# def test_species_not_found(schedule_species: ScheduleSpecies, pytestconfig):
#     # Create a ScheduleSpecies instance
#     test_mysql_url = pytestconfig.getoption("test_db_url")
#     args = DEFAULT_ARGS.copy()
#     args["registry_url"] = test_mysql_url
#     args["species"] = ["species1"]
#     schedule_species_instance = schedule_species(args)

#     with pytest.raises(LookupError, match="Database not found for species1, check registry parameters"):
#         schedule_species_instance.run()

# Test case to check successful run with run_all parameter
# def test_successful_run_all(schedule_species: ScheduleSpecies, pytestconfig):
#     # Create a ScheduleSpecies instance
#     test_mysql_url = pytestconfig.getoption("test_db_url")
#     test_scratch_path = pytestconfig.getoption("test_scratch_path")
#     args = DEFAULT_ARGS.copy()
#     args["registry_url"] = test_mysql_url
#     args["run_all"] = True
#     args["dataflow_output_path"] = test_scratch_path
#     schedule_species_instance = schedule_species(args)

#     # Create the dbs in the registry
#     dbs = {
#         "bos_taurus_core_999_1": {"release": 999},
#         "danio_rerio_core_999_1": {"release": 999},
#         "equus_caballus_core_999_1": {"release": 999},
#         "homo_sapiens_core_998_1": {"release": 998},
#     }
#     created_dbs = create_dbs_in_registry(test_mysql_url, dbs)

#     dataflow_file_path = os.path.join(test_scratch_path, "dataflow_species.json")
#     clean_url = clean_registry_url(test_mysql_url)
#     try:
#         # Run the ScheduleSpecies instance
#         schedule_species_instance.run()

#         # Check if the dataflow file is created
#         assert os.path.exists(dataflow_file_path), f"Expected file {dataflow_file_path} not found"

#         # Check the content of the dataflow file
#         expected_content = [
#             {"species_name": "bos_taurus", "species_db": f"{clean_url}/bos_taurus_core_999_1"},
#             {"species_name": "danio_rerio", "species_db": f"{clean_url}/danio_rerio_core_999_1"},
#             {"species_name": "equus_caballus", "species_db": f"{clean_url}/equus_caballus_core_999_1"}
#         ]
#         check_dataflow_content(dataflow_file_path, expected_content)
#     finally:
#         # Cleanup the dbs in the registry
#         cleanup_dbs_in_registry(test_mysql_url, created_dbs)

#         # Cleanup: Remove the dataflow file if it exists
#         if os.path.exists(dataflow_file_path):
#             os.remove(dataflow_file_path)

# Test case to check successful run with run_all parameter with db_prefix set
# def test_successful_run_all_prefix(schedule_species: ScheduleSpecies, pytestconfig):
#     # Create a ScheduleSpecies instance
#     test_mysql_url = pytestconfig.getoption("test_db_url")
#     test_scratch_path = pytestconfig.getoption("test_scratch_path")
#     args = DEFAULT_ARGS.copy()
#     args["registry_url"] = test_mysql_url
#     args["run_all"] = True
#     args["db_prefix"] = "testprefix"
#     args["dataflow_output_path"] = test_scratch_path
#     schedule_species_instance = schedule_species(args)

#     # Create the dbs in the registry
#     dbs = {
#         "bos_taurus_core_999_1": {"release": 999},
#         "danio_rerio_core_999_1": {"release": 999},
#         "equus_caballus_core_999_1": {"release": 999},
#         "homo_sapiens_core_998_1": {"release": 998},
#         "testprefix_homo_sapiens_core_999_1": {"release": 999},
#     }
#     created_dbs = create_dbs_in_registry(test_mysql_url, dbs)

#     dataflow_file_path = os.path.join(test_scratch_path, "dataflow_species.json")
#     clean_url = clean_registry_url(test_mysql_url)
#     try:
#         # Run the ScheduleSpecies instance
#         schedule_species_instance.run()

#         # Check if the dataflow file is created
#         assert os.path.exists(dataflow_file_path), f"Expected file {dataflow_file_path} not found"

#         # Check the content of the dataflow file
#         expected_content = [
#             {"species_name": "homo_sapiens", "species_db": f"{clean_url}/testprefix_homo_sapiens_core_999_1"},
#         ]
#         check_dataflow_content(dataflow_file_path, expected_content)
#     finally:
#         # Cleanup the dbs in the registry
#         cleanup_dbs_in_registry(test_mysql_url, created_dbs)

#         # Cleanup: Remove the dataflow file if it exists
#         if os.path.exists(dataflow_file_path):
#             os.remove(dataflow_file_path)

# Test case to check successful run with specified species
# def test_successful_run_species(schedule_species: ScheduleSpecies, pytestconfig):
#     # Create a ScheduleSpecies instance
#     test_mysql_url = pytestconfig.getoption("test_db_url")
#     test_scratch_path = pytestconfig.getoption("test_scratch_path")
#     args = DEFAULT_ARGS.copy()
#     args["registry_url"] = test_mysql_url
#     args["dataflow_output_path"] = test_scratch_path
#     args["species"] = ["bos_taurus", "danio_rerio"]
#     schedule_species_instance = schedule_species(args)

#     # Create the dbs in the registry
#     dbs = {
#         "bos_taurus_core_999_1": {"release": 999},
#         "danio_rerio_core_999_1": {"release": 999},
#         "equus_caballus_core_999_1": {"release": 999},
#         "homo_sapiens_core_998_1": {"release": 998},
#     }
#     created_dbs = create_dbs_in_registry(test_mysql_url, dbs)

#     dataflow_file_path = os.path.join(test_scratch_path, "dataflow_species.json")
#     clean_url = clean_registry_url(test_mysql_url)
#     try:
#         # Run the ScheduleSpecies instance
#         schedule_species_instance.run()

#         # Check if the dataflow file is created
#         assert os.path.exists(dataflow_file_path), f"Expected file {dataflow_file_path} not found"

#         # Check the content of the dataflow file then remove it
#         expected_content = [
#             {"species_name": "bos_taurus", "species_db": f"{clean_url}/bos_taurus_core_999_1"},
#             {"species_name": "danio_rerio", "species_db": f"{clean_url}/danio_rerio_core_999_1"},
#         ]
#         check_dataflow_content(dataflow_file_path, expected_content)
#         os.remove(dataflow_file_path)

#         # Change the antispecies
#         schedule_species_instance.set_param("antispecies", ["danio_rerio"])

#         # Run the ScheduleSpecies instance again
#         schedule_species_instance.run()

#         # Check if the dataflow file is created
#         assert os.path.exists(dataflow_file_path), f"Expected file {dataflow_file_path} not found"

#         # Check the content of the dataflow file
#         expected_content = [
#             {"species_name": "bos_taurus", "species_db": f"{clean_url}/bos_taurus_core_999_1"},
#         ]
#         check_dataflow_content(dataflow_file_path, expected_content)
#     finally:
#         # Cleanup the dbs in the registry
#         cleanup_dbs_in_registry(test_mysql_url, created_dbs)

#         # Cleanup: Remove the dataflow file if it exists
#         if os.path.exists(dataflow_file_path):
#             os.remove(dataflow_file_path)

# Test case to check successful run with specified division
# def test_successful_run_division(schedule_species: ScheduleSpecies, pytestconfig):
#     # Create a ScheduleSpecies instance
#     test_mysql_url = pytestconfig.getoption("test_db_url")
#     test_scratch_path = pytestconfig.getoption("test_scratch_path")
#     args = DEFAULT_ARGS.copy()
#     args["registry_url"] = test_mysql_url
#     args["dataflow_output_path"] = test_scratch_path
#     args["division"] = "EnsemblVertebrates"
#     schedule_species_instance = schedule_species(args)

#     # Create the dbs in the registry
#     dbs = {
#         "bos_taurus_core_999_1": {"release": 999, "division": "EnsemblVertebrates"},
#         "danio_rerio_core_999_1": {"release": 999, "division": "EnsemblVertebrates"},
#         "equus_caballus_core_999_1": {"release": 999, "division": "EnsemblVertebrates"},
#         "equus_caballus_core_998_1": {"release": 998, "division": "EnsemblVertebrates"},
#         "zea_mays_core_999_1": {"release": 999, "division": "EnsemblPlants"},
#     }
#     created_dbs = create_dbs_in_registry(test_mysql_url, dbs)

#     dataflow_file_path = os.path.join(test_scratch_path, "dataflow_species.json")
#     clean_url = clean_registry_url(test_mysql_url)
#     try:
#         # Run the ScheduleSpecies instance
#         schedule_species_instance.run()

#         # Check if the dataflow file is created
#         assert os.path.exists(dataflow_file_path), f"Expected file {dataflow_file_path} not found"

#         # Check the content of the dataflow file then remove it
#         expected_content = [
#             {"species_name": "bos_taurus", "species_db": f"{clean_url}/bos_taurus_core_999_1"},
#             {"species_name": "danio_rerio", "species_db": f"{clean_url}/danio_rerio_core_999_1"},
#             {"species_name": "equus_caballus", "species_db": f"{clean_url}/equus_caballus_core_999_1"},
#         ]
#         check_dataflow_content(dataflow_file_path, expected_content)
#         os.remove(dataflow_file_path)

#         # Change the antispecies
#         schedule_species_instance.set_param("antispecies", ["danio_rerio"])

#         # Run the ScheduleSpecies instance again
#         schedule_species_instance.run()

#         # Check if the dataflow file is created
#         assert os.path.exists(dataflow_file_path), f"Expected file {dataflow_file_path} not found"

#         # Check the content of the dataflow file
#         expected_content = [
#             {"species_name": "bos_taurus", "species_db": f"{clean_url}/bos_taurus_core_999_1"},
#             {"species_name": "equus_caballus", "species_db": f"{clean_url}/equus_caballus_core_999_1"},
#         ]
#         check_dataflow_content(dataflow_file_path, expected_content)
#         os.remove(dataflow_file_path)

#         # Change the division
#         schedule_species_instance.set_param("division", "EnsemblPlants")

#         # Run the ScheduleSpecies instance again
#         schedule_species_instance.run()

#         # Check if the dataflow file is created
#         assert os.path.exists(dataflow_file_path), f"Expected file {dataflow_file_path} not found"

#         # Check the content of the dataflow file
#         expected_content = [
#             {"species_name": "zea_mays", "species_db": f"{clean_url}/zea_mays_core_999_1"},
#         ]
#         check_dataflow_content(dataflow_file_path, expected_content)
#     finally:
#         # Cleanup the dbs in the registry
#         cleanup_dbs_in_registry(test_mysql_url, created_dbs)

#         # Cleanup: Remove the dataflow file if it exists
#         if os.path.exists(dataflow_file_path):
#             os.remove(dataflow_file_path)
