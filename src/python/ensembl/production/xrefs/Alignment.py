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

"""Alignment module to map xref sequences into ensEMBL ones."""

import re
import shlex
import subprocess
from sqlalchemy.dialects.mysql import insert

from ensembl.xrefs.xref_update_db_model import (
    MappingJobs as MappingJobsORM,
    Mapping as MappingORM,
)

from ensembl.production.xrefs.Base import Base

class Alignment(Base):
    XREF_HIT_PATTERN = re.compile(r"^xref")

    def run(self):
        method: str = self.get_param("align_method", {"required": True, "type": str})
        query_cutoff: int = self.get_param("query_cutoff", {"required": True, "type": int})
        target_cutoff: int = self.get_param("target_cutoff", {"required": True, "type": int})
        max_chunks: int = self.get_param("max_chunks", {"required": True, "type": int})
        chunk: int = self.get_param("chunk", {"required": True, "type": int})
        job_index: int = self.get_param("job_index", {"required": True, "type": int})
        source: str = self.get_param("source_file", {"required": True, "type": str})
        target: str = self.get_param("target_file", {"required": True, "type": str})
        xref_db_url: str = self.get_param("xref_db_url", {"required": True, "type": str})
        map_file: str = self.get_param("map_file", {"required": True, "type": str})
        source_id: int = self.get_param("source_id", {"required": True, "type": int})
        seq_type: str = self.get_param("seq_type", {"required": True, "type": str})

        # Construct Exonerate command
        ryo = "xref:%qi:%ti:%ei:%ql:%tl:%qab:%qae:%tab:%tae:%C:%s\n"
        exe = subprocess.check_output(["which", "exonerate"]).decode("utf-8").strip()
        command_string = f"{exe} --showalignment FALSE --showvulgar FALSE --ryo '{ryo}' --gappedextension FALSE --model 'affine:local' {method} --subopt no --query {source} --target {target} --querychunktotal {max_chunks} --querychunkid {chunk}"
        command_list = shlex.split(command_string)

        # Get exonerate hits
        output = subprocess.run(command_list, capture_output=True, text=True)

        exit_code = abs(output.returncode)
        if exit_code == 0:
            hits = output.stdout.split("\n")

            # Write to mapping file
            with open(map_file, "w") as map_fh:
                for hit in hits:
                    if self.XREF_HIT_PATTERN.search(hit):
                        map_fh.write(f"{hit}\n")
        elif exit_code == 9:
            raise MemoryError(
                f"Exonerate failed due to insufficient memory (exit code: {exit_code})"
            )
        elif exit_code == 256:
            raise SyntaxError(
                f"Exonerate failed due to unexpected character(s) in files (exit code: {exit_code})"
            )
        else:
            raise Exception(f"Exonerate failed with exit_code: {output.returncode}")

        # Add job and mapping data into db
        db_engine = self.get_db_engine(xref_db_url)
        with db_engine.connect() as xref_dbi:
            out_file = f"xref_{seq_type}.{max_chunks}-{chunk}.out"
            job_id = f"{source_id}{job_index}{chunk}"
            xref_dbi.execute(
                insert(MappingJobsORM).values(
                    map_file=map_file,
                    status="SUBMITTED",
                    out_file=out_file,
                    err_file=out_file,
                    array_number=chunk,
                    job_id=job_id,
                )
            )
            xref_dbi.execute(
                insert(MappingORM).values(
                    job_id=job_id,
                    method=seq_type,
                    percent_query_cutoff=query_cutoff,
                    percent_target_cutoff=target_cutoff,
                )
            )
