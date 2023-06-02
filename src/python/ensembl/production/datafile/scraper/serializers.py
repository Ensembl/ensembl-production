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
"""Serializers for DataFile Scraper"""

from pathlib import Path
from typing import Optional, Tuple

from .utils import get_metadata_from_db, ManifestRow

import re

def metadata_from_manifest(manifest_row: ManifestRow, manifest_dir: Path):
    data = manifest_row._asdict()
    data["file_dir"] = str(manifest_dir)
    return data


def metadata_from_db(
    metadata_db_url: str, species: str, ens_release: int
) -> Tuple[Optional[dict], Optional[str]]:
    ens_metadatas, err = get_metadata_from_db(metadata_db_url, species, ens_release)
    if err:
        return None, err
    data = ens_metadatas[0]._asdict()
    data["release_date"] = data["release_date"].isoformat()
    return data, None

def metadata_from_filename(file_name: str, file_path: str, release: int):
    file_suffixes = Path(file_name).suffixes
    path_array = file_path.split("/")

    # Get file extension
    if len(file_suffixes) == 0:
        return None, None, None
    valid_extensions = ["gff3", "gtf", "fa", "bam", "dat"]

    # Try last extension, if not valid then try next to last (in case of compression)
    ext = file_suffixes[-1]
    ext = ext[1:]
    if len(file_suffixes) > 1 and ext not in valid_extensions:
      ext = file_suffixes[-2]
      ext = ext[1:]
    if ext not in valid_extensions:
      return None, None, None

    # Get file format
    format = ext
    if ext == "fa":
      format = "fasta"
    elif ext == "bam":
      format = "bamcov"
    elif ext == "dat":
      if "embl" in path_array:
        format = "embl"
      elif "genbank" in path_array:
        format = "genbank"

    content_type = ''
    if format != "bamcov":
      filenames_regex = re.compile(
        (
          r"^(?P<species>\w+)\.(?P<assembly>[\w\-\.]+?)\.(?P<release>(5|1)\d{1,2})\."
          r"(?P<content_type>abinitio|chr|chr_patch_hapl_scaff|nonchromosomal|(chromosome|plasmid|scaffold)\.[\w\-\.]+?|primary_assembly[\w\-\.]*?|(chromosome_)?group\.\w+?)?.*?"
        )
      )
      if format == "fasta":
        filenames_regex = re.compile(
            (
                r"^(?P<species>\w+)\.(?P<assembly>[\w\-\.]+?)\.(?P<sequence_type>dna(_sm|_rm)?|cdna|cds|pep|ncrna)\."
                r"(?P<content_type>abinitio|all|alt|toplevel|nonchromosomal|(chromosome|plasmid|scaffold)\.[\w\-\.]+?|primary_assembly[\w\-\.]*?|(chromosome_)?group\.\w+?)?.*?"
            )
        )

      match = filenames_regex.match(file_name)
      species = match.group("species")
      content_type = match.group("content_type")
      if not release and format != "fasta":
        release = match.group("release")
    else:
      species = path_array[-2]

    if content_type:
      content_type = '{"content_type":"'+content_type+'"}'

    return format, species.lower(), content_type
