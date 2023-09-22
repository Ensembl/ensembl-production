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
from eHive import ParamException
from sqlalchemy.engine.url import make_url


class MetadataUpdaterHiveProcessDb(BaseProdRunnable):
    def fetch_input(self):
        try:
            payload = json.loads(self.param_required("payload"))

            self.param("comment", payload["input"].get("comment", None))
            self.param("database_uri", payload["input"].get("database_uri", None))
            self.param_required("database_uri")
            self.param("email", payload["input"].get("email", None))
            self.param("metadata_uri", payload["input"].get("metadata_uri", None))
            self.param_required("metadata_uri")
            self.param("source", payload["input"].get("source", None))
            self.param("timestamp", payload["input"].get("timestamp", None))
            self.param("taxonomy_uri", payload["input"].get("taxonomy_uri", None))
            self.param_required("taxonomy_uri")

        except json.JSONDecodeError as e:
            raise ParamException(e)

    def run(self):
        db_url = make_url(self.param("database_uri"))
        output = {
            "database_uri": self.param("database_uri"),
            "metadata_uri": self.param("metadata_uri"),
        }
        if '_compara_' in db_url.database:
            self.dataflow(output, 4)
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
                '^ensembl_accounts|ensembl_archive|ensembl_autocomplete|ensembl_production|ensembl_stable_ids|ncbi_taxonomy|ontology|website',
                db_url.database):
            self.dataflow(output, 10)
        else:
            raise Exception("Can't find data_type for database " + db_url.database)
