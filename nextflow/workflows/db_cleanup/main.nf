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
include { CLEANUP_TMP_DB } from '../../modules/db_cleanup/cleanup_tmp_db.nf'
include { DROP_SOURCE_DB } from '../../modules/db_cleanup/drop_source_db.nf'

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
    drop source db at end   : ${params.drop_source_db}

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


process GET_GENOME_UUID {
    
    input:
    tuple val(job_id), val(db_name)
    
    output:
    tuple val(job_id), val(db_name), path('genome_uuid.txt')
    
    script:
    """
    if [[ "${db_name}" == *"_core_"* ]]; then
        echo "Core database detected: ${db_name}" >&2
        
        # Query the meta table for genome_uuid
        genome_uuid=\$(mysql -h ${params.source_host} -P ${params.source_port} \\
            -u ensro \\
            -N -e "SELECT meta_value FROM ${db_name}.meta WHERE meta_key='genome.genome_uuid';" 2>/dev/null)
        
        if [[ -n "\$genome_uuid" && "\$genome_uuid" != "NULL" ]]; then
            echo "Found genome UUID: \$genome_uuid" >&2
            echo "\$genome_uuid" > genome_uuid.txt
        else
            echo "No genome UUID found, using database name" >&2
            echo "${db_name}" > genome_uuid.txt
        fi
    else
        echo "Non-core database detected: ${db_name}" >&2
        echo "core-like" > genome_uuid.txt
    fi
    """
}


process VERIFY_SQL_DUMP {

    // publishDir "${params.target_path}/db_archive/${db_name}/validation/", mode: 'copy', overwrite: true 
    publishDir "${params.target_path}/db_archive/${genome_uuid}/validation/", mode: 'copy', overwrite: true 


    // run process on cluster
    executor = 'slurm'
    queue = 'datamover'
    //clusterOptions = "--mail-type=END --mail-user=${params.email}"
    time = '24:00:00'
    memory = '4.GB'

    tag "$db_name"

    input:
    // tuple val(db_name), path(sql_file), path(orig_counts)
    tuple val(db_name), path(sql_file), path(orig_counts), val(genome_uuid)  // Add genome_uuid


    output:
    path("${db_name}.verify_status.txt"), emit: verify_status
    path("${db_name}.orig.sorted.txt")
    path("${db_name}.verify.sorted.txt")

    script:
    def restore_db = "${db_name}_verify"

    """
    echo "Restoring DB: ${restore_db}"

    # Drop and recreate the DB
    mysql -h ${params.verify_host} -P ${params.verify_port} -u ${params.verify_user} -p${params.verify_password} \\
        -e 'DROP DATABASE IF EXISTS ${restore_db}; CREATE DATABASE ${restore_db};'

    # Restore SQL dump into new DB
    mysql -h ${params.verify_host} -P ${params.verify_port} -u ${params.verify_user} -p${params.verify_password} \\
        ${restore_db} < ${sql_file}

    # Count rows from restored DB
    mysql -h ${params.verify_host} -P ${params.verify_port} -u ${params.verify_user} -p${params.verify_password} -N \\
        -e "SELECT table_name, table_rows FROM information_schema.tables WHERE table_schema = '${restore_db}';" \\
        > ${db_name}.verify_counts.txt

    # Normalize delimiters: convert all spaces or tabs to tabs consistently
    awk '{\$1=\$1; OFS="\\t"; print}' ${orig_counts} > ${db_name}.orig.normalized.txt
    awk '{\$1=\$1; OFS="\\t"; print}' ${db_name}.verify_counts.txt > ${db_name}.verify.normalized.txt

    # Sort normalized files
    sort ${db_name}.orig.normalized.txt > ${db_name}.orig.sorted.txt
    sort ${db_name}.verify.normalized.txt > ${db_name}.verify.sorted.txt

    # Compare counts
    if diff -q ${db_name}.orig.sorted.txt ${db_name}.verify.sorted.txt; then
        echo "VERIFY SUCCESS: ${db_name}" > ${db_name}.verify_status.txt
    else
        echo "VERIFY FAILED: ${db_name}" > ${db_name}.verify_status.txt
        exit 1
    fi

    # Drop the DB
    mysql -h ${params.verify_host} -P ${params.verify_port} -u ${params.verify_user} -p${params.verify_password} \\
        -e 'DROP DATABASE IF EXISTS ${restore_db};'
    """
}



workflow {

    main:

        // Print the raw db_list to ensure it's being passed properly
        println "Raw params.db_list: ${params.db_list}"

        // Split the string into a list and print it
        // db_list = params.db_list.split(',')
        db_list = file(params.db_list).text
        .split(',')              // Split by commas
        .collect { it.trim() }   // Trim whitespace from each element
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

        if (params.skip_dbcopy) {
            // If using source DB directly, skip copy
            println "Using source DB directly, skipping db copy"

            // sort out input for generating sql as expecting id and db_name
            db_names_ch
            .map { db_name -> tuple('NA', db_name) }
            .set { db_input_ch }

            db_input_ch.view()

            // Get archive directory for skip_dbcopy path
            GET_GENOME_UUID(db_input_ch)

            // After GET_GENOME_UUID, extract the UUID value
            GET_GENOME_UUID.out
            .map { job_id, db_name, uuid_file -> 
                def genome_uuid = uuid_file.text.trim()
                tuple(job_id, db_name, genome_uuid)
            }
            .set { genome_uuid_ch }

            genome_uuid_ch.view()

            // Generate SQL files directly from source
            // GENERATE_SQL(db_input_ch)
            GENERATE_SQL(genome_uuid_ch)

            // sql_output_ch = GENERATE_SQL.out.sql_output_file
            GENERATE_SQL.out.sql_outputs.view()
            
            // COMPRESS_FILE(GENERATE_SQL.out.sql_output_file)
            COMPRESS_FILE(GENERATE_SQL.out.sql_outputs)

            // No cleanup needed for temp DB in this mode

        } else {

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
            // leaving this here as needs doing before cleaning up tmp db
            // which only happens in this condition, so I can't move next step out
            // compressed_sql_ch = COMPRESS_FILE(GENERATE_SQL.out.sql_output_file)
            GENERATE_SQL.out.sql_outputs
                .map { it[1] }  // Get only the sql_file
                .set { sql_files_ch }

            COMPRESS_FILE(sql_files_ch)

            // Cleanup the temp db created by this pipeline
            CLEANUP_TMP_DB(compressed_sql_ch, MONITOR_DB_COPY.out.monitored_job)
        }

        // Output restored counts and compare counts for verification
        VERIFY_SQL_DUMP(GENERATE_SQL.out.sql_outputs)
}
