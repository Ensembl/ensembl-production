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

 Bio::EnsEMBL::Production::Pipeline::Webdatafile::GenomeInfoYml;

=head1 DESCRIPTION

 Given a yml or a list of species, dataflow jobs with species names. 

=cut

package Bio::EnsEMBL::Production::Pipeline::Webdatafile::GenomeInfoYml;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use YAML::XS 'LoadFile';
use Array::Utils qw(intersect);

sub write_output {

  my ($self) = @_;
  my $genomeinfo_yml = $self->param('genomeinfo_yml');
  my $run_all =  $self->param('run_all');
  if( $genomeinfo_yml ){
      my $config = LoadFile($genomeinfo_yml);
      my @available_genomes = keys %$config;
      my @requested_genomes = @{$self->param('species')};
      my @genomes = intersect(@available_genomes, @requested_genomes); 
      if($run_all && scalar @genomes == 0){
         @genomes = keys %$config;  
      }
      foreach my $species ( @genomes ) {
          $self->dataflow_output_id({
            species => $species,
            group   => 'core',
          }, 2);
      }
      

   }else{
         
      $self->dataflow_output_id( {'speciesFactory' => '1'}, 3);
   }


   $self->dataflow_output_id( {'notify_email' => '1'}, 1);
   
}

1;
