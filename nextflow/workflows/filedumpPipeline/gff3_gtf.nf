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

process DumpGFF3_GTFFiles {

  debug 'true'
  label 'mem20GB'
  errorStrategy 'finish'
  tag "${db_name}-dump_gff-gtf"
  publishDir "${params.ftp_path}/${output_folder}/genset", mode: 'copy'
  maxForks 1

  input: 
  val dataset
  val output_folder
  path feature_seq

  output:
  path "test_gff.gff"
  path "test_gtf.gtf"

  script:
  jsonS = new JsonSlurper()
  confJson = jsonS.parseText(dataset)
  species = confJson.species
  db_name = confJson.dataset_source

  //Sequence parameter is a folder where fasta build saves sequence. So it is just database name folder in working dir
  //Dont change it until it complies with fasta dump
  """
  export PYTHONPATH="$BASE_DIR/ensembl-production/src/python" 
  ${params.nf_py_script_path}file_dump/dump_gff3_gtf.py --base_dir=${BASE_DIR}\
   --username ${params.user} --sequence ${feature_seq} --password ${params.password}  --db ${params.server}/${db_name} --species ${species} 
  """
}
