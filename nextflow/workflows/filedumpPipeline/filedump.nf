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

process DumpFastaFiles {

  debug 'ture'
  label 'mem20GB'
  tag 'dump_fasta'
  errorStrategy 'finish'
  publishDir "${params.output}"

  input:
  each db_name

  output:
  path "${db_name}.log"

  """
  
  export PYTHONPATH="${params.base_dir}ensembl-production/src/python" 
  export SPARK_LOCAL_IP="127.0.0.1"

  ${params.nf_py_script_path}/dump_fasta.py --base_dir=${params.base_dir}\
   --username ensadmin --password  --dest "$BASE_DIR/test-out/"\
   --db jdbc:mysql://mysql-ens-core-prod-1:4524/mus_musculus_casteij_core_114_2

  """

}

process CleanFiles {

  debug 'ture'
  label 'mem4GB'
  tag 'cleanemptyfiles'
  errorStrategy 'finish'
  publishDir "${params.output}", mode: 'copy', overWrite: true 

  input:
  val output
  val outputfiles

  output:
  path "cleanupfiles.log"

  """
  #!/usr/bin/env python
  import os
  import logging
  import glob

  #set nextflow params
  OUTPUT  = "$output"

  #set a log file name
  logging.basicConfig(
        filename=f"cleanupfiles.log",
        filemode='w',
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S')

  logger = logging.getLogger("${params.release}")
  file_list = glob.glob(os.path.join(OUTPUT, 'checkftpfile*'))
  for file_path in file_list:
      if os.path.exists(file_path) and os.path.isfile(file_path) and os.path.getsize(file_path) == 0:
          os.remove(file_path)
          logger.info(f"Removed empty log {file_path}")  
  """ 

}