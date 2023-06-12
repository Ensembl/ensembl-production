
def convertToList( userParam ){

    /*
      Function: convertToList
      Description: Convert User defined comma seperated params into a list.
      Input: inputData - Comma seperated string. (Type: String, Ex: "homo_sapiens,mus_musculus")
      Output: result - Split the string with delimitar. (Type: List[String])
    */ 

    if ( userParam && userParam != true && userParam != false){
        return userParam.split(',').collect { value -> "\"$value\""}
    }

    return []	

}

process GenomeInfoProcess {
    /*
      Description: Fetch the genome information from the ensembl production metadata-api and generate the yaml file.
      Input:
            genome_uuid (list): genome Universally Unique IDentifier. Defaults to [].
            species_name (list): Ensembl Species Name. Defaults to [].
            organism_group (list): Ensembl species Divisions. Defaults [].
            metadata_uri (str, Required): Mysql URI string to connect the metadata database.
            taxonomy_uri (str, Required): Mysql URI string to connect the ncbi taxonomy db.

       Output:
            Tuple: File paths to  genome information and genome ids 
    */

    debug true  
    label 'mem4GB'
    tag 'genomeinfo'
    publishDir "${params.genome_info_yaml}", mode: 'copy', overWrite: true

    input:
    val genome_uuid
    val species_name
    val organism_group
    val metadata_uri
    val taxonomy_uri 

    output:
    path "load-${params.release}.conf"

    """
    #!/usr/bin/env python
    
    #Script to fetch genome info from new metadata api

    import os
    import yaml
    import configparser 
    from ensembl.production.metadata.api import GenomeAdaptor

    #set nexflow params
    GENOME_UUID    = $genome_uuid if $genome_uuid else None
    SPECIES_NAME   = $species_name if $species_name else None
    ORGANISM_GROUP = $organism_group if $organism_group else None
    METADATA_URI   = "$metadata_uri"
    METADATA_URI   = "$taxonomy_uri"

    genome_info    = {} 
    genome_info_obj = GenomeAdaptor(metadata_uri=METADATA_URI, taxonomy_uri=METADATA_URI)    

       
    with open("genome_id_info.yml", "a") as genome_id_info_file, open("genome_uuids.txt", "a") as genome_uuids_file:
         
        for genome in genome_info_obj.fetch_genomes_info(unreleased_datasets=True, genome_uuid=GENOME_UUID, ensembl_name=SPECIES_NAME, group=ORGANISM_GROUP) or []:

            division_type = "vert" if genome[0]['genome'][-1].name.lower() == "ensemblvertebrates" else "non_vert"
            if genome[0]['genome'][2].assembly_default == "GRCh37":
                division_type = genome[0]['genome'][2].assembly_default.lower()

            division = genome[0]['genome'][-1].name.lower().replace('ensembl','') 
            genome_uuids_file.write(f"{genome[0]['genome'][0].genome_uuid}\\n")
            yaml.dump({
                genome[0]['genome'][0].genome_uuid:{
                "genome_id" : genome[0]['genome'][0].genome_uuid,
                "species"   : genome[0]['genome'][1].ensembl_name,
                "gca"       : genome[0]['genome'][2].accession,
                "division"  : division,
                "dbname"    : genome[0]['datasets'][-1][-1].name,
                "contigs"   : genome[0]['genome'][2].level,
                "version"   : genome[0]['genome'][2].assembly_default,
                "type"      : division_type
               }
            }, genome_id_info_file)

    """

}