#  See the NOTICE file distributed with this work for additional information
#  regarding copyright ownership.
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

from datetime import datetime
import hashlib
from time import time
import re

import pytest
from unittest.mock import patch, mock_open

from ensembl.production.hive.datafile.parsers import (
    Result,
    FileMetadata,
    Assembly,
    Release,
    FileURL,
    Species,
    EMBLOptMetadata,
    EMBLFileParser,
    FASTAFileParser,
    BAMFileParser
)


def test_embl_file_parser():
    embl_file_content = "test content"
    encoded_embl_file = bytes(embl_file_content, "utf-8")
    modified_time = time()
    file_size = 3363872
    b2b = hashlib.blake2b()
    b2b.update(encoded_embl_file)
    b2bsum = b2b.hexdigest()
    metadata = {
        "file_dir": "/FTP/PUBLIC/release-100/gtf/acanthochromis_polyacanthus",
        "file_name": "Acanthochromis_polyacanthus.ASM210954v1.100.abinitio.gtf.gz",
        "file_format": "gtf",
        "species": "acanthochromis_polyacanthus",
        "ens_release": 100,
        "release_date": datetime(2020, 4, 29).astimezone().isoformat(),
        "division": "EnsemblVertebrates",
        "genome_id": 882535,
        "taxon_id": 80966,
        "species_taxon_id": 80966,
        "assembly_default": "ASM210954v1",
        "assembly_accession": "GCA_002109545.1"
    }
    config = {
        "ftp_dir_ens": "/FTP/PUBLIC",
        "ftp_dir_eg": "/ENSGEN/FTP",
        "ftp_url_ens":"ftp://ensembl.ftp",
        "ftp_url_eg": "ftp://ensemblgenomes.ftp",
    }
    file_path = f"{metadata['file_dir']}/{metadata['file_name']}"
    expected_result = Result(
        file_metadata=FileMetadata(
            file_path=file_path,
            file_set_id=None,
            file_format=metadata["file_format"],
            release=Release(
                ens=metadata["ens_release"],
                eg=metadata["ens_release"] - 53,
                date=metadata["release_date"]
            ),
            assembly=Assembly(
                default='ASM210954v1',
                accession='GCA_002109545.1',
                provider_name='',
                genome_id=metadata["genome_id"]
            ),
            file_size=file_size,
            file_last_modified=datetime.fromtimestamp(modified_time).astimezone().isoformat(),
            blake2bsum=b2bsum,
            urls=[
                FileURL(
                    url=re.sub(config["ftp_dir_ens"], config["ftp_url_ens"], file_path),
                    headers={})
            ],
            species=Species(
                production_name=metadata["species"],
                division=metadata["division"],
                taxon_id=metadata["taxon_id"],
                species_taxon_id=metadata["species_taxon_id"],
                classifications=[metadata["division"]]
            ),
            optional_data=EMBLOptMetadata(
                file_extension='gtf',
                compression='gzip',
                content_type='abinitio',
                sorting=None
            )
        ),
        errors=[]
    )
    patch_open = patch("builtins.open", mock_open(read_data=encoded_embl_file))
    patch_stat = patch("pathlib.Path.stat")
    parser = EMBLFileParser(**config)
    with patch_open, patch_stat as patched_stat:
        patched_stat.return_value.st_mtime = modified_time
        patched_stat.return_value.st_size = file_size
        result = parser.parse_metadata(metadata)
    assert result == expected_result