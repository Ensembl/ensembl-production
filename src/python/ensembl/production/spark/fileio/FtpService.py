# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import sqlalchemy
from sqlalchemy import text
from datetime import datetime
__all__ = ['FtpService']

def get_dataset_path(url, username, pwd, species):
    if (len(pwd) > 0):
        url = "mysql://" + username + ":" + pwd + "@" + url.split("//")[1]
    else: 
        url = "mysql://" + username + "@" + url.split("//")[1]

    engine = sqlalchemy.create_engine(url)
    
    with engine.connect() as conn:
        query = text("select meta_value from meta where meta_key = \"assembly.accession\"  and species_id = (select species_id from meta where meta_value=\"" + species + "\" and meta_key=\"organism.production_name\")")
        assembly = conn.execute(query)
        for assembly_accession in assembly:
            assembly_accession = assembly_accession[0].replace("_", "")[:assembly_accession[0].index(".")]
            result = ("/").join((assembly_accession[i:i+3]) for i in range(0, len(assembly_accession), 3))
            result = result + "/ensembl/"
            result = result + datetime.now().strftime('%Y_%m')
            return result
    