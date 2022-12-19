/*
	Sample Production Nextflow Workflow 
*/
num = Channel.of( 1, 2, 3 )

process CHECK_RELEASE_VERSION {
  debug true
  label "default_process"
  tag "Check release version" 

  script:
  """
  echo "Production Nextflow workflows \$ENS_VERSION \$EG_VERSION "
  """
}

process CHECK_DATA_MOVER {
  debug true
  label "dm"
  tag "Check datamover queue"

  script:
  """
  ls /nfs/ftp
  """
}


process BASICEXAMPLE {
  debug true
  penv 'production-tools' 
  label 'default_process'
  tag 'Test Prallel processing'

  input:
  val x

  script:
  """
  pyenv activate production-tools 
  echo process job $x
  dbcopy-client --help
  """
}

workflow {
  CHECK_RELEASE_VERSION() 
  CHECK_DATA_MOVER()
  BASICEXAMPLE(num)
}
