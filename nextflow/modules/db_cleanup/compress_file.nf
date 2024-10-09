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

process COMPRESS_FILE {

    // get working and then check which compression method to use

    // copies compressed file to user-provided target path
    publishDir params.target_path, mode: 'copy', overwrite: true

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