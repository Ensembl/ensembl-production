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

/* use new genome factory */
process GenomeInfo {
  /*
    Description: Fetch the genome information from the ensembl production metadata-api
    Input:
      genome_uuid         (list): genome Universally Unique IDentifier. Defaults to [].
      species_name        (list): Ensembl Species Name. Defaults to [].
      organism_group      (list): Ensembl species Divisions. Defaults [].
      output_json         (str, Required): path to genome info json file
    Output:
        String: Json file with genome information
  */

    debug "${params.debug}"
    label 'mem4GB'
    tag 'genomeinfo'

    input:
    val metadata_db_uri
    val genome_uuid
    val dataset_uuid
    val organism_group_type
    val division
    val dataset_type
    val species
    val antispecies
    val dataset_status
    val update_dataset_status
    val batch_size
    val page
    val columns
    val output_json

    output:
    path "$output_json"

    script :
    def metadata_db_uri_param        =  metadata_db_uri ?                  "--metadata_db_uri $metadata_db_uri" : ''
    def genome_uuid_param            =  genome_uuid.size() > 0 ?           "--genome_uuid ${genome_uuid.join(" ")}" : ''
    def dataset_uuid_param           =  dataset_uuid.size() > 0 ?          "--dataset_uuid ${genome_uuid.join(" ")}" : ''
    def organism_group_type_param    =  organism_group_type.size() > 0 ?   "--organism_group_type ${organism_group_type.join(" ")}" : ''
    def division_param               =  division.size() > 0 ?              "--division ${division.join(" ")}" : ''
    def dataset_type_param           =  dataset_type ?                     "--dataset_type $dataset_type" : ''
    def species_param                =  species.size() > 0 ?               "--species ${species.join(" ")}" : ''
    def antispecies_param            =  antispecies.size() > 0 ?           "--antispecies ${antispecies.join(" ")}" : ''
    def dataset_status_param         =  dataset_status.size() > 0 ?        "--dataset_status ${dataset_status.join(" ")}" : ''
    def update_dataset_status_param  =  update_dataset_status ?            "--update_dataset_status $update_dataset_status" : ''
    def batch_size_param             =  batch_size > 0 ?                   "--batch_size $batch_size" : '--batch_size 0'
    def page_param                   =  page ?                             "--page $page" : ''
    def columns_param                =  columns.size() > 0 ?               "--columns ${columns.join(" ")}" : ''
    def output_json_param            =  output_json ?                      "--output $output_json" : '--output genome_info.json'

    """
    pyenv local production-pipeline-env
    ${params.nf_py_script_path}/genome_info.py $metadata_db_uri_param $genome_uuid_param $dataset_uuid_param \
    $organism_group_type_param $division_param $dataset_type_param $species_param \
    $antispecies_param $dataset_status_param $update_dataset_status_param $batch_size_param \
    $page_param $columns_param $output_json_param
    """
}
