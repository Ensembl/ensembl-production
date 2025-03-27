import argparse
import csv
import sys
from pathlib import Path
import yaml

import logging
import os
import requests

from sqlalchemy import func, select
from ensembl.database import DBConnection
from ensembl.production.metadata.api.models.dataset import (
    DatasetType,
    Dataset,
    DatasetSource,
    DatasetStatus,
)
from ensembl.production.metadata.api.models.genome import Genome, GenomeDataset

# Configure root logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)  # Set minimum level for all handlers
logger.handlers.clear()
formatter = logging.Formatter(
    "%(asctime)s - %(name)s - %(levelname)s - %(filename)s:%(lineno)d - %(message)s"
)

# ERROR log handler
error_file_handler = logging.FileHandler("error.log")
error_file_handler.setLevel(logging.ERROR)
error_file_handler.setFormatter(formatter)
logger.addHandler(error_file_handler)

# Console handler (shows INFO and above)
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.INFO)
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)

logger = logging.getLogger(__name__)


class TrackUtils:

    def __init__(self, genome_uuid):
        self.genome_uuid = genome_uuid
        self.yaml_templates_list = [
            entry.stem
            for entry in Path(ARGS.track_templates_dir).iterdir()
            if entry.is_file()
        ]
        self.custom_variant_track_data = self.get_variant_track_data()
        self.custom_gene_track_data = self.get_gene_track_data()

    def submit_tracks(self, track_file:str)-> None:
        filename = os.path.splitext(track_file)[0]
        # Skip file
        if filename == "variant-details" or filename.endswith("-summary"):
            return
        # Exact match
        if filename in self.yaml_templates_list:
            track_payload = self.get_track_payload(template_name=filename)
            self.post_track(track_payload)
            return
        multimatch = False
        for template_name in self.yaml_templates_list:
            # Multiple templates for one track file which will result in multiple entries in tackAPI
            if template_name.startswith(filename):
                track_payload = self.get_track_payload(template_name)
                self.post_track(track_payload)
                multimatch = True
            # Template matches a datafile with different suffix (e.g. repeats.repeatmask*.bb)
            if not multimatch and filename.startswith(template_name):
                track_payload=self.get_track_payload(template_name)
                track_payload = self.update_track_payload(track_payload, datafile=track_file)
                self.post_track(track_payload)
                return

    def get_track_payload(self, template_name:str)-> dict:
        track_api_json = self.read_yaml_template(template_name=f"{template_name}.yaml")
        track_api_json["genome_id"] = self.genome_uuid
        if track_api_json["type"] == "gene":
            track_api_json.update(self.custom_gene_track_data)
        if track_api_json["type"] == "variant":
            track_api_json.update(self.custom_variant_track_data)
        return track_api_json

    @staticmethod
    def update_track_payload(track_payload: dict, datafile: str)-> dict:
        for key, value in track_payload["datafiles"].items():
            # derive bw filename for bb/bw datafile pairs
            if key.endswith("summary") and value:
                nameroot = datafile[: datafile.rfind("-")]
                track_payload["datafiles"][key] = f"{nameroot}-summary.bw"
            else:
                track_payload["datafiles"][key] = datafile
        return track_payload
    @staticmethod
    def check_directory(path:str)->str:
        if not os.path.isdir(path):
            raise argparse.ArgumentTypeError(f"The directory '{path}' does not exist.")
        return path

    @staticmethod
    def read_yaml_template(template_name:str)->dict:
        track_template = ARGS.track_templates_dir + template_name
        if Path(track_template).is_file():
            with open(track_template, "r") as template_file:
                track_payload = yaml.safe_load(template_file)
            return track_payload

    @staticmethod
    def post_track(track_payload:dict)-> None:
        try:
            request = requests.post(f"{ARGS.track_api_url}/track", json=track_payload)
            if request.status_code == 201:
                logger.info("All good! Here is the payload just in case:")
                logger.info(track_payload)
            else:
                logger.error("Error while posting data:")
                logger.info(track_payload)
                logger.error(request.json())
        except Exception as e:
            logger.error(track_payload)
            logger.error(e)

    def get_variant_track_data(self) -> dict:
        variant_data_csv = f"{ARGS.track_templates_dir}variant-track-desc.csv"
        try:
            with open(variant_data_csv) as data:
                reader = csv.DictReader(data)
                variant_data_dict = {}
                for line in reader:
                    if self.genome_uuid == line["Genome_UUID"]:
                        variant_data_dict={
                            "description": line["Description"],
                            "track_name": line["Track_name"] if "Track_name" in line else "",
                            "source_names": line["Source_name"].split(","),
                            "source_urls": line["Source_URL"].split(","),
                        }
                        # Remove key, value if value is empty:
                        variant_data_dict = {k: v for k, v in variant_data_dict.items() if v}
                        break

                return variant_data_dict.get(self.genome_uuid,{})
        except FileNotFoundError:
            logger.error(f"Error: track description CSV file not found in {variant_data_csv}")
        except KeyError as e:
            logger.error(f"Error: unexpected CSV format in {variant_data_csv} ({e})")
    def get_gene_track_data(self)-> dict:
        try:
            query = (
                select(Dataset)
                .outerjoin(Dataset.genome_datasets)
                .filter(Dataset.dataset_type.has(DatasetType.name.in_([ARGS.dataset_type])))
            )
            if self.genome_uuid:
                query = query.filter(
                    GenomeDataset.genome.has(Genome.genome_uuid.in_([self.genome_uuid]))
                )
            if ARGS.species:
                query = query.filter(
                    GenomeDataset.genome.has(Genome.production_name.in_(ARGS.species))
                )

            logger.info(f"Quering metadata : {query} ")

            result_dict = {}
            with DBConnection(ARGS.metadata_db_uri).session_scope() as session:
                for dataset in session.scalars(query):
                    row_data = {"label": dataset.dataset_source.name}
                    # Set species and uuid from genome
                    for genome_dataset in dataset.genome_datasets:
                        genome = genome_dataset.genome
                        row_data["species"] = genome.production_name
                    # Set attribute values
                    for attrib in dataset.dataset_attributes:
                        if attrib.attribute.name == "genebuild.provider_url":
                            row_data.setdefault("sources", [{"url": attrib.value}])
                        if attrib.attribute.name in ARGS.dataset_attributes:
                            row_data.setdefault("description", "Annotated")
                    # Set annotation type
                    if row_data.get("genebuild.provider_name") == "Ensembl":
                        row_data["description"] = "Imported"
                    # Remove key, value if value is empty:
                    row_data = {k: v for k, v in row_data.items() if v}
                    result_dict[genome.genome_uuid] = row_data
            return result_dict
        except Exception as e:
            logger.error("Error connecting to DB",e)



if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="Create Metadata CSV File For Track API Loading"
    )
    parser.add_argument(
        "--genome_uuid",
        type=str,
        nargs="*",
        default=[],
        required=False,
        help="List of genome UUIDs to filter the query. Default is an empty list.",
    )
    parser.add_argument(
        "--species",
        type=str,
        nargs="*",
        default=[],
        required=False,
        help="List of Species Production names to filter the query. Default is an empty list.",
    )
    parser.add_argument(
        "--dataset_attributes",
        type=str,
        nargs="*",
        default=["genebuild.provider_name", "genebuild.provider_url"],
        required=False,
        help="Fetch dataset attribute values for given dataset type name",
    )
    parser.add_argument(
        "--metadata_db_uri",
        type=str,
        required=True,
        help="metadata db mysql uri, ex: mysql://ensro@localhost:3366/ensembl_genome_metadata",
    )
    parser.add_argument(
        "--dataset_type",
        type=str,
        default="genebuild",
        required=False,
        help="Fetch Dataset Based on dataset type Ex: genebuild",
    )
    parser.add_argument(
        "--file_path",
        type=TrackUtils.check_directory,
        required=False,
        help="Path to the genome browser files directory ",
    )

    parser.add_argument(
        "--track_templates_dir",
        type=TrackUtils.check_directory,
        required=True,
        help="Track API templates directory.",
    )
    parser.add_argument(
        "--track_api_url",
        type=str,
        required=True,
        help="Track API url Ex: https://dev-2020.ensembl.org/api/tracks/",
    )

    ARGS = parser.parse_args()
    logger.info(f"Provided Arguments  {ARGS} ")


    genome_uuid_directory = [path.name for path in Path(ARGS.file_path).iterdir() if path.is_dir()]
    genome_uuid_list = ARGS.genome_uuid if ARGS.genome_uuid else genome_uuid_directory
    for genome_uuid in genome_uuid_list:
        track_utils = TrackUtils(genome_uuid=genome_uuid)
        gene_track_data = track_utils.get_gene_track_data()


        track_data_dir = Path(track_utils.check_directory(ARGS.file_path + genome_uuid + "/"))
        track_data_file_list = [
            entry.stem for entry in track_data_dir.iterdir() if entry.is_file()
        ]
        for track_file in track_data_file_list:
            track_utils.submit_tracks(track_file)

