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

process DB_COPY_SUBMIT {

    input:
    val db_name

    output:
    tuple path('job_id.txt'), val(db_name), emit: job_info_ch

    script:
    api_url="https://services.ensembl-production.ebi.ac.uk/api/dbcopy/requestjob"
    source_db="${params.source_host}:${params.source_port}"
    target_db="${params.target_host}:${params.target_port}"

    println "Submitting dbcopy job for $db_name"

    """
    # Submit the job via dbcopy-client
    dbcopy-client -u $api_url -a submit -s $source_db -t $target_db -i $db_name -n ${db_name}_tmp -e $params.email -r $params.user --wipe_target 1 --skip-check &> out.log

    # sleep to allow file to be created
    sleep 10

    # Extract the job id
    job_id=\$(grep -o '[0-9a-f\\-]\\{36\\}' out.log)
    echo \$job_id > job_id.txt
    """
}