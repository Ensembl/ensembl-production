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

"""Email module to send user emails notifying of xref pipelines end, with important information and statistics."""

from ensembl.production.xrefs.Base import *

from smtplib import SMTP
from email.message import EmailMessage


class EmailNotification(Base):
    def run(self):
        pipeline_name = self.param_required("pipeline_name", {"type": "str"})
        base_path     = self.param_required("base_path", {"type": "str"})
        release       = self.param_required("release", {"type": "int"})
        email_address = self.param_required("email", {"type": "str"})
        email_server  = self.param_required("email_server", {"type": "str"})
        log_timestamp = self.param("log_timestamp", None, {"type": "str"})

        email_message = f"The <b>{pipeline_name}</b> has completed its run.<br>"

        indent = "&nbsp;&nbsp;&nbsp;"

        if log_timestamp:
            # Get the path of the log files
            log_path = os.path.join(base_path, "logs", log_timestamp)

            # Read the log file
            if os.path.exists(log_path):
                parameters = {}

                # Copy different log files into a main one
                main_log_file = self.combine_logs(
                    base_path, log_timestamp, pipeline_name
                )

                # Read the full logs
                with open(main_log_file) as fh:
                    data = fh.read()

                # Extract parameter data
                parameters_list = re.findall(
                    r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Param: (\w+) = (.*)", data
                )
                parameters = {param[0]: param[1] for param in parameters_list}

                email_message += (
                    "<br>The pipeline was run with the following parameters:<br>"
                )
                for param_name, param_value in parameters.items():
                    if param_value == "1" or param_value == "0":
                        param_value = bool(param_value)
                    email_message += f"<b>{param_name}</b> = {param_value}<br>"

                # Extract statistics data from logs
                if re.search("Download", pipeline_name):
                    sources_data, added_species, skipped_species = {}, {}, {}

                    # Get sources scheduled for download
                    matches_list = re.findall(
                        r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source to download: ([\w\/]+)",
                        data,
                    )
                    sources_data = {
                        source: {"to_download": 1} for source in matches_list
                    }

                    # Get sources scheduled for cleanup
                    matches_list = re.findall(
                        r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source to cleanup: ([\w\/]+)",
                        data,
                    )
                    for source in matches_list:
                        sources_data[source].update({"to_cleanup": 1})

                    # Get sources cleaned up
                    matches_list = re.findall(
                        r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source ([\w\/]+) cleaned up",
                        data,
                    )
                    for source in matches_list:
                        sources_data[source].update({"cleaned_up": 1})

                    # Get sources with skipped download
                    matches_list = re.findall(
                        r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) file already exists, skipping download \((.*)\)",
                        data,
                    )
                    for source in matches_list:
                        sources_data[source[0]].update(
                            {"skipped": os.path.dirname(source[1])}
                        )

                    # Get sources downloaded
                    matches_list = re.findall(
                        r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) file downloaded via (HTTP|FTP): (.*)",
                        data,
                    )
                    for source in matches_list:
                        sources_data[source[0]].update(
                            {"downloaded": source[1] + "|" + os.path.dirname(source[2])}
                        )

                    # Get sources copied from local ftp
                    matches_list = re.findall(
                        r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) file copied from local FTP: (.*)",
                        data,
                    )
                    for source in matches_list:
                        sources_data[source[0]].update(
                            {"copied": os.path.dirname(source[1])}
                        )

                    # Get skipped species
                    skipped_species_list = re.findall(
                        r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) skipped species = (\d+)",
                        data,
                    )
                    skipped_species = {
                        source[0]: source[1] for source in skipped_species_list
                    }

                    # Get species with files created
                    added_species_list = re.findall(
                        r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) species files created = (\d+)",
                        data,
                    )
                    added_species = {
                        source[0]: source[1] for source in added_species_list
                    }

                    # Add source statistics to email message
                    email_message += "<br>--Source Statistics--<br>"
                    for source_name, source_values in sources.items():
                        email_message += f"<b>{source_name}:</b><br>"
                        if source_values.get("to_download"):
                            email_message += f"{indent}Scheduled for download &#10004;<br>"

                        if source_values.get("downloaded"):
                            (download_type, file_path) = source_values[
                                "downloaded"
                            ].split("|")
                            email_message += f"{indent}File downloaded via {download_type} into {file_path}<br>"
                        elif source_values.get("copied"):
                            email_message += (
                                indent
                                + "File(s) copied from local FTP into %s<br>"
                                % (source_values["copied"])
                            )
                        elif source_values.get("skipped"):
                            email_message += (
                                indent
                                + "File(s) download skipped, already exists in %s<br>"
                                % (source_values["skipped"])
                            )

                        if source_values.get("to_cleanup"):
                            email_message += f"{indent}Scheduled for cleanup &#10004;<br>"
                        if source_values.get("cleaned_up"):
                            email_message += f"{indent}Cleaned up &#10004;<br>"

                    # Add species statistics to email message
                    email_message += "<br>--Species Statistics--<br>"
                    email_message += "Skipped Species (files already exist):<br>"
                    for source_name, count in skipped_species.items():
                        email_message += f"{indent}{source_name}: {count}<br>"
                    email_message += "Added Species (files created):<br>"
                    for source_name, count in added_species.items():
                        email_message += f"{indent}{source_name}: {count}<br>"

                    email_message += "<br>To run the Xref Process Pipeline based on the data from this pipeline, use the same <b>--source_db_url</b>, and <b>--config_file</b> values provided to this pipeline."
                elif re.search("Process", pipeline_name):
                    parsed_sources, species_counts = {}, {}

                    # Get species mapped
                    matches_list = re.findall(
                        r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Mapping starting for species '([\w\/]+)'",
                        data,
                    )
                    for species_name in matches_list:
                        species_counts[species_name] = {
                            "DIRECT": 0,
                            "INFERRED_PAIR": 0,
                            "MISC": 0,
                            "CHECKSUM": 0,
                            "DEPENDENT": 0,
                            "SEQUENCE_MATCH": 0,
                        }

                    # Get number of xrefs added per species per source
                    matches_list = re.findall(
                        r"^\d{2}-\w{3}-\d{4} \\| INFO \\| \tLoaded (\d+) ([\w\/]+) xrefs for '([\w\/]+)'",
                        data,
                    )
                    for species in matches_list:
                        count = int(species[0])
                        xref_type = species[1]
                        species_name = species[2]

                        prev_count = species_counts[species_name][xref_type]
                        count += prev_count

                        species_counts[species_name][xref_type] = count

                    # Get parsed sources per species
                    matches_list = re.findall(
                        r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ParseSource starting for source '([\w\/]+)' with parser '([\w\/]+)' for species '([\w\/]+)'",
                        data,
                    )
                    for species in matches_list:
                        source_name = species[0]
                        parser = species[1]
                        species_name = species[2]

                        parsed_sources[species_name].update({source_name: parser})

                    # Add species statistics to email message
                    email_message += "<br>--Species Statistics--<br>"
                    for species_name, species_data in parsed_sources.items():
                        email_message += f"<b>{species_name}:</b><br>"
                        email_message += f"{indent}Sources parsed: " + ",".join(keys(species_data))

                        xref_counts = species_counts[species_name]
                        email_message += indent + "Xrefs added: "
                        for xref_type, count in xref_counts.items():
                            email_message += f"{count} {xref_type} "

        # Send email
        message = EmailMessage()
        message["Subject"] = f"{pipeline_name} Finished"
        message["From"] = email_address
        message["To"] = email_address
        message.set_content(email_message, "html")

        smtp = SMTP(email_server)
        smtp.send_message(message)

    def combine_logs(self, base_path: str, timestamp: str, type: str) -> str:
        ordered_processes = {
            "download": [
                "ScheduleDownload",
                "DownloadSource",
                "ScheduleCleanup",
                "Cleanup(.*)Source",
                "EmailNotification",
            ],
            "process": [
                "ScheduleSpecies",
                "ScheduleParse",
                "ParseSource",
                "(.*)Parser",
                "DumpEnsembl",
                "DumpXref",
                "ScheduleAlignment",
                "Alignment",
                "ScheduleMapping",
                "DirectXrefs",
                "ProcessAlignment",
                "RNACentralMapping",
                "UniParcMapping",
                "CoordinateMapping",
                "Mapping",
                "AdvisoryXrefReport",
                "EmailAdvisoryXrefReport",
                "EmailNotification",
            ],
        }
        log_order = (
            ordered_processes["download"]
            if re.search("Download", type)
            else ordered_processes["process"]
        )

        log_path = os.path.join(base_path, "logs", timestamp)
        log_files = os.listdir(log_path)

        main_log_file = os.path.join(
            base_path, "logs", timestamp, "logfile_" + timestamp
        )

        # Copy different log files into a main one
        with open(main_log_file, "a") as out_fh:
            for pattern in log_order:
                pattern = r"^tmp_logfile_" + pattern + r"_\d+"
                matches = [s for s in log_files if re.search(pattern, s)]

                for log_file in matches:
                    log_file = os.path.join(log_path, log_file)
                    with open(log_file) as in_fh:
                        log_data = in_fh.read()
                        out_fh.write(log_data)
                    os.remove(log_file)

        return main_log_file
