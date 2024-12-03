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

"""Mapper module for processing coordinate xref data."""

import subprocess
import logging
from datetime import datetime
from sqlalchemy import select, func, update, insert

from ensembl.core.models import (
    ObjectXref as ObjectXrefCORM,
    Xref as XrefCORM,
    UnmappedObject as UnmappedObjectORM,
    UnmappedReason as UnmappedReasonORM,
    Analysis as AnalysisORM
)

from ensembl.production.xrefs.mappers.BasicMapper import BasicMapper

coding_weight = 2
ens_weight = 3
transcript_score_threshold = 0.75

class CoordinateMapper(BasicMapper):
    def __init__(self, mapper: BasicMapper) -> None:
        self.xref(mapper.xref())
        self.core(mapper.core())
        self.species_dir(mapper.species_dir())
        mapper.set_up_logging()

    def run_coordinatemapping(self, species_name: str, species_id: int, scripts_dir: str) -> None:
        self.update_process_status("coordinate_xrefs_started")

        # We only do coordinate mapping for mouse and human for now
        if species_name not in ["mus_musculus", "homo_sapiens"]:
            self.update_process_status("coordinate_xref_finished")
            return

        output_dir = self.species_dir()

        with self.xref().connect() as xref_dbi, self.core().connect() as core_dbi:
            # Figure out the last used IDs in the core DB
            xref_id = core_dbi.execute(select(func.max(XrefCORM.xref_id))).scalar()
            object_xref_id = core_dbi.execute(select(func.max(ObjectXrefCORM.object_xref_id))).scalar()
            unmapped_object_id = core_dbi.execute(select(func.max(UnmappedObjectORM.unmapped_object_id))).scalar()
            unmapped_reason_id = core_dbi.execute(select(func.max(UnmappedReasonORM.unmapped_reason_id))).scalar()

            logging.info(
                f"Last used xref_id={xref_id}, object_xref_id={object_xref_id}, unmapped_object_id={unmapped_object_id}, unmapped_reason_id={unmapped_reason_id}"
            )

            # Get an analysis ID
            analysis_params = f"weights(coding,ensembl)={coding_weight:.2f},{ens_weight:.2f};transcript_score_threshold={transcript_score_threshold:.2f}"
            analysis_id = core_dbi.execute(
                select(AnalysisORM.analysis_id).where(
                    AnalysisORM.logic_name == "xrefcoordinatemapping",
                    AnalysisORM.parameters == analysis_params,
                )
            ).scalar()

            if not analysis_id:
                analysis_id = core_dbi.execute(
                    select(AnalysisORM.analysis_id).where(
                        AnalysisORM.logic_name == "xrefcoordinatemapping"
                    )
                ).scalar()

                if analysis_id:
                    logging.info("Will update 'analysis' table with new parameter settings")

                    # Update an existing analysis
                    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    core_dbi.execute(
                        update(AnalysisORM)
                        .where(AnalysisORM.analysis_id == analysis_id)
                        .values(created=now, parameters=analysis_params)
                    )
                else:
                    logging.info(
                        f"Cannot find analysis ID for this analysis: logic_name = 'xrefcoordinatemapping' parameters = {analysis_params}"
                    )

                    # Store a new analysis
                    logging.info("A new analysis will be added")

                    analysis_id = core_dbi.execute(select(func.max(AnalysisORM.analysis_id))).scalar()
                    logging.info(f"Last used analysis_id is {analysis_id}")

                    analysis_id += 1
                    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    core_dbi.execute(
                        insert(AnalysisORM).values(
                            analysis_id=analysis_id,
                            created=now,
                            logic_name="xrefcoordinatemapping",
                            program="CoordinateMapper.pm",
                            parameters=analysis_params,
                            module="CoordinateMapper.pm",
                        )
                    )

            if analysis_id:
                logging.info(f"Analysis ID is {analysis_id}")

            logging.info(f"Running perl script {scripts_dir}/coordinate_mapper.pl")
            perl_cmd = [
                "perl",
                f"{scripts_dir}/coordinate_mapper.pl",
                "--xref_db_url", str(self.xref()),
                "--core_db_url", str(self.core()),
                "--species_id", str(species_id),
                "--output_dir", output_dir,
                "--analysis_id", str(analysis_id)
            ]
            subprocess.run(perl_cmd, capture_output=True, text=True, check=True)

            self.update_process_status("coordinate_xref_finished")

            self.biomart_fix("UCSC", "Translation", "Gene", xref_dbi)
            self.biomart_fix("UCSC", "Transcript", "Gene", xref_dbi)
