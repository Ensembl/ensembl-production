
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
from ensembl.production.metadata.updater.core import CoreMetaUpdater

class MetadataUpdaterHiveCore(BaseProdRunnable):

    def run(self):
        if self.param("force") == "0":
            Run = CoreMetaUpdater(self.param("database_uri"), self.param("metadata_uri"), self.param("taxonomy_uri"))
        elif self.param("force") == "1":
            Run = CoreMetaUpdater(self.param("database_uri"), self.param("metadata_uri"), self.param("taxonomy_uri"), force=1)
        else:
            raise ValueError
        Run.process_core()

