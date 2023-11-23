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
     --mongo_db_host ${params.mongo_db_host} \
     --mongo_db_port ${params.mongo_db_port} \
     --mongo_db_dbname ${params.mongo_db_dbname} \
     --mongo_db_user ${params.mongo_db_user} \
     --mongo_db_password ${params.mongo_db_password} \
     --mongo_db_schema ${params.mongo_db_schema} \
     --mongo_db_collection ${params.mongo_db_collection}
    """
}

process LoadThoasMetadata {
    /*
      Description: Load  genome data into mongodb collection for thoas
    */

    debug "${params.debug}"  
    label 'mem2GB'
    cpus '2'
    tag 'thoasmetadataloading'

    publishDir "${params.thoas_data_location}", mode: 'copy', overWrite: true

    input:
    path thoas_config_file

    output:
    val thoas_config_file.name

    """
    pyenv local production-nextflow-py-3.8
    export META_CLASSIFIER_PATH=${params.thoas_code_location}/metadata_documents/metadata_classifiers/
    python ${params.nf_py_script_path}/thoas_load.py -c ${params.thoas_code_location} -i ${params.thoas_data_location}/${thoas_config_file} --load_metadata 
    """
}

process ExtractCoreDbDataCDS {
    /*
      Description: Extract  genomic feature from ensembl core databases 
    */

    debug "${params.debug}"  
    label 'mem16GB'
    cpus '4'
    tag 'extractcoredbdata'

    publishDir "${params.thoas_data_location}", mode: 'copy', overWrite: true

    input:
      val genome_info

    script:
      def jsonSlurper = new groovy.json.JsonSlurper()
      def genome      = jsonSlurper.parseText(genome_info[0])
      species     = genome['species']
      assembly    = genome['assembly_name']
      thoas_conf  = genome_info[1]
    
    """
     echo Extract genomic feature for species $species 
     echo $genome
     pyenv local production-nextflow-py-3.8
     export META_CLASSIFIER_PATH=${params.thoas_code_location}/metadata_documents/metadata_classifiers/    
     python ${params.nf_py_script_path}/thoas_load.py \
     -s $species -c ${params.thoas_code_location}/src/ensembl/ -i ${params.thoas_data_location}/$thoas_conf \
     --load_species \
     --extract_genomic_features \
     --extract_genomic_features_type cds 
    """

    output:
      tuple val("${species}"), val(thoas_conf), path("${species}.extract.cds.log"),
       path("${species}_${assembly}_attrib.csv"), path("${species}_${assembly}.csv"), path("${species}_${assembly}_phase.csv")
}

process ExtractCoreDbDataGeneName {
    /*
      Description: Extract  genomic feature from ensembl core databases 
    */

    debug "${params.debug}"  
    label 'mem16GB'
    cpus '4'
    tag 'extractcoredbdata'

    publishDir "${params.thoas_data_location}", mode: 'copy', overWrite: true

    input:
      val genome_info

    script:
      def jsonSlurper = new groovy.json.JsonSlurper()
      def genome      = jsonSlurper.parseText(genome_info[0])
      species     = genome['species']
      assembly    = genome['assembly_name']
      thoas_conf  = genome_info[1]
    
    """
     echo Extract genomic feature for species $species 
     echo $genome
     pyenv local production-nextflow-py-3.8
     export META_CLASSIFIER_PATH=${params.thoas_code_location}/metadata_documents/metadata_classifiers/    
     python ${params.nf_py_script_path}/thoas_load.py \
     -s $species -c ${params.thoas_code_location}/src/ensembl/ -i ${params.thoas_data_location}/$thoas_conf \
     --load_species \
     --extract_genomic_features \
     --extract_genomic_features_type genes
    """

    output:
      tuple val("${species}"), val(thoas_conf), path("${species}.extract.genes.log"),
       path("${species}_${assembly}_gene_names.json")
}

process ExtractCoreDbDataProteins {
    /*
      Description: Extract  genomic feature from ensembl core databases 
    */

    debug "${params.debug}"  
    label 'mem16GB'
    cpus '4'
    tag 'extractcoredbdata'

    publishDir "${params.thoas_data_location}", mode: 'copy', overWrite: true

    input:
      val genome_info

    script:
      def jsonSlurper = new groovy.json.JsonSlurper()
      def genome      = jsonSlurper.parseText(genome_info[0])
      species     = genome['species']
      assembly    = genome['assembly_name']
      thoas_conf  = genome_info[1]
    
    """
     echo Extract genomic feature for species $species 
     echo $genome
     pyenv local production-nextflow-py-3.8
     export META_CLASSIFIER_PATH=${params.thoas_code_location}/metadata_documents/metadata_classifiers/    
     python ${params.nf_py_script_path}/thoas_load.py \
     -s $species -c ${params.thoas_code_location}/src/ensembl/ -i ${params.thoas_data_location}/$thoas_conf \
     --load_species \
     --extract_genomic_features \
     --extract_genomic_features_type proteins 
    """

    output:
      tuple val("${species}"), val(thoas_conf), path("${species}.extract.proteins.log"), 
      path("${species}_${assembly}_translations.json")
}

process LoadGeneIntoThoas {
    /*
      Description: Load  genomic feature into mongo
    */

    debug "${params.debug}"  
    label 'mem8GB'
    cpus '8'
    tag 'extractcoredbdata'
    
    publishDir "${params.thoas_data_location}", mode: 'copy', overWrite: true

    input:
      val genome_info

    script:
      species     = genome_info[0]
      thoas_conf  = genome_info[1]
          

    """
    echo $species
    echo Load genes for  $species in  $thoas_conf
    pyenv local production-nextflow-py-3.8
    export META_CLASSIFIER_PATH=${params.thoas_code_location}/metadata_documents/metadata_classifiers/   
    cd  ${params.thoas_data_location}/
    python ${params.nf_py_script_path}/thoas_load.py \
    -s $species -c ${params.thoas_code_location}/src/ensembl/ -i ${params.thoas_data_location}/$thoas_conf \
    --load_species \
    --load_genomic_features \
    --load_genomic_features_type genes
    """
    // removed load genome --load_genomic_features_type genome genes regions
    output:
      tuple val("${species}"), val(thoas_conf)
    queueSize=10
}

process LoadRegionIntoThoas {
    /*
      Description: Load  genomic feature into mongo
    */

    debug "${params.debug}"  
    label 'mem8GB'
    cpus '8'
    tag 'extractcoredbdata'
    
    publishDir "${params.thoas_data_location}", mode: 'copy', overWrite: true

    input:
      val load_species

    script:
      species = load_species[0]
      thoas_conf = load_species[1]
          

    """
    echo $species
     echo Load regions for  $species in $thoas_conf
     pyenv local production-nextflow-py-3.8
     export META_CLASSIFIER_PATH=${params.thoas_code_location}/metadata_documents/metadata_classifiers/   
     cd  ${params.thoas_data_location}/
     python ${params.nf_py_script_path}/thoas_load.py \
     -s $species -c ${params.thoas_code_location}/src/ensembl/ -i ${params.thoas_data_location}/$thoas_conf \
     --load_species \
     --load_genomic_features \
     --load_genomic_features_type regions
    """
    // removed load genome --load_genomic_features_type genome genes regions
    output:
      tuple val("${species}"), val(thoas_conf)
    queueSize=20
}

process CreateIndex {
    /*
      Description: Create MongoDB Index for gene genome and regions 
    */

    debug "${params.debug}"  
    label 'mem8GB'
    cpus '8'
    tag 'createindex'
        
    publishDir "${params.thoas_data_location}", mode: 'copy', overWrite: true

    input:
      val thoas_conf

    """
      echo Index in progress 
      pyenv local production-nextflow-py-3.8
      export META_CLASSIFIER_PATH=${params.thoas_code_location}/metadata_documents/metadata_classifiers/   
      cd  ${params.thoas_data_location}/
      python ${params.thoas_code_location}/src/ensembl/create_index.py --config_file ${params.thoas_data_location}/${thoas_conf} --mongo_collection ${params.mongo_db_collection}
    """

}




process Validate {
    /*
      Description: Create MongoDB Index for gene genome and regions 
    */

    debug "${params.debug}"  
    label 'mem8GB'
    cpus '8'
    tag 'createindex'
    
    publishDir "${params.thoas_data_location}", mode: 'copy', overWrite: true

    input:
      val load_species

    script:
      species = load_species[0]
      thoas_conf = load_species[1]


    """
      echo Index in progress 
      pyenv local production-nextflow-py-3.8
      export META_CLASSIFIER_PATH=${params.thoas_code_location}/metadata_documents/metadata_classifiers/   
      cd  ${params.thoas_data_location}/
      python ${params.thoas_code_location}/src/ensembl/create_index.py --config_file ${params.thoas_data_location}/$thoas_conf --mongo_collection ${params.mongo_db_collection}
    """

}







// process LoadThoas {
//     /*
//       Description: Load  genome data into mongodb collection for thoas
//     */

//     debug "${params.debug}"  
//     label 'mem16GB'
//     cpus '12'
//     tag 'thoasloading'

//     publishDir "${params.thoas_data_location}", mode: 'copy', overWrite: true

//     input:
//     path thoas_config_file
//     val genome_info

//     output:
//     path "loading_log_${params.release}.out"

//     """
//     pyenv local production-nextflow-py-3.8
//     #export META_CLASSIFIER_PATH=${params.thoas_code_location}/metadata_documents/metadata_classifiers/
//     #python ${params.thoas_code_location}/src/ensembl/multi_load.py --config ${params.thoas_data_location}/$thoas_config_file &> loading_log_${params.release}.out
//     echo ${genome_info}
    
//     """

//}

// process LoadGeneIntoThoasBack {
//     /*
//       Description: Load  genomic feature into mongo
//     */

//     debug "${params.debug}"  
//     label 'mem8GB'
//     cpus '8'
//     tag 'extractcoredbdata'
    
//     publishDir "${params.thoas_data_location}", mode: 'copy', overWrite: true

//     input:
//       val genome_info

//     script:
//       def jsonSlurper = new groovy.json.JsonSlurper()
//       def genome      = jsonSlurper.parseText(genome_info[0])
//       species     = genome['species']
//       assembly    = genome['assembly_name']
//       thoas_conf  = genome_info[1]
          

//     """
//     echo $species
//      echo Load genes for  $species in  $thoas_conf
//      pyenv local production-nextflow-py-3.8
//      export META_CLASSIFIER_PATH=${params.thoas_code_location}/metadata_documents/metadata_classifiers/   
//      cd  ${params.thoas_data_location}/
//      python ${params.nf_py_script_path}/thoas_load.py \
//      -s $species -c ${params.thoas_code_location}/src/ensembl/ -i ${params.thoas_data_location}/$thoas_conf \
//      --load_species \
//      --load_genomic_features \
//      --load_genomic_features_type genes
//     """
//     // removed load genome --load_genomic_features_type genome genes regions
//     output:
//       tuple val("${species}"), val(thoas_conf)
//     queueSize=20
// }