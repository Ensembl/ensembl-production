process GenerateThoasConfigFile {
    /*
      Description: Generate Thoas loading config ini file with general and genome information  
    */

    debug "${params.debug}"  
    label 'mem4GB'
    tag 'thoasConfig'
    publishDir "${params.thoas_data_location}", mode: 'copy', overWrite: true
     

    input:
    path genome_info

    output:
    path "${params.thoas_config_filename}"

    """
    #Script to prepare thoas load-<ENS_VERSION>.conf file 
    ${params.nf_py_script_path}/generate_thoas_conf.py \
     -i $genome_info \
     -o ${params.thoas_config_filename} \
     --release ${params.release} \
     --thoas_code_location ${params.thoas_code_location} \
     --thoas_data_location ${params.thoas_data_location} \
     --base_data_path ${params.base_data_path} \
     --grch37_data_path ${params.grch37_data_path} \
     --classifier_path ${params.classifier_path} \
     --chr_checksums_path ${params.chr_checksums_path} \
     --xref_lod_mapping_file ${params.xref_lod_mapping_file} \
     --core_db_host ${params.core_db_host} \
     --core_db_port ${params.core_db_port} \
     --core_db_user ${params.core_db_user} \
     --metadata_db_host ${params.metadata_db_host} \
     --metadata_db_port ${params.metadata_db_port} \
     --metadata_db_user ${params.metadata_db_user}  \
     --metadata_db_dbname ${params.metadata_db_dbname}  \
     --taxonomy_db_host ${params.metadata_db_host} \
     --taxonomy_db_port ${params.metadata_db_port} \
     --taxonomy_db_user ${params.metadata_db_user}  \
     --taxonomy_db_dbname ${params.taxonomy_db_dbname}  \
     --refget_db_host ${params.refget_db_host} \
     --refget_db_port ${params.refget_db_port} \
     --refget_db_dbname ${params.refget_db_dbname} \
     --refget_db_user ${params.refget_db_user} \
     --refget_db_password ${params.refget_db_password} \
     --mongo_db_host ${params.mongo_db_host} \
     --mongo_db_port ${params.mongo_db_port} \
     --mongo_db_dbname ${params.mongo_db_dbname} \
     --mongo_db_user ${params.mongo_db_user} \
     --mongo_db_password ${params.mongo_db_password} \
     --mongo_db_schema ${params.mongo_db_schema} \
     --mongo_db_collection ${params.mongo_db_collection}
    """

}


process LoadThoas {
    /*
      Description: Load  genome data into mongodb collection for thoas
    */

    debug "${params.debug}"  
    label 'mem16GB'
    cpus '12'
    tag 'thoasloading'

    publishDir "${params.thoas_data_location}", mode: 'copy', overWrite: true

    input:
    //path thoas_config_file
    val genome_info
 
    //output:
    //path "loading_log_${params.release}.out"

    """
    pyenv local production-nextflow-py-3.8
    export META_CLASSIFIER_PATH=${params.thoas_code_location}/metadata_documents/metadata_classifiers/
    echo JHIIIIIIIIIIIIIIIIIIIIIIIIIIIi 
     echo $genome_info
    """

}
