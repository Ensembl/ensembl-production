process SolrDumps {
    /*
      Description: Extract  genomic feature from ensembl core databases
    */

    debug "${params.debug}"
    label 'mem8GB'
    cpus '4'
    tag "${genome['species']}_${genome['genome_uuid']}"

    publishDir "${params.solr_data_location}", mode: 'copy', overWrite: true

    input:
      val core_host_uri
      val genome

    script:
      genome_uuid     = genome['genome_uuid']
      species         = genome['species']
      assembly        = genome['assembly_name']
      division        = genome['division']
      database_name   = genome['database_name']
      core_db_uri     = core_host_uri.endsWith('/') ? "${core_host_uri}${database_name}" : "${core_host_uri}/${database_name}"
      output_filename = "${genome['genome_uuid']}_toplevel_solr.json"

    """
     echo Start solr dumps for $species
     pyenv local production-pipeline-env
     python ${params.nf_py_script_path}/genesearch_solr.py \
     --genome_uuid $genome_uuid \
     --species $species  \
     --division $division \
     --core_db_uri $core_db_uri \
     --output $output_filename
    """
    output:
       path "${output_filename}"
}

process SolrIndex {
    /*
      Description: Load genenames into solr
    */

    debug "${params.debug}"
    label 'mem2GB'
    cpus '1'
    tag "${index_json_file}-${solr_collection}"

    input:
      path index_json_file
      each solr_host
      val solr_collection

    """
     echo Start index solr data for $index_json_file
     pyenv local production-pipeline-env
     echo $index_json_file $solr_host $solr_collection
     python ${params.nf_py_script_path}/index_solr_data.py \
     --solr_file $index_json_file \
     --solr_host $solr_host \
     --solr_collection $solr_collection
    """
}