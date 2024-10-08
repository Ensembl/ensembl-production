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

"""
Compresses gff with bgzip and stores them to a modified VEP location
"""

import logging
import os
from pathlib import Path

import eHive


class GFFbgzip(eHive.BaseRunnable):
    def run(self):
        output_filename = self.param_required("output_filename")

        # Split the path into parts and find the index of "organisms"
        path_parts = Path(output_filename).parts
        try:
            org_index = path_parts.index("organisms")
        except ValueError:
            raise ValueError(f"'organisms' not found in the path: {output_filename}")

        # Construct the new bgzip path by inserting 'vep' directory right after "organisms" subpath
        new_parts = list(path_parts[:org_index + 3]) + ["vep"] + list(path_parts[org_index + 3:])
        new_parts[-1] = new_parts[-1] + ".bgz"
        bgzip_filename = str(Path(*new_parts))

        # Create the target directory if it does not exist
        bgzip_directory = Path(bgzip_filename).parent
        bgzip_directory.mkdir(parents=True, exist_ok=True)

        # Compress the file and index it using bgzip and tabix
        os.system(f"sort -k1,1 -k4,4n -k5,5n -t$\'\\t\' {output_filename} | bgzip -c > {bgzip_filename}")
        os.system(f"tabix -p gff -C {bgzip_filename}")

        output_location = str(Path(*path_parts[org_index + 1:]))

        # Log the output paths for debugging purposes
        logging.info(f"Original file: {output_filename}")
        logging.info(f"Compressed file: {bgzip_filename}")
        logging.info(f"Output location: {output_location}")

        # Construct the attribute_dict parameter
        attribute_dict = {"vep.gff_location": output_location}

        # Pass it on
        self.dataflow({'attribute_dict': attribute_dict}, 2)
