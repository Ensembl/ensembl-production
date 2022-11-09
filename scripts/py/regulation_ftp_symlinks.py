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
import logging
import shutil
import sys

#***** New (species, assemblies) should be added here ************************

# MISC_SPECIES_PEAKS = [(<species_name>, <assembly_name>), (...)]
MISC_SPECIES_PEAKS = [("sus_scrofa", "Sscrofa11.1"), ("gallus_gallus", "GRCg7b"), ("gallus_gallus", "GRCg6a")]

# MISC_SPECIES_SIGNAL = [(<source_species_name>, <source_assembly_name>,
#                           <target_species_name>, <target_assembly_name>), (...)]
MISC_SPECIES_SIGNAL = [("sus_scrofa", "Sscrofa11.1", "sus_scrofa", "Sscrofa11.1"),
                       ("gallus_gallus", "bGalGal1.mat.broiler.GRCg7b", "gallus_gallus", "GRCg7b"),
                       ("gallus_gallus_gca000002315v5", "GRCg6a", "gallus_gallus", "GRCg6a")]

#*******************************************************************************


# Paths
PUBLIC_PUB_PATH = "PUBLIC/pub"
PUBLIC_DATA_FILES_PATH = "data_files"
MISC_GENE_SWITCH_PATH = "misc/gene-switch/regulation"


#Logging
logging.basicConfig(format="%(message)s")
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# Exceptions
class FtpError(Exception):
    """Base class for the regulation_ftp_symlinks script exceptions"""
    pass

class PathNotFound(FtpError):
    """Raised when path is not found"""
    pass

class NoReleaseFound(FtpError):
    """Raised when release path is not found"""
    pass

class UnableToDeleteSymlink(FtpError):
    """Raised when delete symlink fails"""
    pass

class UnableToCreateSymlink(FtpError):
    """Raised when create symlink fails"""
    pass

class ReleaseVersionNotMatch(FtpError):
    """Raised when FTP release version doesn't match the DB release version"""
    pass


def parse_arguments():
    """
    --ftp_path: (Required) Path to the root FTP directory.
    --release_version: Release version
    --delete_symlinks
    """

    parser = argparse.ArgumentParser(description='Arguments')
    required_args = parser.add_argument_group('Required arguments')
    exclusive_args = parser.add_mutually_exclusive_group(required=True)
    required_args.add_argument('-f', '--ftp_path', metavar='FTP path', type=str, help='FTP root path ...',
                               required=True)
    exclusive_args.add_argument('-r', '--release_version', metavar='Release version', type=int,
                                help='Release version ...')
    exclusive_args.add_argument('-d', '--delete_symlinks', help='Delete symlinks', action='store_true')

    return parser.parse_args()


def check_path(path):
    if not os.path.isdir(path):
        raise PathNotFound("Path Not Found: %s" % path)

    return path


def get_highest_release_directory(base_path, current_release):
    release_dirs = next(os.walk(base_path))[1]
    release_dirs = [int(i) for i in release_dirs if int(i) <= current_release]
    if not release_dirs:
        raise NoReleaseFound("Highest release path not found")

    return max(release_dirs)


def get_highest_ensembl_release_directory(base_path, current_release):
    dirs = next(os.walk(base_path))[1]
    release_dirs = [i for i in dirs if i.startswith('release-')]
    if not release_dirs:
        raise NoReleaseFound("Ensembl release path not found")

    highest_release_number = 0
    for rel_dir in release_dirs:
        release_number = int(re.findall(r'\d+', rel_dir)[0])
        if (release_number > highest_release_number) and (release_number <= int(current_release)):
            highest_release_number = release_number
    if highest_release_number == 0:
        raise NoReleaseFound("Highest Ensembl release path not found")

    return highest_release_number


def misc_signal_symlinks(species, ftp_root_path, assembly, public_path, data_files_path, gene_switch_path,
                         target_species, target_assembly, release_version):
    symlink_paths = {}
    base_path = os.path.join(ftp_root_path, public_path)
    partial_target_signal_path = os.path.join(base_path, gene_switch_path, target_species, target_assembly)
    funcgen_signal_path = check_path(os.path.join(base_path, data_files_path, species, assembly, "funcgen"))
    highest_release = get_highest_release_directory(funcgen_signal_path, release_version)
    src_signal_path = check_path(os.path.join(funcgen_signal_path, str(highest_release), "signal"))
    src_signal_relative_path = os.path.relpath(src_signal_path, partial_target_signal_path)
    target_signal_path = os.path.join(partial_target_signal_path, 'signal')
    symlink_paths['source'] = src_signal_relative_path
    symlink_paths['target'] = target_signal_path

    return symlink_paths


def misc_peaks_symlinks(species, ftp_root_path, assembly, public_path, gene_switch_path, release_version):
    symlink_paths = {}
    base_path = check_path(os.path.join(ftp_root_path, public_path))
    highest_release_dir_number = get_highest_ensembl_release_directory(base_path, release_version)
    if highest_release_dir_number == release_version:
        partial_target_peaks_path = os.path.join(base_path, gene_switch_path, species, assembly)
        release_dir = "release-" + str(highest_release_dir_number)
        src_peaks_path = check_path(os.path.join(base_path, release_dir, "regulation", species, assembly, "peaks"))
        src_peaks_relative_path = os.path.relpath(src_peaks_path, partial_target_peaks_path)
        target_peaks_path = os.path.join(partial_target_peaks_path, 'peaks')

        symlink_paths['source'] = src_peaks_relative_path
        symlink_paths['target'] = target_peaks_path

    else:
        raise ReleaseVersionNotMatch("Database release version is '%s' but highest Ensembl release directory is '%s'"
                         % (release_version, str(highest_release_dir_number)))

    return symlink_paths


def check_symlink(target, created_message=True, source=""):
    ret = False
    if os.path.exists(target):
        if os.path.islink(target):
            if created_message:
                logger.info("%s -> %s --- Was successfully created" % (target, source))
            ret = True

    return ret


def delete_symlink(symlink):
    try:
        if check_symlink(symlink, False):
            os.unlink(symlink)

        return
    except OSError:
        raise UnableToDeleteSymlink("Error deleting symlink: %s" % symlink)


def create_symlinks(symlinks):
    separator = '/'
    for symlink_data in symlinks:
        target_splitted_path = symlink_data['target'].split(separator)
        target_splitted_path.pop()

        target_parent_path = separator.join(target_splitted_path)

        # remove symlink if already exists
        delete_symlink(symlink_data['target'])

        # create path if doesn't exists
        if not os.path.exists(target_parent_path):
            os.makedirs(target_parent_path)

        try:
            # create symlink
            os.symlink(src=symlink_data['source'], dst=symlink_data['target'], target_is_directory=True)
            check_symlink(symlink_data['target'], True, symlink_data['source'])
        except OSError:
            raise UnableToCreateSymlink("Error creating symlink: %s -> %s" % (symlink_data['source'],
                                                                              symlink_data['target'] ))
    return

def signal_symlinks(ftp_root_path, release_version):
    signal_symlinks_to_create = []
    for species_assembly in MISC_SPECIES_SIGNAL:
        source_species_name = species_assembly[0]
        source_assembly_name = species_assembly[1]
        target_species_name = species_assembly[2]
        target_assembly_name = species_assembly[3]
        misc_signal = misc_signal_symlinks(species=source_species_name, ftp_root_path=ftp_root_path,
                                           assembly=source_assembly_name, public_path=PUBLIC_PUB_PATH,
                                           data_files_path=PUBLIC_DATA_FILES_PATH,
                                           gene_switch_path=MISC_GENE_SWITCH_PATH, target_species=target_species_name,
                                           target_assembly=target_assembly_name, release_version=release_version)
        if misc_signal:
            signal_symlinks_to_create.append(misc_signal)

    return signal_symlinks_to_create

def peaks_symlink(ftp_root_path, release_version):
    peak_symlinks_to_create = []
    for species_assembly in MISC_SPECIES_PEAKS:
        species_name = species_assembly[0]
        assembly_name = species_assembly[1]
        misc_peaks = misc_peaks_symlinks(species=species_name, ftp_root_path=ftp_root_path,
                                         assembly=assembly_name,
                                         public_path=PUBLIC_PUB_PATH,
                                         gene_switch_path=MISC_GENE_SWITCH_PATH,
                                         release_version=release_version)
        if misc_peaks:
            peak_symlinks_to_create.append(misc_peaks)

    return peak_symlinks_to_create

def delete_all_symlinks(root_ftp_path):
    path_to_delete = check_path(os.path.join(root_ftp_path, PUBLIC_PUB_PATH, MISC_GENE_SWITCH_PATH))
    if path_to_delete:
        confirmation = input("Do you want to delete %s (Yes/No) (default=No)? " % path_to_delete)
        if confirmation.upper() == "Y" or confirmation.upper() == "YES":
            try:
                shutil.rmtree(path_to_delete)
                print("%s was successfully deleted." % path_to_delete)
            except OSError as e:
                print("Error: %s : %s" % (path_to_delete, e.strerror))
        else:
            print("No changes will be done to %s" % path_to_delete)

    return


if __name__ == '__main__':
    logger.info("Script started ...")

    args = parse_arguments()
    ftp_path = check_path(args.ftp_path)
    if args.delete_symlinks:
        delete_all_symlinks(args.ftp_path)
    else:
        sig_symlinks = signal_symlinks(ftp_path, args.release_version)
        pea_symlinks = peaks_symlink(ftp_path, args.release_version)
        symlinks_to_create = sig_symlinks + pea_symlinks
        create_symlinks(symlinks_to_create)

    logger.info("Process Completed")
