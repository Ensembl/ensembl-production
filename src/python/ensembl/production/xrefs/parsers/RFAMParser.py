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

"""Parser module for RFAM source."""

from ensembl.production.xrefs.parsers.BaseParser import *


class RFAMParser(BaseParser):
    def run(self, args: Dict[str, Any]) -> Tuple[int, str]:
        source_id       = args["source_id"]
        species_id      = args["species_id"]
        species_name    = args["species_name"]
        file            = args["file"]
        dba             = args["dba"]
        ensembl_release = args["ensembl_release"]
        xref_dbi        = args["xref_dbi"]
        verbose         = args.get("verbose", False)

        if not source_id or not species_id or not file:
            raise AttributeError("Need to pass source_id, species_id and file as pairs")

        # Extract db connection parameters from file
        wget_url, db_user, db_host, db_port, db_name, db_pass = (
            self.extract_params_from_string(
                file, ["wget", "user", "host", "port", "dbname", "pass"]
            )
        )
        if not db_user:
            db_user = "ensro"
        if not db_port:
            db_port = "3306"

        # Get the species name(s)
        species_id_to_names = self.species_id_to_names(xref_dbi)
        if species_name:
            species_id_to_names.setdefault(species_id, []).append(species_name)

        if not species_id_to_names.get(species_id):
            return 0, "Skipped. Could not find species ID to name mapping"

        species_name = species_id_to_names[species_id][0]

        # Connect to the appropriate rfam db
        if db_host:
            rfam_db_url = URL.create(
                "mysql", db_user, db_pass, db_host, db_port, db_name
            )
        elif dba:
            rfam_db_url = dba
        else:
            if verbose:
                logging.info("Looking for db in mysql-ens-sta-1")
            registry = "ensro@mysql-ens-sta-1:4519"
            rfam_db_url = self.get_db_from_registry(
                species_name, "core", ensembl_release, registry
            )

        if not rfam_db_url:
            raise IOError(f"Could not find RFAM DB.")
        else:
            if verbose:
                logging.info(f"Found RFAM DB: {rfam_db_url}")

        # Get data from rfam db
        db_engine = self.get_db_engine(rfam_db_url)
        with db_engine.connect() as rfam_dbi:
            query = (
                select(
                    TranscriptORM.stable_id.distinct(),
                    DnaAlignFeatureORM.hit_name,
                    AnalysisORM.analysis_id,
                )
                .join(
                    TranscriptORM,
                    and_(
                        TranscriptORM.analysis_id == AnalysisORM.analysis_id,
                        AnalysisORM.logic_name.like("ncrna%"),
                        TranscriptORM.biotype != "miRNA",
                    ),
                )
                .join(
                    ExonTranscriptORM,
                    ExonTranscriptORM.transcript_id == TranscriptORM.transcript_id,
                )
                .join(
                    SupportingFeatureORM,
                    and_(
                        SupportingFeatureORM.exon_id == ExonTranscriptORM.exon_id,
                        SupportingFeatureORM.feature_type == "dna_align_feature",
                    ),
                )
                .join(
                    DnaAlignFeatureORM,
                    DnaAlignFeatureORM.dna_align_feature_id
                    == SupportingFeatureORM.feature_id,
                )
                .order_by(DnaAlignFeatureORM.hit_name)
            )
            result = rfam_dbi.execute(query).mappings().all()

        # Create a dict with RFAM accessions as keys and value is an array of ensembl transcript stable_ids
        rfam_transcript_stable_ids = {}
        for row in result:
            rfam_id = None

            match = re.search(r"^(RF\d+)", row.hit_name)
            if match:
                rfam_id = match.group(1)

            if rfam_id:
                rfam_transcript_stable_ids.setdefault(rfam_id, []).append(row.stable_id)

        # Download file through wget if url present
        if wget_url:
            uri = urlparse(wget_url)
            file = os.path.join(os.path.dirname(file), os.path.basename(uri.path))
            wget.download(wget_url, file)

        # Read data from file
        lines = []
        entry = ""

        file_io = gzip.open(file, "r")
        for line in file_io:
            line = line.decode("latin-1")
            if re.search(r"^//", line):
                lines.append(entry)
                entry = ""
            elif (
                re.search(r"^#=GF\sAC", line)
                or re.search(r"^#=GF\sID", line)
                or re.search(r"^#=GF\sDE", line)
            ):
                entry += line
        file_io.close()

        # Add xrefs
        xref_count, direct_count = 0, 0

        for entry in lines:
            accession, label, description = None, None, None

            # Extract data from entry
            match = re.search(r"^#=GF\sAC\s+(\w+)", entry, flags=re.MULTILINE)
            if match:
                accession = match.group(1)
            match = re.search(r"^#=GF\sID\s+([^\n]+)", entry, flags=re.MULTILINE)
            if match:
                label = match.group(1)
            match = re.search(r"^#=GF\sDE\s+([^\n]+)", entry, flags=re.MULTILINE)
            if match:
                description = match.group(1)

            if accession:
                if rfam_transcript_stable_ids.get(accession):
                    xref_id = self.add_xref(
                        {
                            "accession": accession,
                            "version": 0,
                            "label": label or accession,
                            "description": description,
                            "source_id": source_id,
                            "species_id": species_id,
                            "info_type": "DIRECT",
                        },
                        xref_dbi,
                    )
                    xref_count += 1

                    transcript_stable_ids = rfam_transcript_stable_ids[accession]
                    for stable_id in transcript_stable_ids:
                        self.add_direct_xref(
                            xref_id, stable_id, "Transcript", "", xref_dbi
                        )
                        direct_count += 1

        result_message = (
            f"Added {xref_count} RFAM xrefs and {direct_count} direct xrefs"
        )

        return 0, result_message
