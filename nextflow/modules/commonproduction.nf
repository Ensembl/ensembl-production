process SpeciesFactory {
  input:
  each x
 
  output:
  path 'dataflow_2.json'
 
  """
  perl ${params.pipeline_dir}/run_process.pl -class='Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory' -dataflow='$x' -reg_conf=${params.registry}
  """
}

process DbAwareSpeciesFactory {
  input:
  each x

  output:
  path 'dataflow_2.json'

  """
  perl ${params.pipeline_dir}/run_process.pl -class='Bio::EnsEMBL::Production::Pipeline::Common::DbAwareSpeciesFactory' -dataflow='$x' -reg_conf=${params.registry}
  """
}

process DbFactory {
 
  output:
  path 'dataflow_2.json'
 
  """
  perl ${params.pipeline_dir}/run_process.pl -class='Bio::EnsEMBL::Production::Pipeline::Common::::DbFactory' -reg_conf=${params.registry} -species=${params.species} -antispecies=${params.antispecies} -division=${params.division} -run_all=${params.run_all} -dbname=${params.dbname} -meta_filters=${params.meta_filters}
  """
}
