=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_eg_conf;

=head1 DESCRIPTION

=head1 AUTHOR 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_eg_conf;

use strict;
use warnings;
use File::Spec;
use Data::Dumper;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_conf');     
   
sub default_options {
    my ($self) = @_;
    
    return {
       # inherit other stuff from the base class
       %{ $self->SUPER::default_options() }, 
       
#       'run_vep'			 => 1, # 0/1, Default => 1
       'vep_command'   		 => '--build all',
	   'perl_command'  		 => 'perl -I ~/Variation/modules',
       'perl_cmd'      		 => 'perl', # added
	   'blast_header_prefix' => 'EG:',
       'exe_dir'             => '/nfs/panda/ensemblgenomes/production/compara/binaries/',

       'ftpdir_vep'          => $self->o('ftp_dir').'/'.$self->o('vep_division').'/vep',
       'tempdir_vep'         => '/nfs/nobackup/ensemblgenomes/'.$self->o('ENV', 'USER').'/workspace/'.$self->o('pipeline_name').'/temp_dir/release-'.$self->o('release').'/'.$self->o('vep_division'),     
       'vep_div'             => $self->o('vep_division'),

   	   'f_dump_vep' 	     => 0,
	};
}

sub pipeline_analyses {
    my ($self) = @_;

    ## Get analyses defined in the base class
    my $super_analyses   = $self->SUPER::pipeline_analyses;

   	my $pipeline_flow;
        # Getting list of dumps from argument
        my $dumps = $self->o('dumps');
        # Checking if the list of dumps is an array
        my @dumps = ( ref($dumps) eq 'ARRAY' ) ? @$dumps : ($dumps);
        #Pipeline_flow will contain the dumps from the dumps list
        if (scalar @dumps) {
          $pipeline_flow  = $dumps;
        }
        # Else, we run all the dumps
        else {
          $pipeline_flow  = ['dump_gtf', 'dump_gff3', 'dump_embl', 'dump_genbank', 'dump_fasta_dna', 'dump_fasta_pep', 'dump_chain', 'dump_tsv_uniprot', 'dump_tsv_ena', 'dump_tsv_metadata', 'dump_tsv_refseq', 'dump_tsv_entrez', 'dump_rdf'];
        }
    
    my %analyses_by_name = map {$_->{'-logic_name'} => $_} @$super_analyses;
    $self->tweak_analyses(\%analyses_by_name, $pipeline_flow);
    
    return [
      @$super_analyses,

	  ##### Toplevel Dumps -> Blast Dumps
	  { -logic_name     => 'convert_fasta',
	    -module         => 'Bio::EnsEMBL::Production::Pipeline::FASTA::BlastConverter',
	    -hive_capacity  => 50,
 	    -parameters     => { header_prefix => $self->o('blast_header_prefix'), }, 
        -flow_into      => { '1' => ['dump_vep'] },
	  },

	  ##### VEP Dumps
      { -logic_name    => 'create_ftpdir_vep',
        -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters    => { cmd => 'mkdir -p ' . $self->o('ftpdir_vep'), },
        -input_ids      => [{}],
        -flow_into     => { '1' => [ $self->o('vep_div') ne 'bacteria' ? 'copy_tmp_to_ftp' : 'copy_tmp_to_ftp_bacteria'] },
        -hive_capacity => -1,
        -meadow_type   => 'LOCAL',
      },

      { -logic_name    => 'copy_tmp_to_ftp',
        -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -parameters    => {
           # Wrap copy command into a loop to avoid job failures, because a *.tar.gz didn't find any files. 
           # This can happen, if an entire directory (like bacteria) comprises only of multi species databases.
           # In this case all vep files will be in subdirectories. 
           # There will be no matching files directly in the root of the temporary directory and 
           # just copying *.tar.gz would make the job fail even though this is ok.
                    		 cmd => q~
							 for vep_file in `find #tempdir_vep# -maxdepth 2 -name "*.tar.gz"`
							 do
						     	cp $vep_file #ftpdir_vep#
							 done
                   		     ~,
                    		 tempdir_vep => $self->o('tempdir_vep'),
                    		 ftpdir_vep  => $self->o('ftpdir_vep'),                   		     
               		       },
         -hive_capacity => -1,
		 -wait_for      => ['dump_vep', 'convert_fasta'],				
      },    

      { -logic_name    => 'copy_tmp_to_ftp_bacteria',
	    -module        => 'Bio::EnsEMBL::Production::Pipeline::VEP::CopyTmpFtpDir',
        -parameters    => {
                    		 tempdir_vep => $self->o('tempdir_vep'),
                    		 ftpdir_vep  => $self->o('ftpdir_vep'),                   		     
               		       },
         -hive_capacity => -1,
		 -wait_for      => ['dump_vep', 'convert_fasta'],				
      },           

      { -logic_name     => 'dump_vep',
        -module         => 'Bio::EnsEMBL::Variation::Pipeline::DumpVEP::DumpVEP',
        -parameters     => {
							  eg		 		   => $self->o('eg'), 
							  eg_version 		   => $self->o('eg_version'), 
						      ensembl_cvs_root_dir => $self->o('ensembl_cvs_root_dir'),
                    		  pipeline_dir         => $self->o('tempdir_vep'),
						      perl_command		   => $self->o('perl_command'),
				              vep_command    	   => $self->o('vep_command'),
                           },
		-priority       => 1,
	    -hive_capacity  => 50, 
  	    -rc_name        => '32GB',
      },     
    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;
    my $pipeline_flow    = shift;

    ## Removed unused dataflow
    $analyses_by_name->{'concat_fasta'}->{'-flow_into'} = { };
    $analyses_by_name->{'primary_assembly'}->{'-wait_for'} = [];

    ## Extend this section to add 'convert_fasta' analysis if fasta dump is done
    if ($self->o('f_dump_vep')){
        $analyses_by_name->{'job_factory'}->{'-flow_into'} = {
                                                                '2->A' => $pipeline_flow,
                                                                'A->2' => ['convert_fasta'],
                                                              };   
    }
 
}



1;

