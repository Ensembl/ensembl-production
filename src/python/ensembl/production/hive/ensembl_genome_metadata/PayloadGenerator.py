
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


from ensembl.production.hive.BaseProdRunnable import BaseProdRunnable
import json
from datetime import datetime
from ensembl.production.metadata.updater import CoreMetaUpdater

class MetadataUpdaterHiveCdna(BaseProdRunnable):
    # Goal of this step is to replicate the json emitted from handover payload
    #         {
    #   "id": 1,
    #   "input": {
    #     "comment": "test1",
    #     "database_uri": "mysql://ensadmin:ensembl@mysql-ens-general-dev-1:4484/homo_sapiens_core_106_38",
    #     "email": "test@ebi.ac.uk",
    #     "metadata_uri": "mysql://ensprod:s3cr3t@mysql-ens-meta-prod-1:4483/ensembl_metadata_production",
    #     "source": "Handover",
    #     "timestamp": "Tue Oct 12 17:21:35 2021"
    #   },
    #   "status": "complete"
    # }
    def run(self):
        data = dict()
        data['id'] = 1
        data['status'] = 'complete'
        data['input'] = dict()
        data['input']['comment'] = self.param("comment")
        data['input']['database_uri'] = self.param_required('db_url')
        data['input']['email'] = self.param("email")
        data['input']['metadata_uri'] = self.param("metadata_uri")
        data['input']['source'] = self.param("source")
        dt = datetime.now()
        data['input']['timestamp'] = dt.strftime("%a %b %m %H:%M:%S %Y")
        payload = json.dumps(data)
        self.dataflow(payload, 10)


