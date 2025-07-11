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

"""Parser module for UCSC source."""

import csv
import re
from typing import Any, Dict, Tuple
from sqlalchemy.sql import insert
from sqlalchemy.engine import Connection

from ensembl.xrefs.xref_update_db_model import CoordinateXref as CoordinateXrefORM

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class UCSCParser(BaseParser):
    CHROMOSOME_PATTERN = re.compile(r"\Achr")
    EXON_PATTERN = re.compile(r",\Z")
    EXON_SPLIT_PATTERN = re.compile(r"\s*,\s*")

    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file")
        xref_dbi = args.get("xref_dbi")

        if not source_id or not species_id or not xref_file:
            raise AttributeError("Missing required arguments: source_id, species_id, and file")

        with self.get_filehandle(xref_file) as file_io:
            if file_io.read(1) == '':
                raise IOError(f"UCSC file is empty")
            file_io.seek(0)

            csv_reader = csv.reader(file_io, delimiter="\t", strict=True)

            count = self.process_lines(csv_reader, source_id, species_id, xref_dbi)

        result_message = f"Loaded a total of {count} UCSC xrefs"
        return 0, result_message

    def process_lines(self, csv_reader: csv.reader, source_id: int, species_id: int, xref_dbi: Connection) -> int:
        count = 0

        # Read lines
        for line in csv_reader:
            try:
                chromosome = line[1].strip()
                strand = line[2].strip()
                exon_starts = line[8].strip()
                exon_ends = line[9].strip()
                accession = line[11].strip()

                tx_start = int(line[3]) if line[3].strip() else None
                tx_end = int(line[4]) if line[4].strip() else None
                cds_start = int(line[5]) if line[5].strip() else None
                cds_end = int(line[6]) if line[6].strip() else None

                # Check for required keys
                if not accession or not chromosome or not strand or tx_start is None or tx_end is None or not exon_starts or not exon_ends:
                    raise ValueError("Missing required key for xref")
            except (IndexError, ValueError) as e:
                raise ValueError(f"Error processing line {line}: {e}")

            # UCSC uses slightly different chromosome names, at least for
            # human and mouse, so chop off the 'chr' in the beginning.  We do
            # not yet translate the names of the special chromosomes, e.g.
            # "chr6_cox_hap1" (UCSC) into "c6_COX" (Ensembl)
            chromosome = self.CHROMOSOME_PATTERN.sub("", chromosome)

            # They also use '+' and '-' for the strand, instead of -1, 0, or 1
            strand = 1 if strand == "+" else -1 if strand == "-" else 0

            # ... and non-coding transcripts have cds_start == cds_end.
            # We would like these to be stored as NULLs
            if cds_start == cds_end:
                cds_start = None
                cds_end = None

            # exon_starts and exon_ends usually have trailing commas, remove them
            exon_starts = self.EXON_PATTERN.sub("", exon_starts)
            exon_ends = self.EXON_PATTERN.sub("", exon_ends)

            # ... and they use the same kind of "inbetween" coordinates as e.g.
            # exonerate, so increment all start coordinates by one
            tx_start += 1
            if cds_start:
                cds_start += 1

            # The string exon_starts is a comma-separated list of start coordinates
            # for subsequent exons and we must increment each one. Split the string
            # on commas, use map() to apply the "+1" transformation to every
            # element of the resulting array, then join the result into a new
            # comma-separated list
            exon_starts = ",".join(
                str(int(x) + 1) for x in self.EXON_SPLIT_PATTERN.split(exon_starts)
            )

            # Add coordinate xref
            query = insert(CoordinateXrefORM).values(
                source_id=source_id,
                species_id=species_id,
                accession=accession,
                chromosome=chromosome,
                strand=strand,
                txStart=tx_start,
                txEnd=tx_end,
                cdsStart=cds_start,
                cdsEnd=cds_end,
                exonStarts=exon_starts,
                exonEnds=exon_ends,
            )
            xref_dbi.execute(query)
            count += 1

        return count