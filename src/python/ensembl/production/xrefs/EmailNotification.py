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

import os
import re
from smtplib import SMTP
from email.message import EmailMessage
from typing import Dict, Any, Tuple

from ensembl.production.xrefs.Base import Base

class EmailNotification(Base):
    INDENT = "&nbsp;&nbsp;&nbsp;"

    def run(self):
        pipeline_name: str = self.get_param("pipeline_name", {"required": True, "type": str})
        base_path: str = self.get_param("base_path", {"required": True, "type": str})
        email_address: str = self.get_param("email", {"required": True, "type": str})
        email_server: str = self.get_param("email_server", {"required": True, "type": str})
        log_timestamp: str = self.get_param("log_timestamp", {"type": str})

        email_message = f"The <b>{pipeline_name}</b> has completed its run.<br>"

        if log_timestamp:
            # Get the path of the log files
            log_path = os.path.join(base_path, "logs", log_timestamp)

            if os.path.exists(log_path):
                # Combine the logs into a single file
                main_log_file = self.combine_logs(base_path, log_timestamp, pipeline_name)

                # Read the logs
                with open(main_log_file) as fh:
                    data = fh.read()

                # Extract the parameters and format them
                parameters = self.extract_parameters(data)
                email_message += self.format_parameters(parameters)

                # Extract statistics data from logs
                if re.search("Download", pipeline_name):
                    sources_data, added_species, skipped_species = self.extract_download_statistics(data)
                    email_message += self.format_download_statistics(sources_data, added_species, skipped_species)
                elif re.search("Process", pipeline_name):
                    parsed_sources, species_counts = self.extract_process_statistics(data)
                    email_message += self.format_process_statistics(parsed_sources, species_counts)

        # Send email
        self.send_email(email_address, email_server, pipeline_name, email_message)

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
        log_order = ordered_processes["download"] if re.search("Download", type) else ordered_processes["process"]

        log_path = os.path.join(base_path, "logs", timestamp)
        log_files = os.listdir(log_path)

        main_log_file = os.path.join(base_path, "logs", timestamp, "logfile_" + timestamp)

        # Copy different log files into a main one
        with open(main_log_file, "a") as out_fh:
            for pattern in log_order:
                pattern = r"^tmp_logfile_" + pattern + r"_\d+"
                matches = [s for s in log_files if re.search(pattern, s)]

                for log_file in matches:
                    log_file_path = os.path.join(log_path, log_file)
                    with open(log_file_path) as in_fh:
                        out_fh.write(in_fh.read())
                    os.remove(log_file_path)

        return main_log_file

    def extract_parameters(self, data: str) -> Dict[str, str]:
        parameters_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Param: (\w+) = (.*)", data)
        return {param[0]: param[1] for param in parameters_list}

    def format_parameters(self, parameters: Dict[str, str]) -> str:
        message = "<br>The pipeline was run with the following parameters:<br>"
        for param_name, param_value in parameters.items():
            message += f"<b>{param_name}</b> = {param_value}<br>"

        return message

    def extract_download_statistics(self, data: str) -> Tuple[Dict[str, Dict[str, Any]], Dict[str, str], Dict[str, str]]:
        sources_data = self.extract_sources_data(data)
        skipped_species = self.extract_skipped_species(data)
        added_species = self.extract_added_species(data)

        return sources_data, added_species, skipped_species

    def extract_sources_data(self, data: str) -> Dict[str, Dict[str, Any]]:
        sources_data = {}

        sources_data.update(self.extract_sources(data, r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source to download: ([\w\/]+)", "to_download"))
        sources_data.update(self.extract_sources(data, r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source to cleanup: ([\w\/]+)", "to_cleanup"))
        sources_data.update(self.extract_sources(data, r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source ([\w\/]+) cleaned up", "cleaned_up"))
        sources_data.update(self.extract_sources(data, r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) file already exists, skipping download \((.*)\)", "skipped", True))
        sources_data.update(self.extract_sources(data, r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) file downloaded via (HTTP|FTP): (.*)", "downloaded", True))
        sources_data.update(self.extract_sources(data, r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) file copied from local FTP: (.*)", "copied", True))

        return sources_data

    def extract_sources(self, data: str, pattern: str, key: str, split: bool = False) -> Dict[str, Dict[str, Any]]:
        sources = {}

        matches_list = re.findall(pattern, data)
        for match in matches_list:
            if split:
                if key == "skipped" or key == "copied":
                    val = os.path.dirname(match[1])
                else:
                    val = f"{match[1]}|" + os.path.dirname(match[2])
                sources[match[0]] = {key: val}
            else:
                sources[match] = {key: True}

        return sources

    def extract_skipped_species(self, data: str) -> Dict[str, str]:
        skipped_species_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) skipped species = (\d+)", data)
        return {species[0]: species[1] for species in skipped_species_list}

    def extract_added_species(self, data: str) -> Dict[str, str]:
        added_species_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) species files created = (\d+)", data)
        return {species[0]: species[1] for species in added_species_list}

    def format_download_statistics(self, sources_data: Dict[str, Dict[str, Any]], added_species: Dict[str, str], skipped_species: Dict[str, str]) -> str:
        message = "<br>--Source Statistics--<br>"

        for source_name, source_values in sources_data.items():
            message += f"<b>{source_name}:</b><br>"
            if source_values.get("to_download"):
                message += f"{self.INDENT}Scheduled for download &#10004;<br>"
            if source_values.get("downloaded"):
                download_type, file_path = source_values["downloaded"].split("|")
                message += f"{self.INDENT}File downloaded via {download_type} into {file_path}<br>"
            elif source_values.get("copied"):
                message += f"{self.INDENT}File(s) copied from local FTP into {source_values['copied']}<br>"
            elif source_values.get("skipped"):
                message += f"{self.INDENT}File(s) download skipped, already exists in {source_values['skipped']}<br>"
            if source_values.get("to_cleanup"):
                message += f"{self.INDENT}Scheduled for cleanup &#10004;<br>"
            if source_values.get("cleaned_up"):
                message += f"{self.INDENT}Cleaned up &#10004;<br>"

        message += "<br>--Species Statistics--<br>"
        message += "Skipped Species (files already exist):<br>"
        for source_name, count in skipped_species.items():
            message += f"{self.INDENT}{source_name}: {count}<br>"
        message += "Added Species (files created):<br>"
        for source_name, count in added_species.items():
            message += f"{self.INDENT}{source_name}: {count}<br>"

        message += "<br>To run the Xref Process Pipeline based on the data from this pipeline, use the same <b>--source_db_url</b>, <b>--split_files_by_species</b>, and <b>--config_file</b> values provided to this pipeline."
        return message

    def extract_process_statistics(self, data: str) -> Tuple[Dict[str, Dict[str, str]], Dict[str, Dict[str, int]]]:
        parsed_sources = self.extract_parsed_sources(data)
        species_counts = self.extract_species_counts(data)

        return parsed_sources, species_counts

    def extract_parsed_sources(self, data: str) -> Dict[str, Dict[str, str]]:
        parsed_sources = {}

        matches_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ParseSource starting for source '([\w\/]+)' with parser '([\w\/]+)' for species '([\w\/]+)'", data)
        for species in matches_list:
            source_name, parser, species_name = species
            if species_name not in parsed_sources:
                parsed_sources[species_name] = {}
            parsed_sources[species_name][source_name] = parser

        return parsed_sources

    def extract_species_counts(self, data: str) -> Dict[str, Dict[str, int]]:
        species_counts = {}

        # Get species mapped
        matches_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Mapping starting for species '([\w\/]+)'", data)
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
        matches_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| \tLoaded (\d+) ([\w\/]+) xrefs for '([\w\/]+)'", data)
        for species in matches_list:
            count, xref_type, species_name = int(species[0]), species[1], species[2]
            species_counts[species_name][xref_type] += count

        return species_counts

    def format_process_statistics(self, parsed_sources: Dict[str, Dict[str, str]], species_counts: Dict[str, Dict[str, int]]) -> str:
        message = "<br>--Species Statistics--<br>"

        for species_name, species_data in parsed_sources.items():
            message += f"<b>{species_name}:</b><br>"
            message += f"{self.INDENT}Sources parsed: " + ",".join(species_data.keys()) + "<br>"

            xref_counts = species_counts[species_name]
            message += f"{self.INDENT}Xrefs added: "
            for xref_type, count in xref_counts.items():
                message += f"{count} {xref_type} "
            message += "<br>"

        return message

    def send_email(self, email_address: str, email_server: str, pipeline_name: str, email_message: str) -> None:
        message = EmailMessage()
        message["Subject"] = f"{pipeline_name} Finished"
        message["From"] = email_address
        message["To"] = email_address
        message.set_content(email_message, "html")

        with SMTP(email_server) as smtp:
            smtp.send_message(message)
