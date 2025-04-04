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

process DumpGFF3_GTFFiles {

  debug 'true'
  label 'mem20GB'
  tag '${db_name}-dump_gff'
  errorStrategy 'finish'
  publishDir "${params.output}"

  input:
  each db_name

  output:
  path "${db_name}.log"

  """
  export PYTHONPATH="$BASE_DIR/ensembl-production/src/python" 
  export SPARK_LOCAL_IP="127.0.0.1"

  ${params.nf_py_script_path}file_dump/dump_gff3_gtf.py --base_dir=${BASE_DIR}\
   --username ${params.user} --password ${params.password} --dest "${params.ftp_path}"\
   --db ${params.server}/${db_name} > ${db_name}.log

  """
}
