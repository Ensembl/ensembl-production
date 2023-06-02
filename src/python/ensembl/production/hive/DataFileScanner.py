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
"""Scanner module for DataFile Scanner pipeline. Walks through the directories and creates the manifest files."""

from pathlib import Path

import eHive
import os

from .BaseProdRunnable import BaseProdRunnable
from ..datafile.scraper.serializers import metadata_from_filename

class DataFileScanner(BaseProdRunnable):
  def run(self):
    root_dir = self.param("root_dir")
    release = self.param("release")
    overwrite = self.param("overwrite")
    
    # Get release
    if not release:
      root_dir_array = root_dir.split("/")
      for root_dir_piece in root_dir_array:
        if root_dir_piece.startswith("release-"):
          release = root_dir_piece.split("-")[1]
    if not release:
      self.warning(f"Warning: Could not retrieve release number from "+root_dir)

    # Traverse recursively through the root directory
    root_dir = Path(root_dir).resolve()
    for root, dirs, files in os.walk(root_dir):
      manifest_lines = []
      known_format_found = 0

      if "MANIFEST" in files and not overwrite:
        continue

      for file in files:
        # Get the file metadata
        format, species, extras = metadata_from_filename(file, root, release)
        if not format:
          continue
        known_format_found = 1

        file_metadata = {"file_format": format, "species": species, "ens_release": release, "file_name": file,"extras": extras}
        manifest_lines.append(file_metadata)

      # Write to manifest file
      if known_format_found:
        fh = open(Path(root, "MANIFEST"), "a")
        fh.write("file_format\tspecies\tens_release\tfile_name\textras")
        for line in manifest_lines:
          fh.write(line["file_format"]+"\t"+line["species"]+"\t"+line["ens_release"]+"\t"+line["file_name"])
          if line["extras"]:
            fh.write("\t"+line["extras"])
          fh.write("\n")
        fh.close()

