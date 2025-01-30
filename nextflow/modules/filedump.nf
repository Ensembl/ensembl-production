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
  #!/usr/bin/env python3

  import logging
  import os
  import sys
  import configparser
  import json
  import glob

  #set nextflow params
  DB_NAME   = "$db_name"
  CONF_FILE = "${params.conf_file}"
  FTP_PATH  = "${params.ftp_path}"
  USER  = "${params.user}"
  PASSWORD  = "${params.password}"
  SERVER  = "${params.server}"

  print(DB_NAME)
  #read config file
  config_details = configparser.ConfigParser()
  config_details.read(CONF_FILE)

  #read config file
  config_details = configparser.ConfigParser()
  config_details.read(CONF_FILE)

  #set a log file name
  logging.basicConfig(
      filename=f"${db_name}.log",
      filemode='w',
      level=logging.INFO,
      format='%(asctime)s - %(levelname)s - %(message)s',
      datefmt='%Y-%m-%d %H:%M:%S')

  logger = logging.getLogger("${params.release}")

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