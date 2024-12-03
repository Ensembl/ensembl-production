#  See the NOTICE file distributed with this work for additional information
#  regarding copyright ownership.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

"""Scheduling module to create xref/ensEMBL alignment jobs."""

import logging
import os
from typing import Optional

from ensembl.production.xrefs.Base import Base

class ScheduleAlignment(Base):
    def run(self):
        species_name: str = self.get_param("species_name", {"required": True, "type": str})
        release: int = self.get_param("release", {"required": True, "type": int})
        target_file: str = self.get_param("ensembl_fasta", {"required": True, "type": str})
        source_file: str = self.get_param("xref_fasta", {"required": True, "type": str})
        seq_type: str = self.get_param("seq_type", {"required": True, "type": str})
        xref_db_url: str = self.get_param("xref_db_url", {"required": True, "type": str})
        base_path: str = self.get_param("base_path", {"required": True, "type": str})
        method: str = self.get_param("method", {"required": True, "type": str})
        query_cutoff: int = self.get_param("query_cutoff", {"required": True, "type": int})
        target_cutoff: int = self.get_param("target_cutoff", {"required": True, "type": int})
        source_id: int = self.get_param("source_id", {"required": True, "type": int})
        source_name: str = self.get_param("source_name", {"required": True, "type": str})
        job_index: int = self.get_param("job_index", {"required": True, "type": int})
        chunk_size: Optional[int] = self.get_param("chunk_size", {"type": int, "default": 1000000})

        logging.info(
            f"ScheduleAlignment starting for species '{species_name}' with seq_type '{seq_type}' and job_index '{job_index}'"
        )

        # Inspect file size to decide on chunking
        size = os.stat(target_file).st_size
        chunks = int(size / chunk_size) + 1

        # Create output path
        output_path = self.get_path(base_path, species_name, release, "alignment")

        # Pass alignment data for each chunk
        chunklet = 1
        for chunklet in range(1, chunks + 1):
            output_path_chunk = os.path.join(
                output_path,
                f"{seq_type}_alignment_{source_id}_{chunklet}_of_{chunks}.map",
            )
            self.write_output(
                "alignment",
                {
                    "species_name": species_name,
                    "align_method": method,
                    "query_cutoff": query_cutoff,
                    "target_cutoff": target_cutoff,
                    "max_chunks": chunks,
                    "chunk": chunklet,
                    "job_index": job_index,
                    "source_file": source_file,
                    "target_file": target_file,
                    "xref_db_url": xref_db_url,
                    "map_file": output_path_chunk,
                    "source_id": source_id,
                    "source_name": source_name,
                    "seq_type": seq_type,
                },
            )
