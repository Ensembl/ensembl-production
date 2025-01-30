#!/usr/bin/env python
"""
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
     http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""
import logging
import os
import sys

import yaml
import argparse
import json
from ensembl.production.metadata.api.factories.datasets import DatasetFactory

'''
Update Dataset Status
'''

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)


def main():
    parser = argparse.ArgumentParser(
        prog='update_dataset_status.py',
        description='Update dataset status'
    )

    parser.add_argument('-d', '--dataset_uuid',
                        type=str,
                        required=True,
                        help='unique dataset uuid ')

    parser.add_argument('-s', '--update_status',
                        type=str,
                        required=True,
                        default='Processed',
                        help='Update dataset status')

    parser.add_argument('--metadata_db_uri',
                        type=str,
                        required=True,
                        help='metadata db mysql uri, ex: mysql://ensro@localhost:3366/ensembl_genome_metadata')

    args = parser.parse_args()

    _, status = DatasetFactory(args.metadata_db_uri) \
        .update_dataset_status(args.dataset_uuid,
                               args.update_status,
                               )
    if args.update_status == status.value:
        logger.info(
            f"Updated Dataset status for dataset uuid: {args.dataset_uuid} to {status.value}"
        )

    else:
        sys.exit('f"Cannot update status for dataset uuid: {dataset_uuid} "')


if __name__ == '__main__':
    main()