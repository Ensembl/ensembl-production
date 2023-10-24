/*
* NextFlow Pipeline To Check FTP Core and Variation Dumps Files 
*/


// Import Production Common Factories
include { SpeciesFactory } from '../modules/productionCommon.nf'
include { CheckFTPFiles; CleanEmptyFiles } from '../modules/ftpcheck.nf'
 
//global variables default values
params.species            = "''"
params.division           = "''"
params.antispecies        = "''"
params.run_all            = 0
params.meta_filters       = "''"
params.dbname             = "''"
params.group              = 'core'
params.pipeline_dir       = "$BASE_DIR/ensembl-hive/scripts/"
params.help               = false
params.core_filetype      = "embl,tsv,genbank,gtf,gff3,json,fasta_pep,fasta_cdna,fasta_cds,fasta_dna,fasta_dna_index,vep"
params.variation_filetype = "vcf,gvf"  
params.conf_file          = false
params.output             = ""


println """\
         F T P  C H E C K - N F   P I P E L I N E
         ===================================
         release                     : ${params.release}
         pipelinedir                 : ${params.pipeline_dir}
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
         """
         .stripIndent()



def helpMessage() {
    log.info"""
Usage:
nextflow run ensembl-production/checkPipeline.nf <ARGUMENTS>
  --ftp_path            Folder containing FTP Core dumps,
                        containing TSV/ENSEMBL/GFF/GTF/GENBANK etc. files.

  --divisions           Ensembl Division Names
                        Ex: vertebrates, plants ,fungi, microbes, metazoa, bacteria

  --species             Ensembl Species Names (should match to production name)
                        Ex: homo_sapiens

  --antispecies         Ensembl Species List Names Want To Exnclude In Process

  --run_all             Include All the species Irrespective of divisions and species list

  --registry            production registry module to load the species details  
  
  --conf_file           Config file with file type and expected files ex: [embl] tsv files , check requiredFiles.conf in ensembl-production repo 
  
  """.stripIndent()
}


workflow {
 
if ( params.help || params.ftp_path == false || params.registry == false || params.conf_file ==false ){
        helpMessage()
        println """
        Missing required params ftp_path/registry/conf_file
        """.stripIndent()
        exit 1
 }
 
 if (params.ftp_path && params.registry && params.conf_file){

        division = channel.of(params.division.split(","))
        SpeciesFactory(division)

        //check core dumps flat files 
        core_out_ch = CoreDumpsChecksFlow(SpeciesFactory.out[2].splitText(), SpeciesFactory.out[0])

        //check variation dump vcf and gvf files  
        var_out_ch = VariationDumpsChecksFlow(SpeciesFactory.out[4].splitText(), SpeciesFactory.out[0])

        //1000 genome files are checked for homo_sapiens alone 
        species_info   = '{"species":"homo_sapiens","group":"variation"}'
        division       = 'vertebrates'
        t_out_ch = ThousandGenomeFlow(species_info, division) 
        
        //clean the empty log files  
        CleanEmptyFiles( params.output, 
                         core_out_ch.join(var_out_ch,  remainder: true)
                                    .join(t_out_ch,  remainder: true)
                                    .collect().flatten().last()  
                       ) 
 }

}


workflow ThousandGenomeFlow {

    take: 
      species_info
      division
 
    main:          
      TG_filetype    = ['1000GenomeVCF', '1000GenomeGVF']
      output_files=CheckFTPFiles(
                     species_info,
                     division,
                     TG_filetype
                   )
    emit:
      output_files.collect()

}

workflow VariationDumpsChecksFlow {
    take: 
    species_info
    division
     
    main:
      variation_filetype = channel.of(params.variation_filetype.split(","))
      output_files = CheckFTPFiles(
                      species_info,
                      division, 
                      variation_filetype 
                     )
    emit:
      output_files.collect()  
}


workflow CoreDumpsChecksFlow {
    take:
    species_info
    division

    main:
      core_filetype = channel.of(params.variation_filetype.split(","))
      output_files  = CheckFTPFiles(
                       species_info,
                       division,
                       core_filetype
                     )
    emit:
      output_files.collect()     
       
}



workflow.onComplete {

    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}

