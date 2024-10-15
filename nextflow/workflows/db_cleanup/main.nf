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

// modules to include
include { DB_COPY_SUBMIT } from '../../modules/db_cleanup/db_copy_submit.nf'
include { MONITOR_DB_COPY } from '../../modules/db_cleanup/monitor_db_copy.nf'
include { GENERATE_SQL } from '../../modules/db_cleanup/generate_sql.nf'
include { COMPRESS_FILE } from '../../modules/db_cleanup/compress_file.nf'

// nf-schema-related modules
include { validateParameters; paramsSummaryLog; samplesheetToList } from 'plugin/nf-schema'

// Validate input parameters
validateParameters()

// Print summary of supplied parameters
// via nf-schema plugin
log.info paramsSummaryLog(workflow)

// default params
// params.source_host = ""
// params.source_port = ""
// params.db_list = []
// params.target_host = "mysql-ens-core-prod-1"
// params.target_port = "4524"
// params.target_path = ""
// params.drop_db = false
// params.email = ""
// params.user = ""

log.info """\

    INFO ON PARAMETERS CURRENTLY SET:

    General parameters
    ==================
    workDir                 : ${workDir}
    launchDir               : ${launchDir}
    projectDir              : ${projectDir}
    email address for HPC   : ${params.email}
    user                    : ${params.user}
    target path for output  : ${params.target_path}

    Database parameters
    ===================
    db list                 : ${params.db_list}
    source db host          : ${params.source_host}
    source db port          : ${params.source_port}
    target db host          : ${params.target_host}
    target db port          : ${params.target_port}
    drop source db at end   : ${params.drop_db}

    """
    .stripIndent(true)



// Process not currently in use as changed to using single file
// for whole db, so no longer archiving a group of table sql files.
// Leaving here in case need it in future - needs testing before
// moving to own module file.
process TAR_COMPRESSED_SQL {

    input:
    path compressed_sql_list  // The list of compressed SQL files
    tuple val(job_id), val(db_name) // Get job ID and db name


    output:
    path "${db_name}.tar.bz2"  // The final tar.bz2 archive

    script:
    // Print a message to inform the user about the archiving
    println "Archiving SQL files for database: ${db_name}"
    println "Compressed files: ${compressed_sql_list.join(', ')}"
    println "Creating archive: ${db_name}_archive.tar.bz2"
    """
    # Create a tar archive with all the compressed SQL files
    tar -cjf ${db_name}.tar.bz2 ${compressed_sql_list.join(' ')}
    """
}

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



workflow {

    main:

        // Print the raw db_list to ensure it's being passed properly
        println "Raw params.db_list: ${params.db_list}"

        // Check if params.db_list is null or empty
        if (params.db_list == null || params.db_list == '') {
            println "ERROR: params.db_list is null or empty"
            exit 1
        }

        // Split the string into a list and print it
        db_list = params.db_list.split(',')
        println "Split db_list: ${db_list}"

        // Check if the split resulted in an empty list
        if (db_list.size() == 0) {
            println "ERROR: db_list is empty after split"
            exit 1
        }

        // Create channel of dbs to copy from user list
        // Set the channel to a variable for use in DB_COPY
        Channel
            .from(db_list)
            .view()
            .set { db_names_ch }

        // Submit the db copy job(s)
        result = DB_COPY_SUBMIT(db_names_ch)

        // Extract the job id and map to db name
        DB_COPY_SUBMIT.out.job_info_ch
        .map { job_id_file, db_name ->  
            def job_id = job_id_file.text.trim()  // Read and trim the contents of job_id.txt
            tuple(job_id, db_name)  // Return the tuple (job_id, db_name)
        }
        .set { job_info_mapped_ch }

        // View the mapped channel contents
        job_info_mapped_ch.view()

        // Monitor the db copy job
        MONITOR_DB_COPY(job_info_mapped_ch)

        // Generate SQL files
        GENERATE_SQL(MONITOR_DB_COPY.out.monitored_job)

        // View the generated files
        GENERATE_SQL.out.sql_output_file.view()

        // Compress the SQL file
        // also outputs compressed file to final storage path
        compressed_sql_ch = COMPRESS_FILE(GENERATE_SQL.out.sql_output_file)

        // Cleanup the temp db created by this pipeline
        CLEANUP_TMP_DB(compressed_sql_ch, MONITOR_DB_COPY.out.monitored_job)
}
