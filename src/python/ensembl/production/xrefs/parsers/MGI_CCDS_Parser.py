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

"""Parser module for MGI CCDS source."""

from ensembl.production.xrefs.parsers.BaseParser import *


class MGI_CCDS_Parser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args["source_id"]
        species_id = args["species_id"]
        file       = args["file"]
        xref_dbi   = args["xref_dbi"]

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        source_ids = []
        labels = {}
        versions = {}
        descriptions = {}
        accessions = {}

        query = select(SourceUORM.source_id).filter(SourceUORM.name.like("MGI"))
        result = xref_dbi.execute(query).fetchall()
        for row in result:
            source_ids.append(row[0])

        query = select(
            XrefUORM.accession, XrefUORM.label, XrefUORM.version, XrefUORM.description
        ).filter(XrefUORM.source_id.in_(source_ids))

        for row in xref_dbi.execute(query).mappings().all():
            if row["description"]:
                accessions[row["label"]] = row.accession
                labels[row["accession"]] = row.label
                versions[row["accession"]] = row.version
                descriptions[row["accession"]] = row.description

        # Get master xref ids via the ccds label
        ccds_label_to_xref_id = {}
        query = select(XrefUORM.label, XrefUORM.xref_id).where(
            XrefUORM.source_id == SourceUORM.source_id, SourceUORM.name == "CCDS"
        )
        result = xref_dbi.execute(query).fetchall()
        for row in result:
            ccds_label_to_xref_id[row[0]] = row[1]

        count = 0
        ccds_missing = 0
        mgi_missing = 0

        mgi_io = self.get_filehandle(file)
        for line in mgi_io:
            line = line.rstrip()
            if not line:
                continue

            fields = line.split("\t")
            chromosome = fields[0]
            g_accession = fields[1]
            gene_name = fields[2]
            entrez_id = fields[3]
            ccds = fields[4]

            if ccds_label_to_xref_id.get(ccds):
                if accessions.get(gene_name) and labels.get(accessions[gene_name]):
                    accession = accessions[gene_name]
                    self.add_dependent_xref(
                        {
                            "master_xref_id": ccds_label_to_xref_id[ccds],
                            "accession": accession,
                            "version": versions[accession],
                            "label": labels[accession],
                            "description": descriptions[accession],
                            "source_id": source_id,
                            "species_id": species_id,
                        },
                        xref_dbi,
                    )

                    count += 1
                else:
                    mgi_missing += 1
            else:
                ccds_missing += 1

        mgi_io.close()

        result_message = f"Added {count} MGI xrefs via CCDS\n"
        result_message += (
            f"{ccds_missing} CCDS not resolved, {mgi_missing} MGI not found"
        )

        return 0, result_message
