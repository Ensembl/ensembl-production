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
import os
from urllib import parse
import time

import eHive
from ensembl.hive.HiveRESTClient import HiveRESTClient



class ProductionDBCopy(HiveRESTClient):
    """ OLS MySQL loader: initialise basics info in Ontology DB """

    def run(self):
        if self.response.status_code != 201:
            raise Exception('The Copy submission failed: '+self.response.raise_for_status)
        submitted_time=time.time()
        while True:
            with self._session_scope() as http:
                job_response = http.request(method='get',
                                         url=self.param('endpoint')+'/'+self.response.json()['job_id'],
                                         headers=self.param('headers'),
                                         timeout=self.param('timeout'))
            if job_response.json()['overall_status'] == 'Failed':
                raise Exception('The Copy failed, check: '+self.param('endpoint')+'/'+self.response.json()['job_id'])
            elif job_response.json()['overall_status'] == 'Complete':
                break
            # If the copy takes more than 2 hours then kill the job
            elif time.time()-submitted_time > 7200:
                raise Exception('The Copy seems to be stuck')
            # Pause for 1min before checking copy status again
            time.sleep(60)
        pass

    def process_response(self, response):
        pass