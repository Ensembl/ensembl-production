=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_non_vertebrates_conf;

=head1 DESCRIPTION

=head1 AUTHOR 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_non_vertebrates_conf;

use strict;
use warnings;
use File::Spec;
use Data::Dumper;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_conf');     
   
sub default_options {
    my ($self) = @_;
    
    return {
       # inherit other stuff from the base class
       %{ $self->SUPER::default_options() }, 
	   'perl_command'  		 => 'perl',
	   'blast_header_prefix' => 'EG:',
      ## gff3 & gtf parameter
      'abinitio'        => 0,
      # Previous release FASTA DNA files location
      'prev_rel_dir' => '/nfs/ensemblgenomes/ftp/pub/',
      ## Indexing parameters
      'skip_convert_fasta' => 0,
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
      $pipeline_flow  = ['json','gtf', 'gff3', 'embl', 'fasta_dna','fasta_pep', 'genbank', 'assembly_chain_datacheck', 'tsv_uniprot', 'tsv_ena', 'tsv_metadata', 'tsv_refseq', 'tsv_entrez', 'rdf'];
    }
    if (not $self->o('skip_convert_fasta')){
      @$pipeline_flow = grep {$_ ne 'fasta_dna' and $_ ne 'fasta_pep'} @$pipeline_flow;
    }
    my %analyses_by_name = map {$_->{'-logic_name'} => $_} @$super_analyses;
    $self->tweak_analyses(\%analyses_by_name, $pipeline_flow);
    
    return [
      @$super_analyses,

	  ##### Toplevel Dumps -> Blast Dumps
	  { -logic_name     => 'convert_fasta',
	    -module         => 'Bio::EnsEMBL::Production::Pipeline::FASTA::BlastConverter',
	    -hive_capacity  => 50,
      -priority        => 5,
 	    -parameters     => { header_prefix => $self->o('blast_header_prefix'), }
	  }  
    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;
    my $pipeline_flow    = shift;

    ## Removed unused dataflow
    $analyses_by_name->{'concat_fasta'}->{'-flow_into'} = { };
    $analyses_by_name->{'primary_assembly'}->{'-wait_for'} = [];
    if ($self->o('skip_convert_fasta')){
      $analyses_by_name->{'backbone_job_pipeline'}->{'-flow_into'} = {
                  '1->A' => $pipeline_flow,
                  'A->1' => ['checksum_generator'],
                };
    }
    else{
      $analyses_by_name->{'backbone_job_pipeline'}->{'-flow_into'} = {
                  '1->A' => $pipeline_flow,
                  'A->1' => ['checksum_generator'],
                  '1->B' => ['fasta_dna','fasta_pep'],
                  'B->1' => ['convert_fasta'],
                };
      $analyses_by_name->{'checksum_generator'}->{'-wait_for'} = ['convert_fasta'];
    }
    return;
 
}



1;

