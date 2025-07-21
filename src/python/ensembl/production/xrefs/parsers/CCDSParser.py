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

import logging
from sqlalchemy import select
from sqlalchemy.engine import URL
from typing import Dict, Any, Tuple, List

from ensembl.core.models import (
    Transcript as TranscriptORM,
    Xref as XrefCORM,
    ExternalDb as ExternalDbORM,
    ObjectXref as ObjectXrefCORM,
)

from ensembl.production.xrefs.parsers.BaseParser import BaseParser

class CCDSParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id = args.get("source_id")
        species_id = args.get("species_id")
        xref_file = args.get("file", "")
        db_url = args.get("extra_db_url")
        xref_dbi = args.get("xref_dbi")
        verbose = args.get("verbose", False)

        if not source_id or not species_id:
            raise AttributeError("Missing required arguments: source_id and species_id")

        # Extract db connection parameters from file
        db_user = "ensro"
        db_host, db_port, db_name, db_pass = self.extract_params_from_string(
            xref_file, ["host", "port", "dbname", "pass"]
        )
        db_port = db_port or "3306"

        # Connect to the appropriate db
        ccds_db_url = None
        if db_host:
            ccds_db_url = URL.create(
                "mysql", db_user, db_pass, db_host, db_port, db_name
            )
        elif db_url:
            ccds_db_url = db_url

        if not ccds_db_url:
            return 1, "Could not find CCDS DB."
        if verbose:
            logging.info(f"Found CCDS DB: {ccds_db_url}")

        # Get data from ccds db
        ccds_data = self.get_ccds_data(ccds_db_url)

        xref_count, direct_count = 0, 0
        seen = {}

        for row in ccds_data:
            stable_id = row.stable_id
            display_label = row.dbprimary_acc

            if "." in display_label:
                acc, version = display_label.split(".")
            else:
                acc, version = display_label, None

            if display_label not in seen:
                xref_args = {
                    "accession": acc,
                    "label": display_label,
                    "source_id": source_id,
                    "species_id": species_id,
                    "info_type": "DIRECT",
                }
                if version is not None:
                    args["version"] = version

                xref_id = self.add_xref(xref_args, xref_dbi)
                xref_count += 1
                seen[display_label] = xref_id
            else:
                xref_id = seen[display_label]

            self.add_direct_xref(xref_id, stable_id, "Transcript", "", xref_dbi)
            direct_count += 1

        result_message = f"Parsed CCDS identifiers, added {xref_count} xrefs and {direct_count} direct_xrefs"

        return 0, result_message

    def get_ccds_data(self, ccds_db_url: str) -> List[Dict[str, Any]]:
        db_engine = self.get_db_engine(ccds_db_url)
        with db_engine.connect() as ccds_dbi:
            query = (
                select(TranscriptORM.stable_id, XrefCORM.dbprimary_acc)
                .join(ObjectXrefCORM, XrefCORM.xref_id == ObjectXrefCORM.xref_id)
                .join(TranscriptORM, ObjectXrefCORM.ensembl_id == TranscriptORM.transcript_id)
                .join(ExternalDbORM, ExternalDbORM.external_db_id == XrefCORM.external_db_id)
                .where(
                    ObjectXrefCORM.ensembl_object_type == "Transcript",
                    ExternalDbORM.db_name.like("Ens_%_transcript")
                )
            )
            result = ccds_dbi.execute(query).mappings().all()

        return result