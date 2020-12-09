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
import time
from urllib.parse import urlparse

from ensembl.hive.HiveRESTClient import HiveRESTClient


class ProductionDBCopy(HiveRESTClient):
    """ OLS MySQL loader: initialise basics info in Ontology DB """

    def fetch_input(self):

        src_db = urlparse(self.param('source_db_uri'))
        tgt_db = urlparse(self.param('target_db_uri'))
        if src_db.scheme and src_db.hostname and tgt_db.hostname and tgt_db.scheme:
            # only if both parameters are set and valid
            self.param('payload', {
                "src_host": ':'.join((src_db.hostname, src_db.port)),
                "src_incl_db": src_db.path[1:],
                "tgt_host": ':'.join((tgt_db.hostname, tgt_db.port)),
                "tgt_db_name": src_db.path[1:],
                "user": "ensprod"
            })

    def run(self):
        response = self.param('response')
        if response.status_code != 201:
            raise Exception('The Copy submission failed: ' + response.raise_for_status)
        submitted_time = time.time()
        while True:
            with self._session_scope() as http:
                job_response = http.request(method='get',
                                            url=self.param('endpoint') + '/' + response.json()['job_id'],
                                            headers=self.param('headers'),
                                            timeout=self.param('timeout'))
            if job_response.json()['overall_status'] == 'Failed':
                raise Exception(
                    'The Copy failed, check: ' + self.param('endpoint') + '/' + response.json()['job_id'])
            elif job_response.json()['overall_status'] == 'Complete':
                break
            # If the copy takes more than 2 hours then kill the job
            elif time.time() - submitted_time > 10800:
                raise Exception('The Copy seems to be stuck')
            # Pause for 1min before checking copy status again
            time.sleep(60)
        pass

    def process_response(self, response):
        pass
