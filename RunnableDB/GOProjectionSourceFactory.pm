=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GOProjectionSourceFactory;

=head1 DESCRIPTION

=head1 AUTHOR

ckong

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GOProjectionSourceFactory;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::Base');

sub fetch_input {
    my ($self) 	= @_;

    my $go_config = $self->param_required('go_config') || die "'go_config' is an obligatory parameter";
    $self->param('go_config', $go_config);

return 0;
}

sub write_output {
    my ($self)  = @_;

    my $go_config = $self->param('go_config');

    foreach my $pair (keys $go_config){
       my $source                 = $go_config->{$pair}->{'source'};
       my $species                = $go_config->{$pair}->{'species'};
       my $antispecies            = $go_config->{$pair}->{'antispecies'};
       my $division               = $go_config->{$pair}->{'division'};
       my $run_all                = $go_config->{$pair}->{'run_all'};       
       my $method_link_type       = $go_config->{$pair}->{'go_method_link_type'};  
       my $homology_types_allowed = $go_config->{$pair}->{'go_homology_types_allowed'};
       my $percent_id_filter      = $go_config->{$pair}->{'go_percent_id_filter'};
       my $ensemblObj_type        = $go_config->{$pair}->{'ensemblObj_type'};
       my $ensemblObj_type_target = $go_config->{$pair}->{'ensemblObj_type_target'};

      $self->dataflow_output_id(
		{'source'      		  => $source, 
		 'species'     		  => $species, 
		 'antispecies' 		  => $antispecies, 
  		 'division'    	  	  => $division, 
		 'run_all' 		  => $run_all,
		 'method_link_type' 	  => $method_link_type,
                 'homology_types_allowed' => $homology_types_allowed,
  		 'percent_id_filter'      => $percent_id_filter,
		 'ensemblObj_type'        => $ensemblObj_type,
		 'ensemblObj_type_target' => $ensemblObj_type_target 
		},2); 
      }

return 0;
}

sub run {
    my ($self)  = @_;

return 0;
}


1;


