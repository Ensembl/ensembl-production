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

    // publishDir "sql/${db_name}", mode: 'copy', overwrite: true  // Publish SQL files to 'sql' directory

    input:
    tuple val(job_id), val(db_name) // Get job ID and db name from job_info_ch

    output:
    path "${db_name}.sql", emit: sql_output_file  // Output pattern to capture SQL files

    script:
    println "Generating SQL for db: ${db_name}"
    """
    # add max package size to account for dna db table size
    mysqldump --max-allowed-packet=2048M --opt --quick -h ${params.target_host} -P ${params.target_port} -u ensro ${db_name}_tmp > ${db_name}.sql
    
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