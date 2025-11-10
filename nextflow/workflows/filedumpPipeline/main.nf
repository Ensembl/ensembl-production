// See the NOTICE file distributed with this work for additional information
// regarding copyright ownership.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
/*
* NextFlow File dump Pipeline generate FTP Core and Variation Dumps Files 
*/
import groovy.json.JsonSlurper
 
//global variables default values
params.metadata_db        = ""
params.output             = ""
params.ftp_path           = ""
params.base_dir           = "$BASE_DIR"
params.password           = ""
// Temp sequnce directories
params.top_level_dir      = "top_level_seq"
params.feature_seq_dir    = "sequence"
// Files subfolders, inside spicies folder
params.factory_path       = "$BASE_DIR/ensembl-metadata-api/src/ensembl/production/metadata/api/factories/genomes.py"

// Import Production Common Factories
include { DumpFastaFiles } from './genset_fasta.nf'
include { DumpGFF3_GTFFiles } from './gff3_gtf.nf'
include { DumpEMBLFiles } from './embl.nf'
include { DumpXrefFile } from './xref.nf'
include { DumpChromosomeFile } from './chromosome.nf'
include { DumpGenomeFiles } from './genome_fasta.nf'
include { BuildTopLevelSequence } from './top_level_seq.nf'
include { BuildFeatureSequence } from './feature_seq.nf'
include { GenerateFolderStructure } from './ftp_structure.nf'

include { validateParameters; paramsSummaryLog } from 'plugin/nf-schema'
 
// Validate input parameters
validateParameters()
 
// Print summary of supplied parameters
log.info paramsSummaryLog(workflow)

def helpMessage() {
    log.info"""
Usage:
nextflow run ensembl-production/nextflow/workflows/filedumpPipeline/main.nf <ARGUMENTS>
  --ftp_path            Folder containing FTP Core dumps,
                        containing TSV/ENSEMBL/GFF/GTF/GENBANK etc. files.

  Mysql server datails 
 --server                Example: jdbc:mysql://mysql-ens-core-prod-1:4524
 --user
 --password
  
  """.stripIndent()
}

workflow {
 
if ( params.help || params.ftp_path == false || params.conf_file ==false ){
        helpMessage()
        println """
        Missing required params ftp_path/registry/conf_file
        """.stripIndent()
        exit 1
}

speciesDBConnStr = params.speciesdb_key

GenomeInfoProcess(params.metadata_db)
| splitText (limit: 1)
| GenerateFolderStructure 
| (BuildTopLevelSequence & DumpXrefFile & DumpChromosomeFile)

//BuildFeatureSequence(BuildTopLevelSequence.out) | (DumpFastaFiles & DumpGFF3_GTFFiles & DumpEMBLFiles)
//DumpGenomeFiles(BuildTopLevelSequence.out)
 
}

process GenomeInfoProcess {
    /*
      Description: Fetch the genome information from the ensembl production
      metadata-api and write as JSON.
    */

    if (params.debug) {
        debug params.debug
        errorStrategy 'terminate'
    }
    label 'mem1GB'
    tag 'genomeinfo'
    publishDir "${params.output_path}", mode: 'copy', overWrite: true

    input:
    val dbconn

    output:
    path 'genome_info.json'

    script:
    g_uuid = params.genome_uuid ? "--genome_uuid " + convertToList(params.genome_uuid).join(" ") : ""
    e_release_id = params.release_id ? "--release_id " + params.release_id : ""

    """
    python ${params.factory_path} \
        --metadata_db_uri ${dbconn} \
        --output genome_info.json \
        --batch_size 0 \
        --dataset_status ${params.factory_selector} \
        --dataset_type genebuild \
        ${g_uuid} \
        ${e_release_id}
    """
}

workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}