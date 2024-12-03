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

"""Scheduling module to create parsing jobs for each xref source."""

import glob
import logging
import os
import re
from sqlalchemy import select
from sqlalchemy.engine.url import make_url
from typing import Tuple, Optional

from ensembl.xrefs.xref_source_db_model import (
    Source as SourceSORM,
    Version as VersionORM,
)

from ensembl.production.xrefs.Base import Base

class ScheduleParse(Base):
    def run(self):
        species_name: str = self.get_param("species_name", {"required": True, "type": str})
        release: int = self.get_param("release", {"required": True, "type": int})
        registry: str = self.get_param("registry_url", {"required": True, "type": str})
        order_priority: int = self.get_param("priority", {"required": True, "type": int})
        source_db_url: str = self.get_param("source_db_url", {"required": True, "type": str})
        xref_db_url: str = self.get_param("xref_db_url", {"required": True, "type": str})
        get_species_file: bool = self.get_param("get_species_file", {"required": True, "type": bool})
        core_db_url: Optional[str] = self.get_param("species_db", {"type": str})

        logging.info(f"ScheduleParse starting for species '{species_name}'")
        logging.info(f"\tParam: order_priority = {order_priority}")
        logging.info(f"\tParam: source_db_url = {source_db_url}")
        logging.info(f"\tParam: xref_db_url = {xref_db_url}")
        logging.info(f"\tParams: core_db_url = {core_db_url}")

        dataflow_suffix, dataflow_sub_suffix = "", ""

        # Create Xref database only at priority 1 (one time)
        if order_priority == 1:
            sources_config_file: str = self.get_param("sources_config_file", {"required": True, "type": str})
            logging.info(f"\tParam: sources_config_file = {sources_config_file}")

            # Construct xref update db name, truncating if necessary
            max_length = 64
            original_species_name = species_name
            xref_db_name = f"{species_name}_xref_update_{release}"
            if len(xref_db_name) > max_length:
                # Try to shorten the name by replacing "_collection" with "_col"
                if species_name.endswith("_collection"):
                    species_name = species_name.replace("_collection", "_col")
                    xref_db_name = f"{species_name}_xref_update_{release}"

                # If still too long, truncate the _xref_update_ part
                if len(xref_db_name) > max_length:
                    xref_db_name = f"{species_name}_xup_{release}"

                # If still too long, raise an error
                if len(xref_db_name) > max_length:
                    raise ValueError(f"Could not sufficiently reduce DB name for species {species_name}")
            species_name = original_species_name

            # Construct xref update url
            xref_db_url = make_url(xref_db_url).set(database=xref_db_name)
            self.create_xref_db(xref_db_url, sources_config_file)
            xref_db_url = xref_db_url.render_as_string(hide_password=False)

            dataflow_suffix = "primary_sources"
            dataflow_sub_suffix = "schedule_secondary"
        elif order_priority == 2:
            dataflow_suffix = "secondary_sources"
            dataflow_sub_suffix = "schedule_tertiary"
        elif order_priority == 3:
            dataflow_suffix = "tertiary_sources"
            dataflow_sub_suffix = "dump_ensembl"
        else:
            raise AttributeError("Parameter 'priority' can only be of value 1, 2, or 3")

        # Get core db from registry if not provided
        if not core_db_url:
            core_db_url = self.get_db_from_registry(
                species_name, "core", release, registry
            )
        if not re.search(r"^mysql://", core_db_url):
            core_db_url = f"mysql://{core_db_url}"

        # Get species and division ids
        species_id, division_id = self.get_core_db_info(core_db_url)

        # Retrieve list of sources from source database
        db_engine = self.get_db_engine(source_db_url)
        with db_engine.connect() as source_dbi:
            query = (
                select(
                    SourceSORM.name.distinct(),
                    SourceSORM.parser,
                    VersionORM.file_path,
                    VersionORM.clean_path,
                    VersionORM.db,
                    VersionORM.priority,
                    VersionORM.revision,
                )
                .where(SourceSORM.source_id == VersionORM.source_id)
                .order_by(SourceSORM.name)
            )
            sources = source_dbi.execute(query).mappings().all()

        # Connect to the xref intermediate db
        xref_dbi = self.get_dbi(xref_db_url)

        hgnc_path = None
        total_sources = 0

        for source in sources:
            if source.name == "HGNC":
                hgnc_path = source.file_path

            if source.db == "checksum" or source.priority != order_priority:
                continue

            dataflow_params = {
                "species_name": species_name,
                "species_id": species_id,
                "core_db_url": core_db_url,
                "xref_db_url": xref_db_url,
            }

            # Use clean files if available
            file_name = source.clean_path or source.file_path

            # Some sources are species-specific
            source_id = self.get_source_id(
                xref_dbi, source.parser, species_id, source.name, division_id
            )
            if not source_id:
                continue

            dataflow_params.update({
                "source_id": source_id,
                "source_name": source.name,
                "parser": source.parser,
                "release_file": source.revision if source.revision else None,
            })

            # Some sources need a connection to a special database
            if source.db:
                dataflow_params["db"] = source.db

                if source.db != "core":
                    db_url = self.get_db_from_registry(
                        species_name, source.db, release, registry
                    )
                    if not db_url:
                        # Not all species have an otherfeatures database
                        if source.db == "otherfeatures":
                            continue
                        else:
                            raise LookupError(
                                f"Cannot use {source.parser} for {species_name}, no {source.db} database"
                            )
                    else:
                        dataflow_params[f"{source.db}_db_url"] = db_url

            logging.info(
                f"Parser '{source.parser}' for source '{source.name}' scheduled for species '{species_name}'"
            )

            if file_name == "Database":
                dataflow_params["file_name"] = file_name
                self.write_output(dataflow_suffix, dataflow_params)
                total_sources += 1
            else:
                # Get list of files if directory
                list_files = (
                    [os.path.join(file_name, f) for f in os.listdir(file_name)]
                    if os.path.isdir(file_name)
                    else [file_name]
                )

                # For Uniprot and Refseq, files might have been split by species
                if get_species_file:
                    file_prefix = {
                        "Uniprot/SWISSPROT": "uniprot_sprot",
                        "Uniprot/SPTREMBL": "uniprot_trembl",
                        "RefSeq_dna": "refseq_rna",
                        "RefSeq_peptide": "refseq_protein",
                    }.get(source.name)

                    if file_prefix:
                        list_files = glob.glob(
                            f"{file_name}/**/{file_prefix}-{species_id}", recursive=True
                        )

                if source.name == "ZFIN_ID":
                    list_files = [list_files[0]]

                for file in list_files:
                    if source.revision and file == source.revision:
                        continue

                    dataflow_params["file_name"] = file

                    if re.search(r"^Uniprot", source.name) and hgnc_path:
                        
                        hgnc_files = glob.glob(hgnc_path + "/*")
                        dataflow_params["hgnc_file"] = hgnc_files[0]

                    self.write_output(dataflow_suffix, dataflow_params)
                    total_sources += 1

        xref_dbi.close()

        if total_sources == 0:
            self.write_output(dataflow_suffix, {})

        dataflow_params = {
            "species_name": species_name,
            "species_db": core_db_url,
            "xref_db_url": xref_db_url,
        }
        self.write_output(dataflow_sub_suffix, dataflow_params)

    def get_core_db_info(self, core_db_url: str) -> Tuple[int, int]:
        db_engine = self.get_db_engine(core_db_url)
        with db_engine.connect() as core_dbi:
            species_id = self.get_taxon_id(core_dbi)
            division_id = self.get_division_id(core_dbi)

        return species_id, division_id
