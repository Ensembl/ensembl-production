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

from pathlib import Path
import re
import json
from ensembl.production.hive.BaseProdRunnable import BaseProdRunnable
from sqlalchemy.engine.url import make_url

class MetadataUpdaterHiveProcessDb(BaseProdRunnable):
    def fetch_input(self):
        # input_data = self.get_input_data()
        # self.param("input_data", input_data)
        # self.param("metadata_uri", input_data.get("metadata_uri"))
        # self.param("database_uri", input_data.get("database_uri"))
        # self.param("e_release", input_data.get("e_release"))
        # self.param("email", input_data.get("email"))
        # self.param("timestamp", input_data.get("timestamp"))
        # self.param("comment", input_data.get("comment"))
        # self.param("payload", input_data.get("payload"))
        if self.param('payload'):
            payload = json.loads(self.param('payload'))
            self.param("comment", payload["input"]["comment"])
            self.param("database_uri", payload["input"]["database_uri"])
            self.param("email", payload["input"]["email"])
            self.param("metadata_uri", payload["input"]["metadata_uri"])
            self.param("source", payload["input"]["source"])
            self.param("timestamp", payload["input"]["timestamp"])


    def run(self):
        db_url = make_url(self.param("database_uri"))
        output = {
            "database_uri" : self.param("database_uri"),
            "metadata_uri" : self.param("metadata_uri"),
        }
        if '_compara_' in db_url.database:
            self.dataflow(output, 4)
        elif '_variation_' in db_url.database:
            self.dataflow(output, 5)
        elif '_funcgen_' in db_url.database:
            self.dataflow(output, 6)
        elif '_core_' in db_url.database:
            self.dataflow(output, 3)
        elif '_otherfeatures_' in db_url.database:
            self.dataflow(output, 7)
        elif '_rnaseq_' in db_url.database:
            self.dataflow(output, 8)
        elif '_cdna_' in db_url.database:
            self.dataflow(output, 9)
        # Dealing with other versionned databases like mart, ontology,...
        elif re.match('^\w+_?\d*_\d+$', db_url.database):
            self.dataflow(output, 10)
        elif re.match(
                '^ensembl_accounts|ensembl_archive|ensembl_autocomplete|ensembl_metadata|ensembl_production|ensembl_stable_ids|ncbi_taxonomy|ontology|website',
                db_url.database):
            self.dataflow(output, 10)
        else:
            raise "Can't find data_type for database " + db_url.database

