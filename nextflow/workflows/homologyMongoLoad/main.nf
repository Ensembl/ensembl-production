#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
  GenomeInfo
} from '../../modules/productionCommon'

include {
  convertToList
} from '../../modules/utils.nf'


def banner(){

  println """\
          Homology Load Mongo - N F   P I P E L I N E
          ============================================
          debug                 : ${params.debug}
          release               : ${params.release}
          genome_uuid           : ${params.genome_uuid}
          species_name          : ${params.species}
          dataset_type          : ${params.dataset_type}
          mongo_url_rw          : ${params.mongo_url_rw}
          mongo_url_admin       : ${params.mongo_url_admin}
          metadata_grpc_url     : ${params.metadata_grpc_url}
          metadata_db_uri       : ${params.metadata_db_uri}        
          """.stripIndent()
}

//TODOD: Integrate with the productionCommon module Genome Info
//Create new process to extract and load homologies stats into mongoDB

workflow {

    //set user params as list
    def jsonSlurper = new groovy.json.JsonSlurper()

}

workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}