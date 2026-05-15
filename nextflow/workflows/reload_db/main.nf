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

process CHECK_ARCHIVES {
    input:
    path archive_path

    output:
    path "*.bz2", emit: sql_archive_ch
    path "archive_list.txt"

    script:
    """
    ls ${archive_path}/*.bz2 > archive_list.txt
    """
}

process DECOMPRESS_SQL {

    publishDir params.temp_dir, mode: 'copy', overwrite: true

    input:
    path sql_archive

    output:
    path "*.sql", emit: sql_output_file

    script:
    """
    mkdir -p ${params.temp_dir}
    echo "Decompressing ${sql_archive}..."
    # decompress and keep original archived file
    bzip2 -dk ${sql_archive} -c > \$(basename ${sql_archive} .bz2)
    """
}

process PREPARE_DB {
    input:
    path db_file

    output:
    path(db_file), emit: prepare_db_out

    script:
    // def db_name = db_file.baseName // can't use this because it goes out of scope for some reason
    // println "Attempting to CREATE DATABASE for file: ${db_file}..."
    """
    echo "nat_${db_file.baseName}"

    echo "Attempting to CREATE DATABASE for file: ${db_file}..."
    echo "Preparing database: nat_${db_file.baseName} for host:port ${params.target_host}:${params.target_port}"

    # Drop and create the database
    #mysql -h ${params.target_host} -P ${params.target_port} -u ${params.user} -p${params.password} \
        -e "DROP DATABASE IF EXISTS nat_${db_file.baseName}; CREATE DATABASE nat_${db_file.baseName};"
    mysql -h ${params.target_host} -P ${params.target_port} -u ${params.dba_user} -p${params.dba_pwd} \
        -e "DROP DATABASE IF EXISTS nat_${db_file.baseName}; CREATE DATABASE nat_${db_file.baseName};"
    """
}

process RESTORE_DB {
    input:
    path(db_file)

    // output:
    // val db_file.baseName, emit: restored_db_ch

    script:
    def db_name = "nat_${db_file.baseName}"
    """
    filename=\$(basename "${db_file}")
    echo \$filename
    db_name="nat_\${filename%.sql}"

    echo "Restoring database: ${db_name} with file: ${db_file}"
    mysql -h ${params.target_host} -P ${params.target_port} -u ${params.dba_user} -p${params.dba_pwd} ${db_name} < ${db_file}
    
    echo \${db_name} > db_name.txt
    """
}

process VERIFY_RESTORE {

    publishDir "db_checks/", mode: 'copy', overwrite: true

    input:
    val db_name

    output:
    path "verification_${db_name}.txt"

    script:
    """
    echo "Verifying database: ${db_name}"

    output_file="verification_${db_name}.txt"

    # Print out header to file
    echo "Table Row Counts for ${db_name}" > \$output_file
    echo "===================================" >> \$output_file

    # is there a better check to do - count rows in each table?
    #mysql -h ${params.target_host} -P ${params.target_port} -u ${params.user} -p${params.password} \
        -e "SHOW TABLES;" ${db_name}

    # Count rows in key tables
    mysql -h ${params.target_host} -P ${params.target_port} -u ${params.user} -p${params.password} -D ${db_name} -e "
    SELECT table_name, table_rows 
    FROM information_schema.tables 
    WHERE table_schema = '${db_name}';
    " >> \$output_file

    echo "Verification completed."
    """
}

process NOTIFY_RESTORE {
    input:
    val db_name

    script:
    """
    echo "Restoration complete for database: ${db_name}"
    """
}


workflow {

    // Create channel of dbs to reload from user list
    println "Creating channel from bz2 files found in ${params.archive_path}..."
    Channel
        .fromPath("${params.archive_path}/*.bz2")
        .view()
        .set { archive_ch }

    file_count = archive_ch.count()
    println "Found ${file_count} archived dbs to restore."

    // 1. Check and list compressed files
    // check_archive_ch = CHECK_ARCHIVES( archive_ch )

    // 2. Decompress files
    decompressed_files_ch = DECOMPRESS_SQL( archive_ch )

    decompressed_files_ch.view()

    // // 3. Prepare/create the target database
    PREPARE_DB( decompressed_files_ch )

    // // 4. Restore the database
    // restored_db_ch = decompressed_files_ch.combine(prepared_db_ch) | RESTORE_DB()
    RESTORE_DB( PREPARE_DB.out.prepare_db_out )

    // // 5. Verify the restored database with show tables - better way?
    // VERIFY_RESTORE( RESTORE_DB.out.restored_db_ch )

    // // Optional: Notify user
    // restored_db_ch | NOTIFY_RESTORE()
}
