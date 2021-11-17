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

import json

import eHive


class BaseProdRunnable(eHive.BaseRunnable):
    def flow_output_data(self, data: dict, channel: int = 1) -> None:
        self.dataflow({
            'data': json.dumps(data)
        }, channel)

    def get_input_data(self) -> dict:
        return json.loads(self.param("data"))

    def write_result(self, output: dict) -> None:
        self.dataflow({
            'job_id': self.input_job.dbID,
            'output': json.dumps(output)
        }, 2)

    def write_progress(self, message: dict) -> None:
        self.dataflow({
            'job_id': self.input_job.dbID,
            'message': json.dumps(message)
        }, 3)