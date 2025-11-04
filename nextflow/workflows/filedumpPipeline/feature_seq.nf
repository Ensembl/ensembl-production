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

process BuildFeatureSequence {

  debug 'true'
  label 'mem20GB'
  errorStrategy 'finish'
  tag "${db_name}-feature_sequence_build"
  publishDir "${params.ftp_path}/${output_dir}", mode: 'copy'
  maxForks 1

  input: 
  each db_name
  path output_dir
  path top_level_dir

  output:
  stdout
  path "${output_dir}"
  path "${top_level_dir}"
  path "${db_name}/${params.feature_seq_dir}"


  //Sequence parameter is a folder where fasta build saves sequence. So it is just database name folder in working dir
  //Dont change it until it complies with fasta dump
  """
  export PYTHONPATH="$BASE_DIR/ensembl-production/src/python" 
  export SPARK_LOCAL_IP="127.0.0.1"
  ${params.nf_py_script_path}file_dump/feature_sequence_build.py --base_dir=${BASE_DIR}\
   --username ${params.user} --password ${params.password}  --db ${params.server}/${db_name} --top_level_seq ${top_level_dir} --output_dir ${db_name}/${params.feature_seq_dir} && echo -n ${db_name}
  """
}
