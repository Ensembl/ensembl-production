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
import pymysql
import re
import sys

MISC_SPECIES = ["sus_scrofa"] #New species should be added here
META_KEY_SPECIES_NAME = "species.production_name"
META_KEY_RELEASE_VERSION = "schema_version"
META_KEY_ASSEMBLY_NAME = 'assembly.name'
PUBLIC_PUB_PATH = "PUBLIC/pub"
PUBLIC_DATA_FILES_PATH = "data_files"
MISC_GENE_SWITCH_PATH = "misc/gene-switch/regulation"


def parse_arguments():
    """
    All Arguments are required.
    --ftp_path: Path to the root FTP directory.
    --db_host: Url to the server where the db is hosted.
    --db_name: Name of the funcgen Database.
    --user: Database user with read permissions.
    --port: Database server port.
    """

    parser = argparse.ArgumentParser(description='Arguments')
    required_args = parser.add_argument_group('Required arguments')
    required_args.add_argument('-f', '--ftp_path', metavar='FTP path', type=str, help='FTP root path ...',
                               required=True)
    required_args.add_argument('-d', '--db_host', metavar='DB host', type=str, help='Database host ...',
                               required=True)
    required_args.add_argument('-n', '--db_name', metavar='DB name', type=str, help='Database name ...',
                               required=True)
    required_args.add_argument('-u', '--user', metavar='DB user', type=str, help='Database user ...',
                               required=True)
    required_args.add_argument('-p', '--port', metavar='Port', type=int, help='Database port ...',
                               required=True)

    return parser.parse_args()


def check_paths(arguments):
    if not os.path.isdir(arguments.ftp_path):
        raise ValueError("Fatal Error: FTP path Not Found")

    return


def db_connection(db_name, host, user, port):
    try:
        connection = pymysql.connect(host=host, user=user, db=db_name, port=port)

        return connection

    except Exception as e:
        raise ValueError("Can't connect to the Core database: {}".format(e))


def get_meta_data(cursor, keys, data):
    try:
        param_holders = ', '.join(("%s",) * len(keys))
        query = "select meta_key, meta_value from meta where meta_key in (%s);" % param_holders
        cursor.execute(query, keys)
        meta = cursor.fetchall()

        for row in meta:
            data[row[0]] = row[1]

        return data

    except Exception as e:
        raise ValueError("Exception: {}".format(e))


def get_highest_release_directory(base_path):
    try:
        release_dirs = next(os.walk(base_path))[1]
        release_dirs = [int(i) for i in release_dirs]

        return max(release_dirs)

    except Exception as e:
        raise ValueError("Exception: {}".format(e))


def get_highest_ensembl_release_directory(base_path):
    try:
        dirs = next(os.walk(base_path))[1]
        release_dirs = [i for i in dirs if i.startswith('release-')]
        highest_relese_number = 0
        for rel_dir in release_dirs:
            release_number = int(re.findall(r'\d+', rel_dir)[0])
            if release_number > highest_relese_number:
                highest_relese_number = release_number

        return highest_relese_number

    except Exception as e:
        raise ValueError("Exception: {}".format(e))


def misc_signal_symlinks(species, ftp_path, assembly, public_path, data_files_path, gene_switch_path):
    try:
        symlink_paths = {}
        #signal directory
        base_path = os.path.join(ftp_path, public_path, data_files_path, species, assembly, "funcgen")
        highest_release = get_highest_release_directory(base_path)
        src_signal_path = os.path.join(base_path, str(highest_release), "signal")
        misc_signal_path = os.path.join(ftp_path, public_path, gene_switch_path, species, assembly, "signal")

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
        highest_release_dir_number = get_highest_ensembl_release_directory(base_path)
        if str(highest_release_dir_number) == release_version:
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
            # create target path if does not exists
            target_splitted_path = symlink_data['target'].split('/')
            target_splitted_path.pop()
            separator = '/'
            target_parent_path = separator.join(target_splitted_path)

            #remove symlink if already exists
            if os.path.exists(symlink_data['target']):
                if os.path.islink(symlink_data['target']):
                    os.unlink(symlink_data['target'])

            #create path if doesn't exists
            if not os.path.exists(target_parent_path):
                os.makedirs(target_parent_path)

            #create symlink
            os.symlink(src=symlink_data['source'], dst=symlink_data['target'], target_is_directory=True)

        return

    except Exception as e:
        raise ValueError("Exception: {}".format(e))


if __name__ == '__main__':
    #check_arguments and db connectons
    args = parse_arguments()
    check_paths(args)
    funcgen_db = db_connection(args.db_name,args.db_host, args.user, args.port)
    core_db_name = args.db_name.replace("funcgen", "core")
    core_db = db_connection(core_db_name,args.db_host, args.user, args.port)
    funcgen_cursor = funcgen_db.cursor()
    core_cursor = core_db.cursor()

    #get meta_data values from funggen and core dbs
    meta_data = get_meta_data(funcgen_cursor, [META_KEY_SPECIES_NAME, META_KEY_RELEASE_VERSION], {})
    meta_data = get_meta_data(core_cursor, [META_KEY_ASSEMBLY_NAME], meta_data)

    #Only species included in MISC_SPECIES list will be processed.
    if not meta_data[META_KEY_SPECIES_NAME].lower() in MISC_SPECIES:
        sys.exit(1)

    #create symlinks
    symlinks_to_create = []
    misc_signal = misc_signal_symlinks(species=meta_data[META_KEY_SPECIES_NAME], ftp_path=args.ftp_path,
                                       assembly=meta_data[META_KEY_ASSEMBLY_NAME], public_path=PUBLIC_PUB_PATH,
                                       data_files_path=PUBLIC_DATA_FILES_PATH, gene_switch_path=MISC_GENE_SWITCH_PATH)

    if misc_signal:
        symlinks_to_create.append(misc_signal)

    misc_peaks = misc_peaks_symlinks(species=meta_data[META_KEY_SPECIES_NAME], ftp_path=args.ftp_path,
                                     assembly=meta_data[META_KEY_ASSEMBLY_NAME],
                                     public_path=PUBLIC_PUB_PATH,
                                     gene_switch_path=MISC_GENE_SWITCH_PATH,
                                     release_version=meta_data[META_KEY_RELEASE_VERSION])

    if misc_peaks:
        symlinks_to_create.append(misc_peaks)

    create_symlinks(symlinks_to_create)

    funcgen_cursor.close()
    funcgen_db.close()
    core_cursor.close()
    core_db.close()

    print("Symlinks successfully created!")




