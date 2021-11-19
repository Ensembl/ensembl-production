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
    FASTAOptMetadata,
    BAMOptMetadata,
    EMBLFileParser,
    FASTAFileParser,
    BAMFileParser
)


CONFIG = {
    "ftp_dir_ens": "/FTP/PUBLIC",
    "ftp_dir_eg": "/ENSGEN/FTP",
    "ftp_url_ens":"ftp://ensembl.ftp",
    "ftp_url_eg": "ftp://ensemblgenomes.ftp",
}


PARSER_TEST_CASES = [
    (
        {
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
        },
        EMBLOptMetadata(
            file_extension='gtf',
            compression='gzip',
            content_type='abinitio',
            sorting=None
        ),
        EMBLFileParser
    ),
    (
        {
            "file_dir": "/FTP/PUBLIC/release-100/fasta/accipiter_nisus/dna",
            "file_name": "Accipiter_nisus.Accipiter_nisus_ver1.0.dna.nonchromosomal.fa.gz",
            "file_format": "fasta",
            "species": "accipiter_nisus",
            "ens_release": 100,
            "release_date": datetime(2020, 4, 29).astimezone().isoformat(),
            "division": "EnsemblVertebrates",
            "genome_id": 882524,
            "taxon_id": 211598,
            "species_taxon_id": 211598,
            "assembly_default": "Accipiter_nisus_ver1.0",
            "assembly_accession": "GCA_004320145.1"
        },
        FASTAOptMetadata(
            compression='gzip',
            file_extension='fa',
            content_type='nonchromosomal',
            sequence_type="dna",
        ),
        FASTAFileParser
    ),
    (
        {
            "file_dir": "/FTP/PUBLIC/release-100/bamcov/amazona_collaria/genebuild",
            "file_name": "ASM394721v1.ENA.blood.1.bam.bw",
            "file_format": "bamcov",
            "species": "amazona_collaria",
            "ens_release": 100,
            "release_date": datetime(2020, 4, 29).astimezone().isoformat(),
            "division": "EnsemblVertebrates",
            "genome_id": 882524,
            "taxon_id": 241587,
            "species_taxon_id": 211598,
            "assembly_default": "ASM394721v1",
            "assembly_accession": "GCA_003947215.1"
        },
        BAMOptMetadata(
            file_extension='bam.bw',
            origin='blood',
            source="ENA",
        ),
        BAMFileParser
    ),
]

@pytest.mark.parametrize("metadata,opt_data,file_parser_cls", PARSER_TEST_CASES)
def test_file_parser(metadata, opt_data, file_parser_cls):
    file_content = "test content"
    encoded_file = bytes(file_content, "utf-8")
    b2b = hashlib.blake2b()
    b2b.update(encoded_file)
    b2bsum = b2b.hexdigest()
    modified_time = time()
    file_size = 3363872
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
                default=metadata["assembly_default"],
                accession=metadata["assembly_accession"],
                provider_name='',
                genome_id=metadata["genome_id"]
            ),
            file_size=file_size,
            file_last_modified=datetime.fromtimestamp(modified_time).astimezone().isoformat(),
            blake2bsum=b2bsum,
            urls=[
                FileURL(
                    url=re.sub(CONFIG["ftp_dir_ens"], CONFIG["ftp_url_ens"], file_path),
                    headers={})
            ],
            species=Species(
                production_name=metadata["species"],
                division=metadata["division"],
                taxon_id=metadata["taxon_id"],
                species_taxon_id=metadata["species_taxon_id"],
                classifications=[metadata["division"]]
            ),
            optional_data=opt_data
        ),
        errors=[]
    )
    patch_open = patch("builtins.open", mock_open(read_data=encoded_file))
    patch_stat = patch("pathlib.Path.stat")
    parser = file_parser_cls(**CONFIG)
    with patch_open, patch_stat as patched_stat:
        patched_stat.return_value.st_mtime = modified_time
        patched_stat.return_value.st_size = file_size
        result = parser.parse_metadata(metadata)
    assert result == expected_result
