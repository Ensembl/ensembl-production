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

from ensembl.xrefs.Base import *

from smtplib import SMTP
from email.message import EmailMessage

class EmailNotification(Base):
  def run(self):
    pipeline_name = self.param_required('pipeline_name')
    base_path     = self.param_required('base_path')
    email_address = self.param_required('email')
    email_server  = self.param_required('email_server')
    log_timestamp = self.param('log_timestamp')

    email_message = f'The <b>{pipeline_name}</b> has completed its run.<br>'

    if log_timestamp:
      # Get the path of the log files
      log_path = os.path.join(base_path, 'logs', log_timestamp)

      # Read the log file
      if os.path.exists(log_path):
        log_files = os.listdir(log_path)

        parameters, sources, added_species, skipped_species = {}, {}, {}, {}

        main_log_file = os.path.join(base_path, 'logs', log_timestamp, 'logfile_'+log_timestamp)

        # Copy different log files into a main one
        with open(main_log_file, 'a') as out_fh:
          for log_file in log_files:
            if not re.search(r"^tmp_", log_file): continue
            log_file = os.path.join(log_path, log_file)
            with open(log_file) as in_fh:
              log_data = in_fh.read()
              out_fh.write(log_data)
            os.remove(log_file)

        # Read the full logs
        with open(main_log_file) as fh:
          data = fh.read()

        # Extract parameter data
        parameters_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Param: (\w+) = (.*)", data)
        parameters = {param[0]: param[1] for param in parameters_list}

        email_message += '<br>The pipeline was run with the following parameters:<br>'
        for param_name,param_value in parameters.items():
          email_message += f'<b>{param_name}</b> = {param_value}<br>'

        if re.search('Download', pipeline_name):
          #Extract data from logs
          sources_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source to download: ([\w\/]+)", data)
          sources = {source : {'to_download' : 1} for source in sources_list}

          sources_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source to cleanup: ([\w\/]+)", data)
          for source in sources_list: sources[source].update({'to_cleanup' : 1})

          sources_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source to preparse: ([\w\/]+)", data)
          for source in sources_list: sources[source].update({'to_preparse' : 1})

          sources_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source ([\w\/]+) cleaned up", data)
          for source in sources_list: sources[source].update({'cleaned_up' : 1})

          sources_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| Source ([\w\/]+) preparsed", data)
          for source in sources_list: sources[source].update({'preparsed' : 1})

          sources_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) file already exists, skipping download \((.*)\)", data)
          for source in sources_list: sources[source[0]].update({'skipped' : os.path.dirname(source[1])})

          sources_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) file downloaded via (HTTP|FTP): (.*)", data)
          for source in sources_list: sources[source[0]].update({'downloaded' : source[1]+"|"+os.path.dirname(source[2])})

          sources_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| ([\w\/]+) file copied from local FTP: (.*)", data)
          for source in sources_list: sources[source[0]].update({'copied' : os.path.dirname(source[1])})

          skipped_species_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| (\w+) skipped species = (\d+)", data)
          skipped_species = {source[0]: source[1] for source in skipped_species_list}

          added_species_list = re.findall(r"^\d{2}-\w{3}-\d{4} \\| INFO \\| (\w+) species files created = (\d+)", data)
          added_species = {source[0]: source[1] for source in added_species_list}

          # Include source statistics
          email_message += '<br>--Source Statistics--<br>'
          for source_name,source_values in sources.items():
            email_message += f'<b>{source_name}:</b><br>'
            if source_values.get('to_download'): email_message += '&nbsp;&nbsp;&nbsp;Scheduled for download &#10004;<br>'

            if source_values.get('downloaded'):
              (download_type, file_path) = source_values['downloaded'].split("|")
              email_message += f'&nbsp;&nbsp;&nbsp;File downloaded via {download_type} into {file_path}<br>'
            elif source_values.get('copied'): email_message += '&nbsp;&nbsp;&nbsp;File(s) copied from local FTP into %s<br>' % (source_values['copied'])
            elif source_values.get('skipped'): email_message += '&nbsp;&nbsp;&nbsp;File(s) download skipped, already exists in %s<br>' % (source_values['skipped'])

            if source_values.get('to_cleanup'): email_message += '&nbsp;&nbsp;&nbsp;Scheduled for cleanup &#10004;<br>'
            if source_values.get('cleaned_up'): email_message += '&nbsp;&nbsp;&nbsp;Cleaned up &#10004;<br>'

            if source_values.get('to_preparse'): email_message += '&nbsp;&nbsp;&nbsp;Scheduled for pre-parse &#10004;<br>'
            if source_values.get('preparsed'): email_message += '&nbsp;&nbsp;&nbsp;Pre-parsed &#10004;<br>'

          # Include species statistics
          email_message += '<br>--Species Statistics--<br>'
          email_message += 'Skipped Species (files already exist):<br>'
          for source_name, count in skipped_species.items():
            email_message += f'&nbsp;&nbsp;&nbsp;{source_name}: {count}<br>'
          email_message += 'Added Species (files created):<br>'
          for source_name, count in added_species.items():
            email_message += f'&nbsp;&nbsp;&nbsp;{source_name}: {count}<br>'

          email_message += '<br>To run the Xref Process Pipeline based on the data from this pipeline, use the same <b>--base_path</b>, <b>--source_db_url</b>, and <b>--central_db_url</b> (if preparse was run) values provided to this pipeline.'

    # Send email
    message = EmailMessage()
    message['Subject'] = f'{pipeline_name} Finished'
    message['From'] = email_address
    message['To'] = email_address
    message.set_content(email_message, 'html')

    smtp = SMTP(email_server)
    smtp.send_message(message)

