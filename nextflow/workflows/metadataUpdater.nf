
/* NextFlow pipeline to update ensembl_genome_metadata database with various submission databases.
*/


// Import Production Common Factories
include { SpeciesFactory } from '../modules/productionCommon.nf'
include { DbFactory } from '../modules/productionCommon.nf'

//default params
params.division = 'vertebrates'
params.filetype = ['embl', 'fasta', 'genbank', 'gff3', 'gtf', 'json', 'mysql', 'tsv']

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

  """.stripIndent()
}

process check_species {
  debug 'ture'
  label 'mem2GB'
  tag 'check_species'
  errorStrategy 'finish'

  input:
  each species_info
  each filetype

  shell:
  species = (species_info =~ /"species":"([A-Za-z0-9_]+)",/)[0][1]

  """
  echo " $species_info , $filetype $species"
  python checkftpfiles.py -f $params.ftp_path -e \$ENS_VERSION  -g \$EG_VERSION -t $filetype -d $params.division -s $species

  """
}

workflow {

 file_type = params.filetype

 if ( params.help || params.ftp_path == false || params.registry == false ){
        helpMessage()
        exit 1
 }

 if (params.ftp_path && params.registry){
        DbFactory()
        SpeciesFactory(DbFactory.out.splitText())
        check_species(SpeciesFactory.out.splitText(), file_type, )
        //check_species(DbFactory.out.splitText(), file_type )
 }

}
