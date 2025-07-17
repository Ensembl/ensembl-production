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

        email_message = f"<p>The <b>{pipeline_name}</b> has completed its run.<br>"
        if re.search("Download", pipeline_name):
            email_message += "To run the Xref Process Pipeline based on the data from this pipeline, use the same <b>--source_db_url</b>, <b>--split_files_by_species</b>, and <b>--config_file</b> values provided to this pipeline."
        email_message += "</p>"

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
                    parsed_sources, absolute_sources, species_counts = self.extract_process_statistics(data)
                    email_message += self.format_process_statistics(parsed_sources, species_counts, absolute_sources)

        # Send email
        self.send_email(email_address, email_server, pipeline_name, email_message)

    def combine_logs(self, base_path: str, timestamp: str, type: str) -> str:
        ordered_processes = {
            "download": [
                "ScheduleDownload",
                "DownloadSource",
                "ScheduleCleanup",
                "Checksum",
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
        parameters_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| \tParam: (\w+) = (.*)", data)
        return {param[0]: param[1] for param in parameters_list if param[0] != 'order_priority'}

    def format_parameters(self, parameters: Dict[str, str]) -> str:
        message = "<br><h5>Run Parameters</h5>"
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

        # Helper function to update sources_data
        def update_sources_data(new_data: Dict[str, Dict[str, Any]]):
            for key, value in new_data.items():
                if key in sources_data:
                    sources_data[key].update(value)
                else:
                    sources_data[key] = value

        # Get sources set to be downloaded
        update_sources_data(self.extract_sources(data, r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source to download: ([\w\/]+)", "to_download"))

        # Get sources set to be cleaned up
        update_sources_data(self.extract_sources(data, r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source to cleanup: ([\w\/]+)", "to_cleanup"))

        # Get sources cleaned up
        update_sources_data(self.extract_sources(data, r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source ([\w\/]+) cleaned up", "cleaned_up"))

        # Get sources skipped
        update_sources_data(self.extract_sources(data, r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) file already exists, skipping download \((.*)\)", "skipped", True))

        # Get sources downloaded
        update_sources_data(self.extract_sources(data, r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) file downloaded via (HTTP|FTP): (.*)", "downloaded", True))

        # Get sources copied
        update_sources_data(self.extract_sources(data, r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) file copied from local FTP: (.*)", "copied", True))

        return sources_data

    def extract_sources(self, data: str, pattern: str, key: str, split: bool = False) -> Dict[str, Dict[str, Any]]:
        sources = {}

        matches_list = re.findall(pattern, data)
        for match in matches_list:
            if split:
                if key == "skipped" or key == "copied":
                    val = os.path.dirname(match[1])
                else:
                    val = os.path.dirname(match[2])
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
        cell_style = 'style="border-right: 1px solid #000; padding: 5px;"'

        message = "<br><h5>Source Statistics</h5>"
        message += f"<table style=\"border-bottom: 1px solid #000;\"><tr style=\"border-bottom: 1px solid #000;\"><th {cell_style}>Source</th><th {cell_style}>Scheduled</th><th {cell_style}>Downloaded</th>"
        message += f"<th {cell_style}>Download Skipped</th><th {cell_style}>Cleaned-up</th><th style=\"padding: 5px;\">Location</th></tr>"
        for source_name, source_values in sources_data.items():
            message += f"<tr><td {cell_style}>{source_name}</td>"
            message += f"<td {cell_style}>X</td>" if source_values.get("to_download") else f"<td {cell_style}></td>"
            message += f"<td {cell_style}>X</td>" if source_values.get("downloaded") or source_values.get("copied") else f"<td {cell_style}></td>"
            message += f"<td {cell_style}>X</td>" if source_values.get("skipped") else f"<td {cell_style}></td>"
            message += f"<td {cell_style}>X</td>" if source_values.get("to_cleanup") else f"<td {cell_style}></td>"
            message += f"<td style=\"padding: 5px;\">{source_values.get('downloaded', source_values.get('copied', source_values.get('skipped', '')))}</td>"
            message += "</tr>"
        message += "</table>"

        message += "<br><h5>Species Statistics</h5>"
        message += "<b>Added Species (files created)</b>:<br><ul>"
        for source_name, count in added_species.items():
            message += f"<li>{source_name}: {count}</li>"
        message += "</ul>"
        message += "<b>Skipped Species (files already exist)</b>:<br><ul>"
        for source_name, count in skipped_species.items():
            message += f"<li>{source_name}: {count}</li>"
        message += "</ul>"

        return message

    def extract_process_statistics(self, data: str) -> Tuple[Dict[str, Dict[str, str]], Dict[str, bool], Dict[str, Dict[str, int]]]:
        parsed_sources, absolute_sources = self.extract_parsed_sources(data)
        species_counts = self.extract_species_counts(data)

        return parsed_sources, absolute_sources, species_counts

    def extract_parsed_sources(self, data: str) -> Tuple[Dict[str, Dict[str, str]], Dict[str, bool]]:
        parsed_sources = {}
        absolute_sources = {}

        matches_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ParseSource starting for source '([\w\/]+)' with parser '([\w\/]+)' for species '([\w\/]+)'", data)
        for species in matches_list:
            source_name, parser, species_name = species
            if species_name not in parsed_sources:
                parsed_sources[species_name] = {}
            parsed_sources[species_name][source_name] = parser
            absolute_sources[source_name] = True

        return parsed_sources, absolute_sources

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

    def format_process_statistics(self, parsed_sources: Dict[str, Dict[str, str]], species_counts: Dict[str, Dict[str, int]], absolute_sources: Dict[str, bool]) -> str:
        cell_style = 'style="border-right: 1px solid #000; padding: 5px;"'

        message = "<br><h5>Source Statistics</h5>"
        message += f"<table style=\"border: 1px solid #000;\"><tr style=\"border-bottom: 1px solid #000;\"><th {cell_style}>Species</th>"
        for source_name in sorted(absolute_sources):
            message += f"<th {cell_style}>{source_name}</th>"
        message += f"</tr>"

        for species_name, species_data in parsed_sources.items():
            message += f"<tr><td {cell_style}>{species_name}</td>"
            for source_name in sorted(absolute_sources):
                message += f"<td {cell_style}>X</td>" if source_name in species_data else f"<td {cell_style}></td>"
            message += "</tr>"
        message += "</table>"

        message += "<br><h5>Xref Data Statistics</h5>"
        message += f"<table style=\"border: 1px solid #000;\"><tr style=\"border-bottom: 1px solid #000;\"><th {cell_style}>Species</th><th {cell_style}>DIRECT</th><th {cell_style}>DEPENDENT</th>"
        message += f"<th {cell_style}>INFERRED_PAIR</th><th {cell_style}>CHECKSUM</th><th {cell_style}>SEQUENCE_MATCH</th><th {cell_style}>MISC</th></tr>"

        for species_name, species_data in species_counts.items():
            message += f"<tr><td {cell_style}>{species_name}</td>"
            message += f"<td {cell_style}>{species_data['DIRECT']}</td>"
            message += f"<td {cell_style}>{species_data['DEPENDENT']}</td>"
            message += f"<td {cell_style}>{species_data['INFERRED_PAIR']}</td>"
            message += f"<td {cell_style}>{species_data['CHECKSUM']}</td>"
            message += f"<td {cell_style}>{species_data['SEQUENCE_MATCH']}</td>"
            message += f"<td {cell_style}>{species_data['MISC']}</td>"
            message += "</tr>"
        message += "</table>"

        return message

    def send_email(self, email_address: str, email_server: str, pipeline_name: str, email_message: str) -> None:
        message = EmailMessage()
        message["Subject"] = f"{pipeline_name} Finished"
        message["From"] = email_address
        message["To"] = email_address
        message.set_content(email_message, "html")

        with SMTP(email_server) as smtp:
            smtp.send_message(message)
