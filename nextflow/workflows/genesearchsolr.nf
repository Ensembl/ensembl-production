#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
  SolrDumps;
  SolrIndex;
} from '../modules/genesearchsolrCommonProcess.nf'

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
         genome_uuid           : ${params.genome_uuid}
         species               : ${params.species}
         dataset_type          : ${params.dataset_type}
         dataset_status        : ${params.dataset_status}
         solr_data_location    : ${params.solr_data_location}
         workDir               : ${workDir}
         load_solr_index       : ${params.load_solr_index}
         solr_hosts            : ${params.solr_hosts}
         solr_collection       : ${params.solr_collection}
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

  --release                ensembl release version default set from env variable ENS_VERSION
                           Ex: 110


  --solr_data_location     path to solor output data location
                           default: ${params.solr_data_location}

  --metadata_db_uri       metadata database uri
                          default: ${params.metadata_db_uri}

  --core_db_uri           core database uri
                          default: "${params.coredb_uri}"

  --load_solr_index       Load Gene index file into solr
                          default: 0

  --solr_hosts            Source solr url to load the gene indexes, load to multiple solr host
                          Ex: http://localhost-1.caas.ebi.ac.uk:32423,http://localhost-2.caas.ebi.ac.uk:32423

  --solr_collection       Solr Collection name
                          Ex: genename

  """.stripIndent()
}

workflow {

    if(params.help){
      helpMessage()
      exit 1;
    }

    //set user params as list
    metadata_db_uri       = params.metadata_db_uri
    core_host_uri         = params.core_host_uri
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
    solr_hosts            = convertToList(params.solr_hosts)
    solr_collection       = params.solr_collection
    def jsonSlurper = new groovy.json.JsonSlurper()
    output_json     = 'genome_info.json'
    GenomeInfo( metadata_db_uri, genome_uuid, dataset_uuid,
                organism_group_type, division, dataset_type,
                species, antispecies, dataset_status, update_dataset_status,
                batch_size, page, columns, output_json
    )

    SolrDumps(
        core_host_uri,
        GenomeInfo.out[0].splitText().map {
            jsonSlurper.parseText(it.replaceAll('\n', ''))
        }
    )
    // Execute only if flag params.load_solr_index is set
    //SolrDumps.out[0].combine(solr_hosts).combine([solr_collection])
    if(params.load_solr_index == 1){
        SolrIndex(SolrDumps.out[0], solr_hosts, solr_collection)
    }

}

workflow SolrIndexLoad {
    main:
        index_ch = Channel.fromPath( "${params.solr_data_location}/*.json" )
        SolrIndex(index_ch, params.solr_hosts, params.solr_collection)
}

workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'FAILED' }"
}
