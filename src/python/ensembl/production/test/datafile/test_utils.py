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

import hashlib
from io import StringIO
import re

import pytest
from unittest.mock import patch, mock_open

from ensembl.production.hive.datafile.utils import (
    blake2bsum,
    get_group,
    make_release,
    manifest_rows,
    clean_name,
)


def test_blake2bsum():
    test_file_content = "test file content"
    encoded_test_file = bytes(test_file_content, "utf-8")
    b2bh = hashlib.blake2b()
    b2bh.update(encoded_test_file)
    expected_hash = b2bh.digest()
    with patch("builtins.open", mock_open(read_data=encoded_test_file)):
        actual_hash = blake2bsum("/test/path")
    assert actual_hash == expected_hash


def test_get_group():
    match = re.match(r"^(?P<test_group>\w+)_not_this", "capture_this_not_this")
    assert get_group("test_group", match) == "capture_this"
    assert get_group("non_group", match) == None
    assert get_group("test_group", None) == None
    assert get_group("non_group", match, "def_value") == "def_value"
    assert get_group("non_group", None, "def_value") == "def_value"


def test_make_release():
    ens_version = 104
    eg_version = 51
    assert make_release(ens_version) == (ens_version, eg_version)


def test_manifest_rows():
    test_manifest = (
        "file_format\tspecies\tens_release\tfile_name\textras\n"
        'fasta\thomo_sapiens\t104\tmy_file.fa\t{"assembly": "ASM123"}\n'
    )
    file = StringIO(test_manifest, newline="")
    rows = list(manifest_rows(file))
    assert len(rows) == 1
    row = rows[0]
    assert row.file_format == "fasta"
    assert row.species == "homo_sapiens"
    assert row.ens_release == 104
    assert row.file_name == "my_file.fa"
    assert row.extras["assembly"] == "ASM123"


def test_manifest_rows_raises():
    test_manifest = (
        "file_format\tens_release\tfile_name\textras\n"
        'fasta\t104\tmy_file.fa\t{"assembly": "ASM123"}\n'
    )
    file = StringIO(test_manifest, newline="")
    with pytest.raises(ValueError):
        list(manifest_rows(file))


def test_clean_name():
    weird_name = "I'm NoT WeIrd "
    assert clean_name(weird_name) == "i'm not weird"
