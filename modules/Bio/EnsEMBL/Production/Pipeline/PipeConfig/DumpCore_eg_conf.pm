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
	   'perl_command'  		 => 'perl',
	   'blast_header_prefix' => 'EG:',
      ## dump_gff3 & dump_gtf parameter
      'abinitio'        => 0
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
          $pipeline_flow  = ['dump_json','dump_gtf', 'dump_gff3', 'dump_embl', 'dump_genbank', 'dump_chain', 'dump_tsv_uniprot', 'dump_tsv_ena', 'dump_tsv_metadata', 'dump_tsv_refseq', 'dump_tsv_entrez', 'dump_rdf'];
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

    $analyses_by_name->{'job_factory'}->{'-flow_into'} = {
                '2'    => $pipeline_flow,
							  '2->A' => ['dump_fasta_dna','dump_fasta_pep'],
							  'A->2' => ['convert_fasta'],
							 };   

    return;
 
}



1;

