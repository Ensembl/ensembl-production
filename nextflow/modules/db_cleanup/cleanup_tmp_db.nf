// See the NOTICE file distributed with this work for additional information
// regarding copyright ownership.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

nextflow.enable.dsl=2

process CLEANUP_TMP_DB {

    input:
    path compressed_file
    tuple val(job_id), val(db_name)

    script:
    """
    tmp_db_name="${db_name}_tmp"
    echo "Attempting to drop database \${tmp_db_name} if it exists..."

    mysql -h $params.target_host -P $params.target_port -u $params.dba_user -p$params.dba_pwd -e "DROP DATABASE IF EXISTS \${tmp_db_name};"

    echo "Drop operation complete."
    """
}