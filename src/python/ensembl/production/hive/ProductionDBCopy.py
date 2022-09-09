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
import time
from urllib.parse import urlparse
from ensembl.production.core.clients.dbcopy import DbCopyRestClient
from .BaseProdRunnable import BaseProdRunnable

class ProductionDBCopy(BaseProdRunnable):
    """" Production Dbcopy Client """

    def fetch_input(self):

        try:

            self.param('db_copy_client', DbCopyRestClient(self.param_required('endpoint')))

            src_db = urlparse(self.param('source_db_uri'))
            tgt_db = urlparse(self.param('target_db_uri'))
            if src_db and tgt_db and src_db.scheme and src_db.hostname and tgt_db.hostname and tgt_db.scheme: 
                src_host =  ':'.join((src_db.hostname, str(src_db.port)))
                src_incl_db = src_db.path[1:]
                tgt_host = ':'.join((tgt_db.hostname, str(tgt_db.port)))
                tgt_db_name =  tgt_db.path[1:]
            else:
                payload = json.loads(self.param('payload'))
                src_host = payload.get('src_host', None)
                src_incl_db = payload.get('src_incl_db', None)
                tgt_host = payload.get('tgt_host', None)
                tgt_db_name =  payload.get('tgt_db_name', '')
                
            user = payload.get('user', None)
            email = payload.get('email', f"{user}@ebi.ac.uk")

            copy_job_id = self.param('db_copy_client').submit_job(src_host, src_incl_db, None, None, None,
                                                tgt_host, tgt_db_name, False, False, False, email, user)

            self.param('copy_job_id', copy_job_id)
            self.param('src_host', src_host)
            self.param('src_incl_db', src_incl_db)
            self.param('tgt_host', tgt_host)

        except Exception as e:
            raise IOError(f"Failed to submit copyjob {payload} error: {e}")

    def run(self):

        db_copy_client = self.param('db_copy_client')
        copy_job_id = self.param('copy_job_id')
        submitted_time = time.time()
        src_host = self.param('src_host')
        src_incl_db = self.param('src_incl_db')
        tgt_host = self.param('tgt_host') 
        try:
            while True:

                job = db_copy_client.retrieve_job(copy_job_id)
                status = job['overall_status']
                runtime = time.time() - submitted_time
                message =  job.get("detailed_status", {})
                message.update({"runtime": str(runtime)})
                self.write_progress(message)
                
                if status == 'Failed':
                    raise IOError(
                        f"The Copy failed, check: {self.param('endpoint')}/{job_id}"
                    )
                if status == 'Complete':
                    break

                # Pause for 1min before checking copy status again
                time.sleep(60)

            runtime = time.time() - submitted_time
            output = {
                'source_db_uri': f"{src_host}/{src_incl_db}",
                'target_db_uri': tgt_host,
                'runtime': str(runtime)
            }
            # in coordination with the dataflow output set in config to "?table_name=results",
            # this will insert results in hive db. Remember @Luca/@marc conversation.
            self.write_result(output)

        except Exception as e:
            raise IOError(f"Copy Job Failed {copy_job_id} {e}")

