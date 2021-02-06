"""
.. See the NOTICE file distributed with this work for additional information
   regarding copyright ownership.
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
       http://www.apache.org/licenses/LICENSE-2.0
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
"""
import collections
import json
import time
from urllib.parse import urlparse

from ensembl.hive.HiveRESTClient import HiveRESTClient

JobProgress = collections.namedtuple("JobProgress", "status_msg table_copied total_tables progress runtime")


class ProductionDBCopy(HiveRESTClient):
    """ Production DB copy REST Hive Client: """

    def fetch_input(self):

        src_db = urlparse(self.param('source_db_uri'))
        tgt_db = urlparse(self.param('target_db_uri'))
        if src_db and tgt_db and src_db.scheme and src_db.hostname and tgt_db.hostname and tgt_db.scheme:
            # only if both parameters are set and valid
            self.param('payload', json.dumps({
                "src_host": ':'.join((src_db.hostname, str(src_db.port))),
                "src_incl_db": src_db.path[1:],
                "tgt_host": ':'.join((tgt_db.hostname, str(tgt_db.port))),
                "tgt_db_name": tgt_db.path[1:],
                "user": "ensprod"
            }))
        super().fetch_input()

    def run(self):
        response = self.param('response')
        if response.status_code != 201:
            raise Exception('The Copy submission failed: %s (%s)' % (response.status_code, response.json()))
        submitted_time = time.time()
        payload = json.loads(self.param('payload'))
        while True:
            with self._session_scope() as http:
                job_response = http.request(method='get',
                                            url=self.param('endpoint') + '/' + response.json()['job_id'],
                                            headers=self.param('headers'),
                                            timeout=self.param('timeout'))
            # job progress
            runtime = time.time() - submitted_time
            # message is a dict as follow:
            # "detailed_status": {
            #   "status_msg": "Complete",
            #   "progress": 100.0,
            #   "total_tables": 77,
            #   "table_copied": 77
            # }
            #
            message = job_response.json().get("detailed_status", {})
            message.update({"runtime": str(runtime)})
            self.dataflow({
                'job_id': self.input_job.dbID,
                'message': json.dumps(message)
            }, 3)
            if job_response.json()['overall_status'] == 'Failed':
                raise Exception(
                    'The Copy failed, check: ' + self.param('endpoint') + '/' + response.json()['job_id'])
            elif job_response.json()['overall_status'] == 'Complete':
                break
            # If the copy takes more than 2 hours then kill the job
            elif time.time() - submitted_time > 10800:
                raise Exception('The Copy seems to be stuck - please contact Production team')
            # Pause for 1min before checking copy status again
            time.sleep(60)

        runtime = time.time() - submitted_time
        output = {
            'source_db_uri': '/'.join((payload["src_host"], payload['src_incl_db'])),
            'target_db_uri': payload['tgt_host'],
            'runtime': str(runtime)
        }
        # in coordination with the dataflow output set in config to "?table_name=results",
        # this will insert results in hive db. Remember @Luca/@marc conversation.
        self.dataflow({
            'job_id': self.input_job.dbID,
            'output': json.dumps(output)
        }, 2)

    def process_response(self, response):
        pass
