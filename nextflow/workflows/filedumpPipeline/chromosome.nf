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
import groovy.json.JsonSlurper

process DumpChromosomeFile {

  debug 'ture'
  label 'mem2GB'
  tag "${db_name}-dump_xref"
  errorStrategy 'finish'
  publishDir "${params.ftp_path}/${db_name}", mode: 'copy', overWrite: true
  maxForks 1
  
  input: 
  val dataset

  output:
  path "chromosomes.tsv", optional: true

  script:
  jsonS = new JsonSlurper()
  confJson = jsonS.parseText(dataset)
  species = confJson.species
  db_name = confJson.dataset_source

  """
  ${params.nf_py_script_path}file_dump/dump_chromosome.py --base_dir=${BASE_DIR}\
   --username ${params.user} --password ${params.password} --db ${params.server}/${db_name} --species ${species}

  """
}
