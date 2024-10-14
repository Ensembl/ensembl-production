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

from ensembl.production.xrefs.Base import *


class ScheduleAlignment(Base):
    def run(self):
        species_name  = self.param_required("species_name", {"type": "str"})
        release       = self.param_required("release", {"type": "int"})
        target_file   = self.param_required("ensembl_fasta", {"type": "str"})
        source_file   = self.param_required("xref_fasta", {"type": "str"})
        seq_type      = self.param_required("seq_type", {"type": "str"})
        xref_db_url   = self.param_required("xref_db_url", {"type": "str"})
        base_path     = self.param_required("base_path", {"type": "str"})
        method        = self.param_required("method", {"type": "str"})
        query_cutoff  = self.param_required("query_cutoff", {"type": "int"})
        target_cutoff = self.param_required("target_cutoff", {"type": "int"})
        source_id     = self.param_required("source_id", {"type": "int"})
        source_name   = self.param_required("source_name", {"type": "str"})
        job_index     = self.param_required("job_index", {"type": "int"})

        logging.info(
            f"ScheduleAlignment starting for species '{species_name}' with seq_type '{seq_type}' and job_index '{job_index}'"
        )

        # Inspect file size to decide on chunking
        size = os.stat(target_file).st_size
        chunks = int(size / 1000000) + 1

        # Create output path
        output_path = self.get_path(base_path, species_name, release, "alignment")

        # Pass alignment data for each chunk
        chunklet = 1
        while chunklet <= chunks:
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
            chunklet += 1
