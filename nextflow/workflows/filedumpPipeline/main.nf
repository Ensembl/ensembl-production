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

 
//global variables default values
params.species            = "''"
params.division           = "''"
params.antispecies        = "''"
params.meta_filters       = "''"
params.group              = 'core'
params.core_filetype      = "embl,tsv,genbank,gtf,gff3,json,fasta_pep,fasta_cdna,fasta_cds,fasta_dna,fasta_dna_index,vep"
params.variation_filetype = "vcf,gvf"  
params.output             = ""
params.ftp_path           = ""
params.base_dir           = "$BASE_DIR"
params.password           = ""
// Temp sequnce directories
params.top_level_dir      = "top_level_seq"
params.feature_seq_dir    = "sequence"
// Files subfolders, inside spicies folder
params.pep_fa_dir         = "fasta"
params.cdna_fa_dir        = "fasta"
params.gff_gtf_dir        = "fasta"
params.embl_dir           = "fasta"
params.xref_dir           = "fasta"
params.genome_fa_dir      = "fasta"


// Import Production Common Factories
include { DumpFastaFiles } from './genset_fasta.nf'
include { DumpGFF3_GTFFiles } from './gff3_gtf.nf'
include { DumpEMBLFiles } from './embl.nf'
include { DumpXrefFile } from './xref.nf'
include { DumpChromosomeFile } from './chromosome.nf'
include { DumpGenomeFiles } from './genome_fasta.nf'
include { BuildTopLevelSequence } from './top_level_seq.nf'
include { BuildFeatureSequence } from './feature_seq.nf'

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
databases = (["abramis_brama_gca022829085v1_core_110_1", "GCA/000/001/405/29/ensembl/2025"])
// abramis_brama_gca022829085v1_core_110_1
// homo_sapiens_core_116_38
//tupaia_belangeri_core_116_1
// Folder for the species is different for every species, so we pass ot over the pipeline
// Base ftp folder and subfolders for the sequence is the same for all the secies so we don't need to pass it or change
// so it is set up in parameters that are availbale in all the workflows
Channel.of(databases) \
// We need to build top level seq in the first place, as multi coord dbs doesn't have seq on the top feature level
| BuildTopLevelSequence \
// We can build feature seq  - now when we have sequnce at the same top level as features, 
//and we can dump genome (top level) seq to files
| BuildFeatureSequence | (DumpFastaFiles & DumpGFF3_GTFFiles & DumpEMBLFiles & DumpGenomeFiles )
// All other files need features to be build to dump feature level fasta, gtf gff and embl formats


Channel.of(databases) | (DumpXrefFile & DumpChromosomeFile)
 
}

workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}