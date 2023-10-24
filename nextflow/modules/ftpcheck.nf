process CleanEmptyFiles {

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


process CheckFTPFiles {
  debug 'ture'
  label 'mem8GB'
  tag 'check_ftp_dumps'
  errorStrategy 'finish'
  publishDir "${params.output}"

  input:
  each species_info
  each division
  each filetype

  output:
  path "checkftpfile_${species}_${division}_${filetype}.log"

  shell:
  species =  (species_info =~ /"species":"([A-Za-z0-9_]+)",/)[0][1]

  """
  #!/usr/bin/env python

  import logging
  import os
  import sys
  import configparser
  import json
  import glob

  #set nextflow params
  SPECIES   = "$species"
  DIVISION  = "$division"
  CONF_FILE = "${params.conf_file}"
  FILE_TYPE = "$filetype"
  FTP_PATH  = "${params.ftp_path}"

  #read config file
  config_details = configparser.ConfigParser()
  config_details.read(CONF_FILE)

  #read config file
  config_details = configparser.ConfigParser()
  config_details.read(CONF_FILE)

  #set a log file name
  logging.basicConfig(
      filename=f"checkftpfile_{SPECIES}_{DIVISION}_{FILE_TYPE}.log",
      filemode='w',
      level=logging.INFO,
      format='%(asctime)s - %(levelname)s - %(message)s',
      datefmt='%Y-%m-%d %H:%M:%S')

  logger = logging.getLogger("${params.release}")


  #get the required files
  expected_files = config_details[FILE_TYPE]['expected_files'].format(species_uc=SPECIES.capitalize()).split(',')
  sub_path = config_details[FILE_TYPE]['path'].format(division=DIVISION, species_dir=SPECIES)

  for required_files in expected_files:
      file_name = os.path.join(FTP_PATH, sub_path, required_files)
      if len(glob.glob(file_name)) == 0 :
          logger.error(f"{FILE_TYPE}  Files Missing For Species {SPECIES} in path {file_name}")

  """

}





