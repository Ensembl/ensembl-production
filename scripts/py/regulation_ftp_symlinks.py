#!/usr/bin/env python
#
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
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
regulation_ftp_symlinks:
Script to create specific symlinks for GENE-SWITCH project under the public miscellaneous directory
"""

import argparse
import os.path
import re

# ***** New (species, assemblies) should be added here *****

# MISC_SPECIES_PEAKS = [(<species_name>, <assembly_name>), (...)]
MISC_SPECIES_PEAKS = [("sus_scrofa", "Sscrofa11.1"), ("gallus_gallus", "GRCg7b"), ("gallus_gallus", "GRCg6a")]

# MISC_SPECIES_SIGNAL = [(<source_species_name>, <source_assembly_name>,
#                           <target_species_name>, <target_assembly_name>), (...)]
MISC_SPECIES_SIGNAL = [("sus_scrofa", "Sscrofa11.1", "sus_scrofa", "Sscrofa11.1"),
                       ("gallus_gallus", "bGalGal1.mat.broiler.GRCg7b", "gallus_gallus", "GRCg7b"),
                       ("gallus_gallus_gca000002315v5", "GRCg6a", "gallus_gallus", "GRCg6a")]

# Paths
PUBLIC_PUB_PATH = "PUBLIC/pub"
PUBLIC_DATA_FILES_PATH = "data_files"
MISC_GENE_SWITCH_PATH = "misc/gene-switch/regulation"


def parse_arguments():
    """
    All Arguments are required.
    --ftp_path: Path to the root FTP directory.
    --release_version: Release version
    """
    parser = argparse.ArgumentParser(description='Arguments')
    required_args = parser.add_argument_group('Required arguments')
    required_args.add_argument('-f', '--ftp_path', metavar='FTP path', type=str, help='FTP root path ...',
                               required=True)
    required_args.add_argument('-r', '--release_version', metavar='Release version', type=int,
                               help='Release version ...', required=True)

    return parser.parse_args()


def check_ftp_path(ftp_path):
    if not os.path.isdir(ftp_path):
        raise ValueError("Fatal Error: FTP path Not Found")

    return


def get_highest_release_directory(base_path, current_release):
    try:
        release_dirs = next(os.walk(base_path))[1]
        release_dirs = [int(i) for i in release_dirs if int(i) <= current_release]

        return max(release_dirs)

    except Exception as e:
        raise ValueError("Exception: {}".format(e))


def get_highest_ensembl_release_directory(base_path, current_release):
    try:
        dirs = next(os.walk(base_path))[1]
        release_dirs = [i for i in dirs if i.startswith('release-')]
        highest_relese_number = 0
        for rel_dir in release_dirs:
            release_number = int(re.findall(r'\d+', rel_dir)[0])
            if (release_number > highest_relese_number) and (release_number <= int(current_release)):
                highest_relese_number = release_number

        return highest_relese_number

    except Exception as e:
        raise ValueError("Exception: {}".format(e))


def misc_signal_symlinks(species, ftp_path, assembly, public_path, data_files_path, gene_switch_path,
                         target_species, target_assembly, release_version):
    try:
        symlink_paths = {}
        base_path = os.path.join(ftp_path, public_path, data_files_path, species, assembly, "funcgen")
        highest_release = get_highest_release_directory(base_path, release_version)
        src_signal_path = os.path.join(base_path, str(highest_release), "signal")
        misc_signal_path = os.path.join(ftp_path, public_path, gene_switch_path, target_species, target_assembly,
                                        "signal")

        symlink_paths['source'] = src_signal_path
        symlink_paths['target'] = misc_signal_path

        return symlink_paths

    except Exception as e:
        raise ValueError("Exception: {}".format(e))


def misc_peaks_symlinks(species, ftp_path, assembly, public_path, gene_switch_path, release_version):
    try:
        symlink_paths = {}
        # peaks
        base_path = os.path.join(ftp_path, public_path)
        highest_release_dir_number = get_highest_ensembl_release_directory(base_path, release_version)
        if highest_release_dir_number == release_version:
            release_dir = "release-" + str(highest_release_dir_number)
            src_peaks_path = os.path.join(base_path, release_dir, "regulation", species, assembly, "peaks")
            misc_peaks_path = os.path.join(ftp_path, public_path, gene_switch_path, species, assembly, "peaks")

            symlink_paths['source'] = src_peaks_path
            symlink_paths['target'] = misc_peaks_path

            return symlink_paths

        else:
            raise ValueError("Exception: Database release version is '%s' but highest release directory is '%s'"
                             % (release_version, str(highest_release_dir_number)))
    except Exception as e:
        raise ValueError("Exception: {}".format(e))


def create_symlinks(symlinks):
    try:
        for symlink_data in symlinks:
            target_splitted_path = symlink_data['target'].split('/')
            target_splitted_path.pop()
            separator = '/'
            target_parent_path = separator.join(target_splitted_path)

            # remove symlink if already exists
            if os.path.exists(symlink_data['target']):
                if os.path.islink(symlink_data['target']):
                    os.unlink(symlink_data['target'])

            # create path if doesn't exists
            if not os.path.exists(target_parent_path):
                os.makedirs(target_parent_path)

            # create symlink
            os.symlink(src=symlink_data['source'], dst=symlink_data['target'], target_is_directory=True)

        return

    except Exception as e:
        raise ValueError("Exception: {}".format(e))


if __name__ == '__main__':
    # check_arguments and paths
    args = parse_arguments()
    check_ftp_path(args.ftp_path)

    symlinks_to_create = []
    for species_assembly in MISC_SPECIES_SIGNAL:
        species_name = species_assembly[0]
        assembly_name = species_assembly[1]
        t_species_name = species_assembly[2]
        t_assembly_name = species_assembly[3]

        misc_signal = misc_signal_symlinks(species=species_name, ftp_path=args.ftp_path,
                                           assembly=assembly_name, public_path=PUBLIC_PUB_PATH,
                                           data_files_path=PUBLIC_DATA_FILES_PATH,
                                           gene_switch_path=MISC_GENE_SWITCH_PATH, target_species=t_species_name,
                                           target_assembly=t_assembly_name, release_version=args.release_version)

        if misc_signal:
            symlinks_to_create.append(misc_signal)
            create_symlinks(symlinks_to_create)

    symlinks_to_create = []
    for species_assembly in MISC_SPECIES_PEAKS:

        species_name = species_assembly[0]
        assembly_name = species_assembly[1]

        misc_peaks = misc_peaks_symlinks(species=species_name, ftp_path=args.ftp_path,
                                         assembly=assembly_name,
                                         public_path=PUBLIC_PUB_PATH,
                                         gene_switch_path=MISC_GENE_SWITCH_PATH,
                                         release_version=args.release_version)

        if misc_peaks:
            symlinks_to_create.append(misc_peaks)
            create_symlinks(symlinks_to_create)

    print("Symlinks successfully created!")
