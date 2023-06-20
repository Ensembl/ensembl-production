#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include { 
          GenerateThoasConfigFile;
          LoadThoas
        } from '../modules/thoasCommonProcess'

include {
    GenomeInfo
} from '../modules/productionCommon'  

include {
  convertToList
} from '../modules/utils.nf'


println """\
         T H O A S - N F   P I P E L I N E
         ===================================
         debug                 : ${params.debug}
         release               : ${params.release}
         genome_uuid           : ${params.genome_uuid} 
         species_name          : ${params.species_name}
         dataset_type          : ${params.dataset_type}
         organism_group        : ${params.organism_group}
         unreleased_genomes    : ${params.unreleased_genomes}
         outdir                : ${params.thoas_data_location}
         thoas_code_location   : ${params.thoas_code_location}   
         thoas_data_location   : ${params.thoas_data_location}
         thoas_config_filename : ${params.thoas_data_location}/${params.thoas_config_filename}
         base_data_path        : ${params.base_data_path}
         grch37_data_path      : ${params.grch37_data_path}
         classifier_path       : ${params.classifier_path}
         chr_checksums_path    : ${params.chr_checksums_path}
         xref_lod_mapping_file : ${params.xref_lod_mapping_file}
         log_faulty_urls       : ${params.log_faulty_urls}   
         mongo_dbname          : ${params.mongo_db_dbname}
         mongodb_collection    : ${params.mongo_db_collection}
         mongo_schema          : ${params.mongo_sb_schema}
         refget_dbname         : ${params.refget_db_dbname}
         """
         .stripIndent()


def helpMessage() {
    log.info"""
Usage:
nextflow run thoas.nf <ARGUMENTS>

  --debug                  echo the output data from process, default: false 
 
  --genome_uuid            Gereate datafiles for the given genome UUID id 

  --organism_group         Ensembl Division Names
                           Ex: EnsemblVertebrates, EnsemblPlants ,EnsemblFungi, EnsemblMetazoa, EnsemblBacteria
   
  --species_name           Ensembl Species Names (should match with ensembl production name)
                           Ex: homo_sapiens

  --dataset_type           Ensembl genome source dataset 
                           Ex: assembly, geneset 

  --thoas_config_filename  thoas config filename 
                           Ex: load-110.conf     
     
  --release                ensembl release version default set from env variable ENS_VERSION
                           Ex: 110

  --thoas_code_location    path to thoas repo location for ensembl-thoas-configs & ensembl-core-mongodb-loading
                           default: ${params.thoas_code_location}  
  
  --thoas_data_location    path to thoas output data location
                           default: ${params.thoas_data_location}   
  
  --base_data_path         path to search dumps 
                           default: ${params.base_data_path}   
  
  --grch37_data_path       path to grch37 search dumps 
                           default: ${params.grch37_data_path}
  
  --classifier_path        path to metadata classifier 
                           default: ${params.classifier_path}
  
  --chr_checksums_path     path to chromosome checksums 
                           default: ${params.chr_checksums_path}
  
  --xref_lod_mapping_file  path to Xref lod mapping file 
                           default: ${params.xref_lod_mapping_file}
  
  --log_faulty_urls       logs the faulty_url, default: false

  --metadata_db_host      metadata database host name 
                          default: ${params.metadata_db_host}

  --metadata_db_port      metadata database port details
                          default: ${params.metadata_db_port}
  
  --metadata_db_user      metadata database user name
                          default: ${params.metadata_db_user}
  
  --metadata_db_dbname    metadata database name 
                          default: ${params.metadata_db_dbname}
  
  --taxonomy_db_dbname    ncbi taxonomy database name
                          default: ${params.taxonomy_db_dbname}
  
  --metadata_db_password  metadata database passwrod
                          default: ${params.metadata_password}
   
  --refget_db_host        refget database host name 
                          default: ${params.refget_host}
  
  --refget_db_port        refget database port details 
                          default: ${params.refget_port}
  
  --refget_db_dbname      refget database name 
                          default: ${params.refget_dbname}    
     
  --refget_db_user        refget database user name 
                          default: ${params.refget_user} 
  
  --refget_db_password    refget database user password
                          default: ${params.refget_password} 
   
  --mongo_db_host         mongo database host name
                          default: ${params.mongo_host}

  --mongo_db_port         mongo database port details
                          default: ${params.mongo_port}

  --mongo_db_user         mongo database user
                          default: ${params.mongo_user}

  --mongo_db_password     mongo_host database password
                          default: ''

  --mongo_db_dbname       mongo database name
                          default: ${params.mongo_dbname}

  --mongo_db_collection   mongo database collection name
                          default: "graphql-${USER}-${ENS_VERSION}"

  --mongo_db_schema       mongo database schema
                          default: "./common/schema.sdl"

  --core_db_host          core database host name
                          default: "${params.coredb_host}"

  --core_db_port          core database port
                          default: "${params.coredb_port}"

  --core_db_user          core database user
                          default: "${params.coredb_user}"
                     
  """.stripIndent()
}

workflow {
    
    if(params.help){
      helpMessage()
      exit 1; 
    }
       
    //set user params as list  
    genome_uuid     = convertToList(params.genome_uuid) 
    species_name    = convertToList(params.species_name)
    organism_group  = convertToList(params.organism_group)
    dataset_type    = convertToList(params.dataset_type)
    metadata_db_uri = "mysql://${params.metadata_db_user}@${params.metadata_db_host}:${params.metadata_db_port}/${params.metadata_db_dbname}"
    taxonomy_db_uri = "mysql://${params.metadata_db_user}@${params.metadata_db_host}:${params.metadata_db_port}/${params.taxonomy_db_dbname}"
    output_json     = 'genome_info.json'
    unreleased_genomes = params.unreleased_genomes ? true : false
    
    GenomeInfo(genome_uuid, species_name, organism_group, unreleased_genomes, dataset_type, 
                              metadata_db_uri, taxonomy_db_uri, output_json)
    GenerateThoasConfigFile(GenomeInfo.out[0])
    LoadThoas(GenerateThoasConfigFile.out[0]) 
}

workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}
