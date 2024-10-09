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

// default params
params.source_host = ""
params.source_port = ""
params.db_list = []
params.target_host = "mysql-ens-core-prod-1"
params.target_port = "4524"
params.target_path = ""
params.drop_db = false
params.email = ""
params.user = "ensro"

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

// process EXTRACT_JOB_ID {

//     input:
//     val db_name
//     path job_id_file

//     output:
//     tuple val(job_id_value), val(db_name), emit: job_info_ch

//     script:
//     // """
//     // # Read the job ID from the job_id_file
//     // #job_id_value=\$(cat $job_id_file)
//     // #echo "Job ID: \$job_id_value"
//     // """
//     // Define a Groovy variable to hold the job ID
//     // Convert job_id_file (which is a path) to a Groovy File object and read its contents
//     def job_id_value = job_id_file.newReader().text.trim()  // New unique variable name
//     println "Job ID: $job_id_value" // Print the job ID for debugging
// }

process MONITOR_DB_COPY {

    input:
    tuple val(job_id), val(db_name) // Get job ID and db name from the previous process

    output:
    tuple val(job_id), val(db_name), emit: monitored_job

    script:
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


process GENERATE_SQL {

    publishDir "sql/${db_name}", mode: 'copy', overwrite: true  // Publish SQL files to 'sql' directory

    input:
    tuple val(job_id), val(db_name) // Get job ID and db name from job_info_ch

    output:
    path "${db_name}.sql", emit: sql_output_file  // Output pattern to capture SQL files

    script:
    println "Generating SQL for db: ${db_name}"
    """
    # add max package size to account for dna db table size
    mysqldump --max-allowed-packet=2048M --opt --quick --skip-column-statistics -h ${params.target_host} -P ${params.target_port} -u ensro ${db_name}_tmp > ${db_name}.sql
    sleep 180
    """
    // # For each table found in the db, dump it out to file
    // for table in \$(mysql -h ${params.target_host} -P ${params.target_port} -u ensro -N -e 'SHOW TABLES' ${db_name}_tmp); do
    //     mysqldump --max-allowed-packet=1G --column-statistics=0 -h ${params.target_host} -P ${params.target_port} -u ensro --routines --triggers --add-drop-table ${db_name}_tmp \${table} > \${table}.sql
    //     #mysqldump --max-allowed-packet=1G --column-statistics=0 -h ${params.target_host} -P ${params.target_port} -u ensro --no-create-info ${db_name}_tmp \${table} > \${table}.sql
    // done
    // """
}

process COMPRESS_FILES {

    // get working and then check which compression method to use

    publishDir "zip/", mode: 'copy', overwrite: true

    input:
    path sql_file

    output:
    path "${sql_file}.bz2", emit: compressed_sql_ch  // Output compressed table-named file into a channel

    script:
    println "Compressing file: ${sql_file}"

    """
    # Ensure the file is copied to the current work dir, not linked
    cp ${sql_file} ./temp_file.sql

    # Compress the file
    #bzip2 \$(realpath temp_file.sql)
    bzip2 temp_file.sql

    # Rename file
    mv temp_file.sql.bz2 ${sql_file}.bz2
    """
}

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

        // sql_file_ch = Channel.of("sql/${db_name}/${db_name}.sql")

        GENERATE_SQL.out.sql_output_file.view()

        // Compress the SQL files
        compressed_sql_ch = COMPRESS_FILES(GENERATE_SQL.out.sql_output_file)
        // compressed_sql_ch = COMPRESS_FILES(sql_file_ch)

        // Collect the compressed SQL files into a list
        // compressed_sql_list = compressed_sql_ch.collect() 

        // compressed_sql_list.view()

        // archive the SQL files
        // TAR_COMPRESSED_SQL(compressed_sql_list, job_info_mapped_ch)

        // move archives to final storage path
        // use the datamover queue for copying things over?
}
