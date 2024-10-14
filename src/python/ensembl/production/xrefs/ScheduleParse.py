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

from ensembl.production.xrefs.Base import *


class ScheduleParse(Base):
    def run(self):
        species_name     = self.param_required("species_name", {"type": "str"})
        release          = self.param_required("release", {"type": "int"})
        registry         = self.param_required("registry_url", {"type": "str"})
        order_priority   = self.param_required("priority", {"type": "int"})
        source_db_url    = self.param_required("source_db_url", {"type": "str"})
        xref_db_url      = self.param_required("xref_db_url", {"type": "str"})
        get_species_file = self.param_required("get_species_file", {"type": "bool"})
        core_db_url      = self.param("species_db", None, {"type": "str"})

        logging.info(f"ScheduleParse starting for species '{species_name}'")
        logging.info(f"\tParam: order_priority = {order_priority}")
        logging.info(f"\tParam: source_db_url = {source_db_url}")
        logging.info(f"\tParam: xref_db_url = {xref_db_url}")
        logging.info(f"\tParams: core_db_url = {core_db_url}")

        dataflow_suffix, dataflow_sub_suffix = "", ""

        # Create Xref database only at priority 1 (one time)
        if order_priority == 1:
            sources_config_file = self.param_required("sources_config_file")
            logging.info(f"\tParam: sources_config_file = {sources_config_file}")

            # Construct xref update url
            xref_db_url = make_url(xref_db_url)
            xref_db_url = xref_db_url.set(
                database=f"{species_name}_xref_update_{release}"
            )
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
            core_db_url = "mysql://" + core_db_url

        # Get species and division ids
        db_engine = self.get_db_engine(core_db_url)
        with db_engine.connect() as core_dbi:
            species_id = self.get_taxon_id(core_dbi)
            division_id = self.get_division_id(core_dbi)

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

            if source.db == "checksum":
                continue
            if source.priority != order_priority:
                continue

            dataflow_params = {
                "species_name": species_name,
                "species_id": species_id,
                "core_db_url": core_db_url,
                "xref_db_url": xref_db_url,
            }

            # Use clean files if available
            file_name = source.file_path
            if source.clean_path:
                file_name = source.clean_path

            # Some sources are species-specific
            source_id = self.get_source_id(
                xref_dbi, source.parser, species_id, source.name, division_id
            )
            if not source_id:
                continue

            dataflow_params["source_id"] = source_id
            dataflow_params["source_name"] = source.name
            dataflow_params["parser"] = source.parser
            if source.revision:
                dataflow_params["release_file"] = source.revision

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
                if os.path.isdir(file_name):
                    list_files = os.listdir(file_name)
                    list_files = [os.path.join(file_name, f) for f in list_files]
                else:
                    list_files = [file_name]

                # For Uniprot and Refseq, files might have been split by species
                if get_species_file:
                    match source.name:
                        case "Uniprot/SWISSPROT":
                            file_prefix = "uniprot_sprot"
                        case "Uniprot/SPTREMBL":
                            file_prefix = "uniprot_trembl"
                        case "RefSeq_dna":
                            file_prefix = "refseq_rna"
                        case "RefSeq_peptide":
                            file_prefix = "refseq_protein"
                        case _:
                            file_prefix = None

                    if file_prefix:
                        list_files = glob.glob(
                            file_name + "/**/" + file_prefix + "-" + str(species_id),
                            recursive=True,
                        )

                if source.name == "ZFIN_ID":
                    list_files = [list_files[0]]

                for file in list_files:
                    if source.revision and file == source.revision:
                        continue

                    dataflow_params["file_name"] = file

                    if re.search(r"^Uniprot", source.name):
                        hgnc_files = glob.glob(hgnc_path + "/*")
                        dataflow_params["hgnc_file"] = hgnc_files[0]

                    self.write_output(dataflow_suffix, dataflow_params)
                    total_sources += 1

        xref_dbi.close()

        if total_sources == 0:
            with open(f"dataflow_{dataflow_suffix}.json", "a") as fh:
                fh.write("")

        dataflow_params = {
            "species_name": species_name,
            "species_db": core_db_url,
            "xref_db_url": xref_db_url,
        }
        self.write_output(dataflow_sub_suffix, dataflow_params)
