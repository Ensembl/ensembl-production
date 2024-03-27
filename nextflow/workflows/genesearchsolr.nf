#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
  GenerateThoasConfigFile;
} from '../modules/thoasCommonProcess'

include {
  GenomeInfo
} from '../modules/productionCommon'

include {
  convertToList
} from '../modules/utils.nf'


println """\
         G E N E - S E A R C H - F I L  E S - F O R - SOLR - N F   P I P E L I N E
         =========================================================================
         This Pipeline Generates JSON Files For SOLR(Search Engine)
         debug                 : ${params.debug}
         release               : ${params.release}
         genome_uuid           : ${params.genome_uuid}
         species_name          : ${params.species}
         dataset_type          : ${params.dataset_type}
         dataset_status        : ${params.dataset_status}
         outdir                : ${params.solr_data_location}
         solr_data_location    : ${params.solr_data_location}
         solr_config_filename  : ${params.solr_data_location}/${params.solr_config_filename}
         """
         .stripIndent()


def helpMessage() {
    log.info"""
Usage:
nextflow run geneSearchForSolr.nf <ARGUMENTS>

  --debug                  echo the output data from process, default: false

  --genome_uuid            Gereate datafiles for the given genome UUID id

  --organism_group         Ensembl Division Names
                           Ex: EnsemblVertebrates, EnsemblPlants ,EnsemblFungi, EnsemblMetazoa, EnsemblBacteria

  --species                Ensembl Species Names (should match with ensembl production name)
                           Ex: homo_sapiens

  --dataset_type           Ensembl genome source dataset
                           Ex: assembly, geneset

  --solr_config_filename   config filename, contains the species information similar to thoas conf 
                           Ex: load-110.conf

  --release                ensembl release version default set from env variable ENS_VERSION
                           Ex: 110


  --solr_data_location     path to solor output data location
                           default: ${params.solr_data_location}

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

  --mongo_db_host         mongo database host name
                          default: ${params.mongo_host}

  --mongo_db_port         mongo database port details
                          default: ${params.mongo_port}

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
    metadata_db_password  = (params.metadata_db_password != true || params.metadata_db_password=="") ?  '' : ":${params.metadata_db_password}"
    metadata_db_uri       = "mysql://${params.metadata_db_user}${metadata_db_password}@${params.metadata_db_host}:${params.metadata_db_port}/${params.metadata_db_dbname}"
    update_dataset_status = params.update_dataset_status
    batch_size            = params.batch_size
    page                  = params.page
    dataset_type          = params.dataset_type
    genome_uuid           = convertToList(params.genome_uuid)
    dataset_uuid          = convertToList(params.dataset_uuid)
    organism_group_type   = convertToList(params.organism_group_type)
    division              = convertToList(params.division)
    species               = convertToList(params.species)
    antispecies           = convertToList(params.antispecies)
    dataset_status        = convertToList(params.dataset_status)
    columns               = convertToList(params.columns)
    
    output_json     = 'genome_info.json'
    GenomeInfo( metadata_db_uri, genome_uuid, dataset_uuid,
                organism_group_type, division, dataset_type,
                species, antispecies, dataset_status, update_dataset_status,
                batch_size, page, columns, output_json
    )
//    GenerateThoasConfigFile(GenomeInfo.out[0])
   SolrDumps(GenerateThoasConfigFile.out[0], GenomeInfo.out[0].splitText().map {it.replaceAll('\n', '')} )
// SolrIndex()
}

workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}
