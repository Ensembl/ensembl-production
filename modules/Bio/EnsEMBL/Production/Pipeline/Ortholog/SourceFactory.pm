=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::Ortholog::SourceFactory

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::Ortholog::SourceFactory;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::Hive::Process');

sub param_defaults {
    return {

           };
}

sub fetch_input {
    my ($self) 	= @_;

return 0;
}

sub run {
    my ($self) = @_;

return 0;
}

sub write_output {
    my ($self)  = @_;

    my $sp_config = $self->param_required('species_config');

    foreach my $pair (keys $sp_config){
       my $compara	  = $sp_config->{$pair}->{'compara'};
       my $source         = $sp_config->{$pair}->{'source'};
       my $target         = $sp_config->{$pair}->{'target'};
       my $exclude        = $sp_config->{$pair}->{'exclude'};
       my $homology_types = $sp_config->{$pair}->{'homology_types'}; 

      $self->dataflow_output_id(
		{
		 'compara' => $compara,
		 'source'  => $source, 
  		 'target'  => $target,
  		 'exclude' => $exclude,
		 'homology_types' => $homology_types,
		},2); 
      }

return 0;
}



1;


