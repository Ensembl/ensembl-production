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
process BuildTopLevelSequence {

  debug 'true'
  label 'mem20GB'
  errorStrategy 'finish'
  tag "${db_name}-top_level_sequence_build"
  publishDir "${params.output}/${species}", mode: 'copy'
  maxForks 1
  
  input: 
  val dataset
  val output_folder

  output:
  val "${dataset}"
  val "${output_folder}"
  path "${params.top_level_dir}"


  script:
  jsonS = new JsonSlurper()
  confJson = jsonS.parseText(dataset)
  species = confJson.species
  db_name = confJson.dataset_source

  """
  export SPARK_LOCAL_IP="127.0.0.1"
  ${params.nf_py_script_path}file_dump/top_level_sequence_build.py --base_dir=${BASE_DIR}\
   --username ${params.user} --password ${params.password}  --db ${params.server}/${db_name} --output_dir ${params.top_level_dir} --species ${species}
  """
}
