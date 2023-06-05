process DbAwareSpeciesFactory {
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

process SpeciesFactory {
  debug 'ture'
  label 'mem2GB'
  tag 'DbFactory'

  input:
  val division

  output:
  val division // place holder to set the array from 1 to 7 as per the standard flows
  path 'dataflow_1.json' // all species flow 
  path 'dataflow_2.json', optional: true // core flow 
  path 'dataflow_3.json', optional: true // chromosome flow 
  path 'dataflow_4.json', optional: true // variation flow 
  path 'dataflow_5.json', optional: true // comapra flow 
  path 'dataflow_6.json', optional: true // regulation flow
  path 'dataflow_7.json', optional: true // otherfeatures flow

  """
  perl ${params.pipeline_dir}/run_process.pl -class='Bio::EnsEMBL::Nextflow::SpeciesFactory' -reg_conf=${params.registry} -species=${params.species} -antispecies=${params.antispecies} -division=$division -dbname=${params.dbname} -meta_filters=${params.meta_filters}
  """
}

process DbFactory {
  debug 'ture'
  label 'mem2GB'
  tag 'DbFactory'

  input:
  val division

  output:
  path 'dataflow_2.json'
 
  """
  perl ${params.pipeline_dir}/run_process.pl -class='Bio::EnsEMBL::Nextflow::DbFactory' -reg_conf=${params.registry} -species=${params.species} -antispecies=${params.antispecies} -division=$division -run_all=${params.run_all} -dbname=${params.dbname} -meta_filters=${params.meta_filters}
  """
}
