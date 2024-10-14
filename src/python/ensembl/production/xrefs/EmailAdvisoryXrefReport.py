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

"""Email module to send user emails notifying of advisory DC failures."""

from ensembl.production.xrefs.Base import *

from smtplib import SMTP
from email.message import EmailMessage


class EmailAdvisoryXrefReport(Base):
    def run(self):
        base_path     = self.param_required("base_path", {"type": "str"})
        release       = self.param_required("release", {"type": "int"})
        pipeline_name = self.param_required("pipeline_name", {"type": "str"})
        email_address = self.param_required("email", {"type": "str"})
        email_server  = self.param_required("email_server", {"type": "str"})
        log_timestamp = self.param("log_timestamp", None, {"type": "str"})

        # Get the path and name of main reports file
        formatted_name = re.sub(r"\s", "_", pipeline_name)
        main_report_file_name = f"dc_report_{formatted_name}"
        if log_timestamp:
            log_path = os.path.join(base_path, "logs", log_timestamp)
            main_report_file_name = f"{main_report_file_name}_{log_timestamp}.log"
        else:
            log_path = os.path.join(base_path, "logs")
            if not os.path.exists(log_path):
                os.makedir(log_path)
            main_report_file_name = f"{main_report_file_name}.log"

        main_report_file = os.path.join(log_path, main_report_file_name)
        main_fh = open(main_report_file, "a")

        species_with_reports = {}

        # Get species in base path
        species_list = os.listdir(base_path)

        for species in species_list:
            # Check if reports exist
            dc_path = os.path.join(base_path, species, release, "dc_report")
            if os.path.exists(dc_path):
                # Get report files
                dc_files = os.listdir(dc_path)

                # Add each dc report into main report file
                for dc_file in dc_files:
                    with open(os.path.join(dc_path, dc_file), "r") as file:
                        dc_data = file.read()

                    main_fh.write(f"{dc_data}\n")

                    dc_name = dc_file.replace(".log", "")
                    if species_with_reports.get(dc_name):
                        species_with_reports[dc_name].append(species)
                    else:
                        species_with_reports[dc_name] = [species]

                # TO DO: maybe delete individual reports

        main_fh.close()

        email_message = f"Some advisory datachecks have failed for the following species in the xref pipeline run ({pipeline_name}).<br><br>"
        for dc_name, species_list in species_with_reports.items():
            email_message += f"Datacheck <b>{dc_name}</b>:<br>"
            email_message += "<ul>"
            for species_name in species_list:
                email_message += f"<li>{species_name}</li>"
            email_message += "</ul>"

        email_message += "<br>DC failures details attached in this email."

        # Send email
        message = EmailMessage()
        message["Subject"] = f"Advisory DC Report (release {release})"
        message["From"] = email_address
        message["To"] = email_address
        message.set_content(email_message, "html")

        with open(main_report_file, "rb") as fh:
            file_data = fh.read()
        message.add_attachment(
            file_data, maintype="text", subtype="plain", filename=main_report_file_name
        )

        smtp = SMTP(email_server)
        smtp.send_message(message)
