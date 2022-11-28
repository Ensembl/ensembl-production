process SpeciesFactory {
  label 'mem2GB'
  tag 'speciesFactory'
  input:
  each x
 
  output:
  path 'dataflow_2.json'
 
  """
  perl ${params.pipeline_dir}/run_process.pl -class='Bio::EnsEMBL::Nextflow::DbAwareSpeciesFactory' -dataflow='$x' -reg_conf=${params.registry}
  """
}

process DbFactory {
  debug 'ture'
  label 'mem2GB'
  tag 'DbFactory'

  output:
  path 'dataflow_2.json'
 
  """
  perl ${params.pipeline_dir}/run_process.pl -class='Bio::EnsEMBL::Nextflow::DbFactory' -reg_conf=${params.registry} -species=${params.species} -antispecies=${params.antispecies} -division=${params.division} -run_all=${params.run_all} -dbname=${params.dbname} -meta_filters=${params.meta_filters}
  """
}
