#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
  GenerateThoasConfigFile;
  LoadThoasMetadata;
  ExtractCoreDbDataCDS;
  ExtractCoreDbDataGeneName;
  ExtractCoreDbDataProteins;
  LoadGeneIntoThoas;
  LoadRegionIntoThoas;
  CreateCollectionAndIndex;
  ShardCollectionData;
  Validate;
} from '../modules/thoasCommonProcess'

include {
  GenomeInfo;
  UpdateDatasetStatus;
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
         species_name          : ${params.species}
         dataset_type          : ${params.dataset_type}
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
         mongo_shard_uri       : ${params.mongo_db_shard_uri}
         mongo_schema          : ${params.mongo_db_schema}
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
//     metadata_db_password  = (params.metadata_db_password != true || params.metadata_db_password=="") ?  '""' : ":${params.metadata_db_password}"
    def jsonSlurper = new groovy.json.JsonSlurper()
    metadata_db_uri       = "mysql://${params.metadata_db_user}@${params.metadata_db_host}:${params.metadata_db_port}/${params.metadata_db_dbname}"
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
    mongo_db_shard_uri    = ( ! params.mongo_db_shard_uri ||   params.mongo_db_shard_uri=="") ?  helpMessage() : params.mongo_db_shard_uri


    output_json     = 'genome_info.json'
    GenomeInfo( metadata_db_uri, genome_uuid, dataset_uuid,
                organism_group_type, division, dataset_type,
                species, antispecies, dataset_status, update_dataset_status,
                batch_size, page, columns, output_json
    )
   GenerateThoasConfigFile(GenomeInfo.out[0])
   CreateCollectionAndIndex(GenerateThoasConfigFile.out[0])
   ShardCollectionData(CreateCollectionAndIndex.out[0], mongo_db_shard_uri,  params.mongo_db_dbname)
   LoadThoasMetadata(GenerateThoasConfigFile.out[0], ShardCollectionData.out[0])
   genomes_ch = GenomeInfo.out[0].splitText().map {
                    genome_json = jsonSlurper.parseText(it.replaceAll('\n', ''))
                    return [genome_json['genome_uuid'], genome_json['species'], genome_json['assembly_name'], genome_json['dataset_uuid']]
                } .combine(LoadThoasMetadata.out[0]).map { it }
   ExtractCoreDbDataCDS(genomes_ch)
   ExtractCoreDbDataGeneName(genomes_ch)
   ExtractCoreDbDataProteins(genomes_ch)
   LoadGeneIntoThoas(ExtractCoreDbDataCDS.out[0].join(ExtractCoreDbDataGeneName.out[0],remainder: true).join(ExtractCoreDbDataProteins.out[0],remainder: true))
   LoadRegionIntoThoas(LoadGeneIntoThoas.out[0])
   Validate(LoadRegionIntoThoas.out[0])
   Validate.out[0].view()
  // UpdateDatasetStatus(Validate.out[0][3], metadata_db_uri, "Processed")
}

workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}
