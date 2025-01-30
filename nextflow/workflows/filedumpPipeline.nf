/*
* NextFlow File dump Pipeline generate FTP Core and Variation Dumps Files 
*/


// Import Production Common Factories
include { DumpFastaFiles } from '../modules/filedump.nf'
 
//global variables default values
params.species            = "''"
params.division           = "''"
params.antispecies        = "''"
params.run_all            = 0
params.meta_filters       = "''"
params.group              = 'core'
params.help               = false
params.core_filetype      = "embl,tsv,genbank,gtf,gff3,json,fasta_pep,fasta_cdna,fasta_cds,fasta_dna,fasta_dna_index,vep"
params.variation_filetype = "vcf,gvf"  
params.conf_file          = false
params.output             = ""
params.ftp_path           = ""


println """\
         F I L E  D U M P - N F   P I P E L I N E
         ===================================
         release                     : ${params.release}
         species                     : ${params.species}
         anti-species                : ${params.antispecies}
         division                    : ${params.division}
         run_all                     : ${params.run_all}
         group                       : ${params.group}
         core filetype               : ${params.core_filetype}
         variation filetypes         : ${params.variation_filetype}
         conf file                   : ${params.conf_file} 
         ftp_path                    : ${params.ftp_path} 
         output                      : ${params.output}
         user                        : ${params.user}
         password                    : ${params.password}
         server                      : ${params.server}

         """
         .stripIndent()



def helpMessage() {
    log.info"""
Usage:
nextflow run ensembl-production/filedumPipeline.nf <ARGUMENTS>
  --ftp_path            Folder to output FTP Core dumps

  --divisions           Ensembl Division Names
                        Ex: vertebrates, plants ,fungi, microbes, metazoa, bacteria

  --species             Ensembl Species Names (should match to production name)
                        Ex: homo_sapiens

  --antispecies         Ensembl Species List Names Want To Exclude In Process

  --run_all             Include All the species Irrespective of divisions and species list

  --server              Db server to dump core databases

  --user                User name for the db server

  --password            Password for the db server
  
  --conf_file           Config file with file type and expected files ex: [embl] tsv files , check requiredFiles.conf in ensembl-production repo 
  
  Run example: nextflow run ensembl-production/nextflow/workflows/filedumpPipeline.nf --release=114 --conf_file=""  --server=jdbc:mysql://mysql-ens-core-prod-1:4524 --user=ensro --password="" --ftp_path

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

division = channel.of(params.division.split(","))

// Dump fasta files
core_out_ch = CoreDumpGensetFastaFlow("mus_musculus_casteij_core_114_2")
  
//clean the empty log files  
 
}

workflow CoreDumpGensetFastaFlow {

    take: 
      database
 
    main:          
      output_files=DumpFastaFiles(database)
    emit:
      output_files.collect() 

}

workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}