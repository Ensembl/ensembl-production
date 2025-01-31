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

process MONITOR_DB_COPY {

    // Get job ID and db name from the previous process
    input:
    tuple val(job_id), val(db_name)

    output:
    tuple val(job_id), val(db_name), emit: monitored_job

    script:
    println "Monitoring job id: ${job_id}"

    """
    # Define the API endpoint to check the status of the job
    api_url="https://services.ensembl-production.ebi.ac.uk/api/dbcopy/requestjob/${job_id}"
    
    # Set the interval for checking the status (e.g., every so many seconds)
    interval=60

    # Polling loop
    while true; do
        # Fetch job status
        status=\$(curl -s -X GET \$api_url | jq -r '.overall_status')

        # Print the status to the Nextflow log
        echo "Job ID: ${job_id} - Status: \$status"

        # Check if the job is completed or failed
        if [ "\$status" = "Complete" ]; then
            echo "Job ID: ${job_id} has completed."
            break
        elif [ "\$status" = "Failed" ]; then
            echo "Job ID: ${job_id} has failed."
            exit 1
        fi

        # Wait for the next interval before checking the status again
        sleep \$interval
    done
    """
}