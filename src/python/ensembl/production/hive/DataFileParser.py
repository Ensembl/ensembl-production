#  See the NOTICE file distributed with this work for additional information
#  regarding copyright ownership.
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

from dataclasses import asdict

import eHive

from .datafile.parsers import get_parser
from .BaseProdRunnable import BaseProdRunnable


class DataFileParser(BaseProdRunnable):
    def fetch_input(self):
        input_data = self.get_input_data()
        self.param("input_data", input_data)
        # Store file_format and file_path in parameters for visibility/clarity
        self.param("file_format", input_data.get("file_format"))
        self.param("file_path", input_data.get("file_path"))

    def run(self):
        file_format = self.param("file_format")
        file_path = self.param("file_path")
        ParserClass, err_result = get_parser(file_format, file_path)
        if err_result:
            self.warning(err_result.errors[0])
            self.param("result", err_result)
        else:
            parser = ParserClass(
                ftp_dir_ens=self.param("ftp_dir_ens"),
                ftp_dir_eg=self.param("ftp_dir_eg"),
                ftp_url_ens=self.param("ftp_url_ens"),
                ftp_url_eg=self.param("ftp_url_eg"),
            )
            result = parser.parse_metadata(self.param("input_data"))
            if result.errors:
                self.warning(f"Errors: {result.errors}")
            self.param("result", result)

    def write_output(self):
        self.write_result(asdict(self.param("result")))
