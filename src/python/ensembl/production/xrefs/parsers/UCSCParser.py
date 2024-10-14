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

from ensembl.production.xrefs.parsers.BaseParser import *


class UCSCParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args["source_id"]
        species_id = args["species_id"]
        file       = args["file"]
        xref_dbi   = args["xref_dbi"]

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        count = 0

        file_io = self.get_filehandle(file)
        csv_reader = csv.reader(file_io, delimiter="\t", strict=True)

        # Read lines
        for line in csv_reader:
            chromosome = line[1]
            strand = line[2]
            tx_start = int(line[3])
            tx_end = int(line[4])
            cds_start = int(line[5])
            cds_end = int(line[6])
            exon_starts = line[8]
            exon_ends = line[9]
            accession = line[11]

            # UCSC uses slightly different chromosome names, at least for
            # human and mouse, so chop off the 'chr' in the beginning.  We do
            # not yet translate the names of the special chromosomes, e.g.
            # "chr6_cox_hap1" (UCSC) into "c6_COX" (Ensembl)
            chromosome = re.sub(r"\Achr", "", chromosome)

            # They also use '+' and '-' for the strand, instead of -1, 0, or 1
            if strand == "+":
                strand = 1
            elif strand == "-":
                strand = -1
            else:
                strand = 0

            # ... and non-coding transcripts have cds_start == cds_end.
            # We would like these to be stored as NULLs
            if cds_start == cds_end:
                cds_start = None
                cds_end = None

            # exon_starts and exon_ends usually have trailing commas, remove them
            exon_starts = re.sub(r",\Z", "", exon_starts)
            exon_ends = re.sub(r",\Z", "", exon_ends)

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
                str(int(x) + 1) for x in re.split(r"\s*,\s*", exon_starts)
            )

            self.add_xref(
                source_id,
                species_id,
                {
                    "accession": accession,
                    "chromosome": chromosome,
                    "strand": strand,
                    "txStart": tx_start,
                    "txEnd": tx_end,
                    "cdsStart": cds_start,
                    "cdsEnd": cds_end,
                    "exonStarts": exon_starts,
                    "exonEnds": exon_ends,
                },
                xref_dbi,
            )
            count += 1

        file_io.close()

        result_message = f"Loaded a total of {count} UCSC xrefs"

        return 0, result_message

    def add_xref(self, source_id: int, species_id: int, xref: Dict[str, Any], dbi: Connection) -> None:
        for required_key in [
            "accession",
            "chromosome",
            "strand",
            "txStart",
            "txEnd",
            "exonStarts",
            "exonEnds",
        ]:
            if not xref.get(required_key):
                raise KeyError(f"Missing required key {required_key} for Xref")

        query = insert(CoordinateXrefORM).values(
            source_id=source_id,
            species_id=species_id,
            accession=xref["accession"],
            chromosome=xref["chromosome"],
            strand=xref["strand"],
            txStart=xref["txStart"],
            txEnd=xref["txEnd"],
            cdsStart=xref["cdsStart"],
            cdsEnd=xref["cdsEnd"],
            exonStarts=xref["exonStarts"],
            exonEnds=xref["exonEnds"],
        )
        dbi.execute(query)
