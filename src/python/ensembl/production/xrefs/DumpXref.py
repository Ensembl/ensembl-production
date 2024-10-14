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

"""Dumping module to dump xref sequence data from an xref intermediate db."""

from ensembl.production.xrefs.Base import *

from Bio import SeqIO
from Bio.Seq import Seq
from Bio.SeqRecord import SeqRecord


class DumpXref(Base):
    def run(self):
        species_name = self.param_required("species_name", {"type": "str"})
        base_path    = self.param_required("base_path", {"type": "str"})
        release      = self.param_required("release", {"type": "int"})
        xref_db_url  = self.param_required("xref_db_url", {"type": "str"})
        file_path    = self.param_required("file_path", {"type": "str"})
        seq_type     = self.param_required("seq_type", {"type": "str"})
        config_file  = self.param_required("config_file", {"type": "str"})

        logging.info(
            f"DumpXref starting for species '{species_name}' with file_path '{file_path}' and seq_type '{seq_type}'"
        )

        # Connect to xref db
        xref_dbi = self.get_dbi(xref_db_url)

        # Create output path
        full_path = self.get_path(base_path, species_name, release, "xref")

        # Extract sources to download from config file
        sources = []
        with open(config_file) as conf_file:
            sources = json.load(conf_file)

        # Create hash of available alignment methods
        method = {}
        query_cutoff = {}
        target_cutoff = {}
        for source in sources:
            if source.get("method"):
                method[source["name"]] = source["method"]
                query_cutoff[source["name"]] = source.get("query_cutoff")
                target_cutoff[source["name"]] = source.get("target_cutoff")

        job_index = 1

        # Get sources related to sequence type
        source_query = select(SourceUORM.name.distinct(), SourceUORM.source_id).where(
            SourceUORM.source_id == XrefUORM.source_id,
            XrefUORM.xref_id == PrimaryXrefORM.xref_id,
            PrimaryXrefORM.sequence_type == seq_type,
        )
        for source in xref_dbi.execute(source_query).mappings().all():
            source_name = source.name
            source_id = source.source_id

            if re.search(r"RefSeq_.*RNA", source_name):
                source_name = "RefSeq_dna"
            if re.search("RefSeq_peptide", source_name):
                source_name = "RefSeq_peptide"

            if method.get(source_name):
                method_name = method[source_name]
                source_query_cutoff = query_cutoff[source_name]
                source_target_cutoff = target_cutoff[source_name]

                # Open fasta file
                file_source_name = source.name
                file_source_name = re.sub(r"\/", "", file_source_name)
                filename = os.path.join(
                    full_path, f"{seq_type}_{file_source_name}_{source_id}.fasta"
                )
                fasta_fh = open(filename, "w")

                # Get xref sequences
                sequence_query = select(
                    PrimaryXrefORM.xref_id, PrimaryXrefORM.sequence
                ).where(
                    XrefUORM.xref_id == PrimaryXrefORM.xref_id,
                    PrimaryXrefORM.sequence_type == seq_type,
                    XrefUORM.source_id == source_id,
                )
                for sequence in xref_dbi.execute(sequence_query).mappings().all():
                    # Ambiguous peptides must be cleaned out to protect Exonerate from J,O and U codes
                    seq = sequence.sequence.upper()
                    if seq_type == "peptide":
                        seq = re.sub(r"(J|O|U)", "X", seq)

                    # Print sequence
                    SeqIO.write(
                        SeqRecord(Seq(seq), id=str(sequence.xref_id), description=""),
                        fasta_fh,
                        "fasta",
                    )

                fasta_fh.close()

                # Pass data into alignment jobs
                self.write_output(
                    "schedule_alignment",
                    {
                        "species_name": species_name,
                        "ensembl_fasta": file_path,
                        "seq_type": seq_type,
                        "xref_db_url": xref_db_url,
                        "method": method_name,
                        "query_cutoff": source_query_cutoff,
                        "target_cutoff": source_target_cutoff,
                        "job_index": job_index,
                        "source_id": source_id,
                        "source_name": source_name,
                        "xref_fasta": filename,
                    },
                )
                job_index += 1

        xref_dbi.close()

        if job_index == 1:
            with open("dataflow_schedule_alignment.json", "a") as fh:
                fh.write("")
