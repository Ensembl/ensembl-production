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

process GenomeInfo {
    /*
      Description: Fetch the genome information from the ensembl production metadata-api
      Input:
            genome_uuid         (list): genome Universally Unique IDentifier. Defaults to [].
            species_name        (list): Ensembl Species Name. Defaults to [].
            organism_group      (list): Ensembl species Divisions. Defaults [].
            unreleased_datasets (bool): Fetch genomes UUID for unreleased dataset. Default True 
            dataset_topic       (str) : dataset topic name to fetch the unique genome ids Default 'assembly'
            metadata_uri        (str, Required): Mysql URI string to connect the metadata database.
            taxonomy_uri        (str, Required): Mysql URI string to connect the ncbi taxonomy db.
            output_json         (str, Required): path to genome info json file 

      Output:
          String: Json file with genome information 
    */

    debug "${params.debug}"  
    label 'mem4GB'
    tag 'genomeinfo'
  
    input:
    val genome_uuid
    val species_name
    val organism_group
    val unreleased_genomes
    val dataset_type
    val metadata_uri
    val taxonomy_uri
    val output_json
    
    output:
    path "$output_json"

  script :
  def metadata_db_uri          =  metadata_uri ? "--metadata_db_uri $metadata_uri" : '' 
  def taxonomy_db_uri          =  taxonomy_uri ? "--taxonomy_db_uri $taxonomy_uri" : ''
  def genome_uuid_param        =  genome_uuid.size() > 0 ?  "--genome_uuid ${genome_uuid.join(" ")}" : ''             
  def species_name_param       =  species_name.size() > 0 ?  "--species_name ${species_name.join(" ")}" : ''        
  def organism_group_param     =  organism_group.size() > 0 ?  "--organism_group ${organism_group.join(" ")}" : ''        
  def unreleased_genomes_param =  unreleased_genomes ? "--unreleased_genomes" : ''         
  def dataset_type_param       =  dataset_type.size() > 0 ?  "--dataset_name ${dataset_type.join(" ")}" : ''        
  
  """
  pyenv local production-nextflow-py-3.8

  ${params.nf_py_script_path}/genome_info.py \
    $metadata_db_uri $taxonomy_db_uri $genome_uuid_param $species_name_param $organism_group_param \
    $unreleased_genomes_param $dataset_type_param -o $output_json
  """
}
