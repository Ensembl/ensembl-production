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

from ensembl.production.xrefs.Base import *


class Alignment(Base):
    def run(self):
        base_path     = self.param_required("base_path", {"type": "str"})
        method        = self.param_required("align_method", {"type": "str"})
        query_cutoff  = self.param_required("query_cutoff", {"type": "int"})
        target_cutoff = self.param_required("target_cutoff", {"type": "int"})
        max_chunks    = self.param_required("max_chunks", {"type": "int"})
        chunk         = self.param_required("chunk", {"type": "int"})
        job_index     = self.param_required("job_index", {"type": "int"})
        source        = self.param_required("source_file", {"type": "str"})
        target        = self.param_required("target_file", {"type": "str"})
        xref_db_url   = self.param_required("xref_db_url", {"type": "str"})
        map_file      = self.param_required("map_file", {"type": "str"})
        source_id     = self.param_required("source_id", {"type": "int"})
        seq_type      = self.param_required("seq_type", {"type": "str"})

        # Construct Exonerate command
        ryo = "xref:%qi:%ti:%ei:%ql:%tl:%qab:%qae:%tab:%tae:%C:%s\n"
        exe = (
            subprocess.check_output("which exonerate", shell=True)
            .decode("utf-8")
            .strip()
        )
        command_string = f"{exe} --showalignment FALSE --showvulgar FALSE --ryo '{ryo}' --gappedextension FALSE --model 'affine:local' {method} --subopt no --query {source} --target {target} --querychunktotal {max_chunks} --querychunkid {chunk}"

        # Get exonerate hits
        output = subprocess.run(command_string, shell=True, stdout=subprocess.PIPE)

        exit_code = abs(output.returncode)
        if exit_code == 0:
            hits = output.stdout.decode("utf-8").split("\n")

            # Write to mapping file
            map_fh = open(map_file, "w")
            for hit in hits:
                if re.search(r"^xref", hit):
                    map_fh.write(f"{hit}\n")
            map_fh.close()
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
