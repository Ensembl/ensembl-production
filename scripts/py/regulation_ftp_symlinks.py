#!/usr/bin/env python
#
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2024] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Creates Regulation FTP symlinks.

This script is in charge of creating Regulation FTP symlinks from data files folders to:
    - GENE-SWITCH project folder under the public miscellaneous directory [PEAKS, SIGNALS] - misc/gene-switch/regulation
    - Release specific folder [PEAKS, SIGNALS] - release-[RELEASE_VERSION]/regulation/[SPECIES]/[ASSEMBLY]

Typical usage example:
    python3 regulation_ftp_symlinks.py -f /nfs/production/flicek/ensembl/production/ensemblftp/ -r 110

Required Args:
  -f, --ftp_path        - FTP root path
  -r, --release_version - Release version

Optional Args:
  -h, --help            - Show help message
  -d, --delete_symlinks - Delete symlinks
"""


import logging
from argparse import ArgumentParser
from collections import defaultdict
from os import listdir, makedirs, path, walk
from pathlib import Path

# Human and Mouse follow a different dir structure
SPECIES_TO_NOT_INCLUDE = []

# GENE-SWITCH species
GENE_SWITCH_SPECIES = [
    "sus_scrofa",
    "gallus_gallus",
    "gallus_gallus_gca000002315v5",
]

PUBLIC_PUB_PATH = "PUBLIC/pub"
DATA_FILES_PATH = "data_files/"
DATA_FILES_PATH_TEMPLATE = "{ftp_path}/data_files/{species}/{assembly}/funcgen"
RELEASE_FOLDER_PATH_TEMPLATE = (
    "{ftp_path}/release-{release}/regulation/{species}/{assembly}"
)
MISC_GENE_SWITCH_PATH_TEMPLATE = (
    "{ftp_path}/misc/gene-switch/regulation/{species}/{assembly}"
)

ANALYSIS_TYPE_PEAKS = "peaks"
ANALYSIS_TYPE_SIGNAL = "signal"
ANALYSIS_TYPES = [ANALYSIS_TYPE_PEAKS, ANALYSIS_TYPE_SIGNAL]

# Logging
logging.basicConfig(format="%(message)s")
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


class Validator:
    @staticmethod
    def is_dir(to_validate, check=False):
        result = to_validate.is_dir()
        if check:
            return result
        else:
            if not result:
                raise NotADirectoryError(f"Dir {to_validate} not found.")

    @staticmethod
    def is_file(to_validate, check=False):
        result = to_validate.is_file()
        if check:
            return result
        else:
            if not result:
                raise FileNotFoundError(f"File {to_validate} not found.")

    @staticmethod
    def analysis_type_is_valid(to_validate, check=False):
        result = to_validate in ANALYSIS_TYPES
        if check:
            return result
        else:
            if not result:
                raise TypeError(f"Invalid analysis type {to_validate}.")

    @staticmethod
    def is_symlink(to_validate, check=False):
        result = to_validate.is_symlink()
        if check:
            return result
        else:
            if not result:
                raise NotADirectoryError(f"Symlink {to_validate} not found.")


validator = Validator()


class Utils:
    @staticmethod
    def get_species_with_analysis_type_folder(analysis_type, ftp_path):
        validator.analysis_type_is_valid(analysis_type)
        validator.is_dir(ftp_path)

        data_files_path = ftp_path / DATA_FILES_PATH

        reg_species = defaultdict(set)

        for root, dirs, _ in walk(data_files_path):
            for species in SPECIES_TO_NOT_INCLUDE:
                if species in dirs:
                    dirs.remove(species)
            if analysis_type in dirs:
                root = Path(root)
                if root.parent.name == "funcgen":
                    assembly = root.parent.parent.name
                    species = root.parent.parent.parent.name

                    reg_species[species].add(assembly)
        return reg_species

    @staticmethod
    def get_most_recent_release_data_file_path(data_file_path):
        validator.is_dir(Path(data_file_path))
        available_releases = listdir(data_file_path)
        releases = []
        for release in available_releases:
            try:
                releases.append(int(release))
            except:
                continue

        return Path(data_file_path) / str(
            max(releases)
        )


utils = Utils()


class RegulationSymlinkFTP:
    RELEASE_PATH_ALIASES = {
        "bGalGal1.mat.broiler.GRCg7b": "GRCg7b",
        "gallus_gallus_gca000002315v5": "gallus_gallus",
    }

    def __init__(self, **path_specifics):
        self.path_specifics = path_specifics
        self.target = Path(
            utils.get_most_recent_release_data_file_path(
                DATA_FILES_PATH_TEMPLATE.format(**path_specifics)
            )
        )
        self.sources = {
            "release_folder": Path(
                RELEASE_FOLDER_PATH_TEMPLATE.format(
                    **self.aliased_paths(**path_specifics)
                )
            ),
            "misc_folder": Path(
                MISC_GENE_SWITCH_PATH_TEMPLATE.format(
                    **self.aliased_paths(**path_specifics)
                )
            ),
        }

        validator.analysis_type_is_valid(self.get("analysis_type"))
        validator.is_dir(self.target)
        validator.is_dir(self.sources["release_folder"])

    def get(self, key):
        return self.path_specifics.get(key)

    def symlink2rf(self, analysis_type, only_remove=False, relative=True):
        target = (
            Path(path.relpath(self.target, self.sources["release_folder"]))
            / analysis_type
            if relative
            else self.target / analysis_type
        )
        source = self.sources["release_folder"] / self.get("analysis_type")

        self._symlink(source, target, only_remove)

    def symlink2misc(self, analysis_type, only_remove=False, relative=True):
        if self.get("species") not in GENE_SWITCH_SPECIES:
            return None, None

        if not validator.is_dir(self.sources["misc_folder"], check=True):
            makedirs(self.sources["misc_folder"])

        target = (
            Path(path.relpath(self.target, self.sources["misc_folder"]))
            / analysis_type
            if relative
            else self.target / analysis_type
        )
        source = self.sources["misc_folder"] / self.get("analysis_type")

        self._symlink(source, target, only_remove)

    def _symlink(self, source, target, only_remove):
        if validator.is_symlink(source, check=True):
            source.unlink()

        if not only_remove:
            source.symlink_to(target, target_is_directory=True)
            if validator.is_symlink(source, check=True):
                logger.info(
                    f"{source} -> {target} --- was successfully created"
                )
        else:
            if not validator.is_symlink(source, check=True):
                logger.info(
                    f"{source} -> {target} -- was successfully removed"
                )

    def aliased_paths(self, **kwargs):
        return {
            key: self.RELEASE_PATH_ALIASES.get(value, value)
            for key, value in kwargs.items()
        }

    @staticmethod
    def search(analysis_type, ftp_path, release):
        result = utils.get_species_with_analysis_type_folder(
            analysis_type, ftp_path
        )
        return [
            RegulationSymlinkFTP(
                analysis_type=analysis_type,
                species=species,
                assembly=assembly,
                ftp_path=ftp_path,
                release=release,
            )
            for species, assemblies in result.items()
            for assembly in assemblies if assembly not in ["GRCh37", "GRCm38", "NCBIM37"]
        ]


def parse_arguments():
    """
    --ftp_path: (Required) Path to the root FTP directory.
    --release_version: Release version
    --delete_symlinks
    """

    parser = ArgumentParser(description="Arguments")

    required_args = parser.add_argument_group("Required arguments")

    required_args.add_argument(
        "-f",
        "--ftp_path",
        type=Path,
        help="FTP root path",
        required=True,
    )

    required_args.add_argument(
        "-r",
        "--release_version",
        type=int,
        help="Release version",
        required=True,
    )

    parser.add_argument(
        "-d",
        "--delete_symlinks",
        help="Delete symlinks",
        action="store_true",
        required=False,
    )

    args = parser.parse_args()
    validator.is_dir(args.ftp_path)

    return args


if __name__ == "__main__":
    logger.info("Script started ...")

    args = parse_arguments()
    ftp_path = args.ftp_path / PUBLIC_PUB_PATH

    logger.info("Searching for peaks in data_files ...")
    peaks = RegulationSymlinkFTP.search(
        ANALYSIS_TYPE_PEAKS, ftp_path, args.release_version
    )
    for peak in peaks:
        peak.symlink2rf("peaks", only_remove=args.delete_symlinks)
        peak.symlink2misc("peaks", only_remove=args.delete_symlinks)

    logger.info("Searching for signals in data_files ...")
    signals = RegulationSymlinkFTP.search(
        ANALYSIS_TYPE_SIGNAL, ftp_path, args.release_version
    )
    for signal in signals:
        signal.symlink2rf("signal", only_remove=args.delete_symlinks)
        signal.symlink2misc("signal", only_remove=args.delete_symlinks)

    logger.info("Process Completed")
