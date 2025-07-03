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

process GENERATE_SQL {

    tag "$db_name"

    //publishDir "sql/${db_name}", mode: 'copy', overwrite: true  // Publish SQL files to 'sql' directory

    input:
    tuple val(job_id), val(db_name), val(genome_uuid) // Get job ID and db name from job_info_ch

    // output:
    // path "${db_name}.pre_stats.txt", emit: pre_stats
    // path "${db_name}.dump_check.txt", emit: dump_check
    // path "${db_name}.table_row_counts.txt", emit: table_row_counts

    output:
    tuple val(db_name), path("${db_name}.sql"), path("${db_name}.table_row_counts.txt"), val(genome_uuid), emit: sql_outputs
    path "${db_name}.sql", emit: sql_output_file  // Output from sql file dump
    path "${db_name}.dump_check.txt", emit: dump_check
    // path "${db_name}.table_row_counts.txt", emit: table_row_counts
    path "${db_name}.pre_stats.txt", emit: pre_table_count


    script:
    println "Generating SQL for db: ${db_name}"
    """
    # Determine host and port based on mode
    if [ "${params.skip_dbcopy}" == "true" ]; then
        db_host="${params.source_host}"
        db_port="${params.source_port}"
    else
        db_host="${params.target_host}"
        db_port="${params.target_port}"
    fi

    echo "Connecting to \$db_host:\$db_port"

    # Pre-dump stats
    mysql -h \$db_host -P \$db_port -u ensro -N -e \\
        "SELECT COUNT(*) AS table_count FROM information_schema.tables WHERE table_schema = '${db_name}';" > ${db_name}.pre_stats.txt

    # Get list of tables in the database
    tables=\$(mysql -h \$db_host -P \$db_port -u ensro -N -e "SHOW TABLES IN ${db_name};")

    # Loop through each table and get the exact row count
    #echo "Table row counts:" > ${db_name}.table_row_counts.txt
    for table in \$tables; do
        row_count=\$(mysql -h \$db_host -P \$db_port -u ensro -N -e "SELECT COUNT(*) FROM ${db_name}.\$table;")
        echo "\$table \$row_count" >> ${db_name}.table_row_counts.txt
    done
    
    # add no-defaults flag to avoid column-statistics error with user ensemblftp
    # add max package size to account for dna db table size
    mysqldump --no-defaults --max-allowed-packet=2048M --opt --quick -h \$db_host -P \$db_port -u ensro ${db_name} > ${db_name}.sql

    # Check end of the SQL file
    if tail -n 1 ${db_name}.sql | grep -q '^-- Dump completed on'; then
        echo "Dump completed successfully" > ${db_name}.dump_check.txt
    else
        echo "ERROR: Dump did not complete as expected" > ${db_name}.dump_check.txt
        exit 1  # Exit the entire workflow if the dump isn't complete
    fi

    # add sleep to let file system finish file dump
    sleep 180
    """
    // Keep this table-based code in case we want to bring this back at later date
    // # For each table found in the db, dump it out to file
    // for table in \$(mysql -h ${params.target_host} -P ${params.target_port} -u ensro -N -e 'SHOW TABLES' ${db_name}_tmp); do
    //     mysqldump --max-allowed-packet=1G --column-statistics=0 -h ${params.target_host} -P ${params.target_port} -u ensro --routines --triggers --add-drop-table ${db_name}_tmp \${table} > \${table}.sql
    //     #mysqldump --max-allowed-packet=1G --column-statistics=0 -h ${params.target_host} -P ${params.target_port} -u ensro --no-create-info ${db_name}_tmp \${table} > \${table}.sql
    // done
    // """
}