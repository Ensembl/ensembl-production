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
process GenerateFolderStructure {

  debug 'true'
  label 'mem1GB'
  errorStrategy 'finish'
  tag "${db_name}-generate-folder-structure"
  
  input: 
  val dataset

  output:
  val "${dataset}"
  stdout

  script:
  jsonS = new JsonSlurper()
  def confJson = jsonS.parseText(dataset)
  species = confJson.species
  db_name = confJson.dataset_source
  """${params.nf_py_script_path}file_dump/generate_output_path.py --species ${species}  --username ${params.user} --password ${params.password} --db ${params.server}/${db_name}"""
}
