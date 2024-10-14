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

"""Parser module for CCDS source."""

from ensembl.production.xrefs.parsers.BaseParser import *


class CCDSParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id  = args["source_id"]
        species_id = args["species_id"]
        file       = args["file"]
        dba        = args["dba"]
        xref_dbi   = args["xref_dbi"]
        verbose    = args.get("verbose", False)

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        # Extract db connection parameters from file
        db_user = "ensro"
        db_host, db_port, db_name, db_pass = self.extract_params_from_string(
            file, ["host", "port", "dbname", "pass"]
        )
        if not db_port:
            db_port = "3306"

        # Connect to the appropriate db
        if db_host:
            ccds_db_url = URL.create(
                "mysql", db_user, db_pass, db_host, db_port, db_name
            )
        elif dba:
            ccds_db_url = dba

        if not ccds_db_url:
            return 1, "Could not find CCDS DB."
        else:
            if verbose:
                logging.info(f"Found CCDS DB: {ccds_db_url}")

        # Get data from ccds db
        db_engine = self.get_db_engine(ccds_db_url)
        with db_engine.connect() as ccds_dbi:
            query = (
                select(TranscriptORM.stable_id, XrefCORM.dbprimary_acc)
                .where(
                    XrefCORM.xref_id == ObjectXrefCORM.xref_id,
                    ObjectXrefCORM.ensembl_object_type == "Transcript",
                    ObjectXrefCORM.ensembl_id == TranscriptORM.transcript_id,
                    ExternalDbORM.external_db_id == XrefCORM.external_db_id,
                )
                .filter(ExternalDbORM.db_name.like("Ens_%_transcript"))
            )
            result = ccds_dbi.execute(query).mappings().all()

        xref_count, direct_count = 0, 0
        seen = {}

        for row in result:
            stable_id = row.stable_id
            display_label = row.dbprimary_acc

            (acc, version) = display_label.split(".")

            if not seen.get(display_label):
                xref_id = self.add_xref(
                    {
                        "accession": acc,
                        "version": version,
                        "label": display_label,
                        "source_id": source_id,
                        "species_id": species_id,
                        "info_type": "DIRECT",
                    },
                    xref_dbi,
                )

                xref_count += 1
                seen[display_label] = xref_id
            else:
                xref_id = seen[display_label]

            self.add_direct_xref(xref_id, stable_id, "Transcript", "", xref_dbi)
            direct_count += 1

        result_message = f"Parsed CCDS identifiers from {file}, added {xref_count} xrefs and {direct_count} direct_xrefs"

        return 0, result_message
