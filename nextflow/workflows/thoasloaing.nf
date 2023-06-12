#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// include { 
//           checkParams;
//           convertToList;
//         } from './modules/datafileProcess'
        

//global variable default values

println """\
         T H O A S - N F   P I P E L I N E
         ===================================
         debug                 : ${params.debug}
         release               : ${params.release}
         outdir                : ${params.thoas_data_location}
         thoas_code_location   : ${params.thoas_code_location}   
         thoas_data_location   : ${params.thoas_data_location}
         base_data_path        : ${params.base_data_path}
         grch37_data_path      : ${params.grch37_data_path}
         classifier_path       : ${params.classifiers_path}
         chr_checksums_path    : ${params.chr_checksums_path}
         xref_lod_mapping_file : ${params.xref_lod_mapping_file}
         log_faulty_urls       : ${params.log_fault_url} 
         genome_uuid           : ${params.genome_uuid} 
         species_name          : ${params.species_name}
         organism_group        : ${params.organism_group}
         metadata_uri          : ${params.metadata_uri}
         taxonomy_uri          : ${params.taxonomy_uri}         
         """
         .stripIndent()


def helpMessage() {
    log.info"""
Usage:
nextflow run datafile.nf <ARGUMENTS>
  --output_path         Datafile output directory (required param)

  --datafile_script_path  perl executable folder with datafile script
                          Ex: <path>/ensembl-e2020-datafiles/bin/  

  --genome_uuid         Gereate datafiles for the given genome UUID id 

  --organism_group      Ensembl Division Names
                        Ex: EnsemblVertebrates, EnsemblPlants ,EnsemblFungi, EnsemblMetazoa, EnsemblBacteria

  --species_name        Ensembl Species Names (should match with ensembl production name)
                        Ex: homo_sapiens

  --metadata_uri        Ensembl Metadata DB mysql  uri
			Ex: mysql://user:pass@localhost:3366/ensembl_genome_metadata

  --taxonomy_uri        Ensembl taxonomy  DB mysql uri
                        Ex: mysql://user:pass@localhost:3366/ncbi_taxonomy

  --steps               Generate datafiles for specified step 
                        Ex: transcript,contig,gc,variation  

  --ncd_path            path to ncd tools 
                        Ex: /homes/dan/ncd-tools2/ncd-tools/pre-builds/codon/
  
  --genome_info_yaml    path to store the genome inforation 
                       
  """.stripIndent()
}

workflow {

    //checkParams() 
    
    if(params.help){
      helpMessage()
    }
    
    if(params.metadata_uri == '' || params.taxonomy_uri == ''){
        helpMessage()
        throw new RuntimeException("Missing Required parameter: metadata_uri or taxonomy_uri ") 
    }

    if( params.genome_info_yaml == ''){
        helpMessage()
        throw new RuntimeException("Missing Required parameter: genome_info_ymal ")
    }


    allowed_steps = ['bootstrap','transcript', 'contig', 'gc']
    for (step in params.steps.split(',')){
      if( !(step in allowed_steps)){
        helpMessage()
        throw new RuntimeException("Unknow step $step allowed steps are $allowed_steps")

      }
    }
    
    //set user params as list  
    genome_uuid    = convertToList(params.genome_uuid)
    species_name   = convertToList(params.species_name)
    organism_group = convertToList(params.organism_group)

   GenomeInfoProcess(genome_uuid, species_name, organism_group, params.metadata_uri, params.metadata_uri)
    myrun = BoostrapFlow(GenomeInfoProcess.out[1].splitText().map { it.replaceAll('\n', '') })
    rs = DatafileFlow(myrun) 
    JumpFileFlow(rs)  
}


workflow BoostrapFlow {
    take: genomes_uuids
    main:
        myrun = BootstrapProcess(genomes_uuids)
    emit:
        genome_out = myrun
}

workflow JumpFileFlow {
    take: 
    genome_ids
    main:
        JumpFileProcess(genome_ids) 
}

workflow DatafileFlow {
    take: ensembl_genome_uuids
    
    main:
        transcript_ch = TranscriptProcess(ensembl_genome_uuids)    
        contig_ch = ContigProcess(ensembl_genome_uuids)        
        gc_ch = GCProcess(ensembl_genome_uuids)
        jumpfile_ch = PrepareJumpFileProcess(transcript_ch
                                                .join(contig_ch,  remainder: true)
                                                .join(gc_ch,  remainder: true)
                                            ) 

        
        emit:
            data = jumpfile_ch.collect().flatten().last()

               
}

