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
from ensembl.production.hive.BaseProdRunnable import BaseProdRunnable
from ensembl.production.metadata.updater.core import CoreMetaUpdater


class MetadataUpdaterHiveCore(BaseProdRunnable):

    def run(self):
        try:
            run = CoreMetaUpdater(self.param("database_uri"), self.param("genome_metadata_uri"))
            run.process_core()
            output = { 'metadata_uri' : self.param("genome_metadata_uri"),
             'database_uri' : self.param("database_uri"),
             'email': self.param("email")
            }
            
            self.dataflow({
			    'job_id' : self.input_job.dbID,
			    'output' : json.dumps(output)
			}, 2);

        except Exception as e : 
            raise ValueError(str(e))
