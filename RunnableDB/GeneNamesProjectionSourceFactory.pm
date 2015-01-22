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

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneNamesProjectionSourceFactory;

=head1 DESCRIPTION

=head1 AUTHOR

ckong

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneNamesProjectionSourceFactory;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::Base');

sub fetch_input {
    my ($self) 	= @_;

    my $gn_config = $self->param_required('gn_config') || die "'gn_config' is an obligatory parameter";
    $self->param('gn_config', $gn_config);

return 0;
}

sub write_output {
    my ($self)  = @_;

    my $gn_config = $self->param('gn_config');

    foreach my $pair (keys $gn_config){
       my $source                 = $gn_config->{$pair}->{'source'};
       my $species                = $gn_config->{$pair}->{'species'};
       my $antispecies            = $gn_config->{$pair}->{'antispecies'};
       my $division               = $gn_config->{$pair}->{'division'};
       my $run_all                = $gn_config->{$pair}->{'run_all'};       
       my $method_link_type       = $gn_config->{$pair}->{'gn_method_link_type'};  
       my $homology_types_allowed = $gn_config->{$pair}->{'gn_homology_types_allowed'};
       my $percent_id_filter      = $gn_config->{$pair}->{'gn_percent_id_filter'};
       my $taxon_filter           = $gn_config->{$pair}->{'taxon_filter'};
       my $geneName_source        = $gn_config->{$pair}->{'geneName_source'};
       my $geneDesc_rules         = $gn_config->{$pair}->{'geneDesc_rules'};
       my $geneDesc_rules_target  = $gn_config->{$pair}->{'geneDesc_rules_target'};

       $self->dataflow_output_id(
		{'source'      		  => $source, 
		 'species'     		  => $species, 
		 'antispecies' 		  => $antispecies, 
  		 'division'    	  	  => $division, 
		 'run_all' 		  => $run_all,
		 'method_link_type' 	  => $method_link_type,
                 'homology_types_allowed' => $homology_types_allowed,
  		 'percent_id_filter'      => $percent_id_filter,
		 'taxon_filter'           => $taxon_filter,
		 'geneName_source'	  => $geneName_source,
		 'geneDesc_rules'	  => $geneDesc_rules,
		 'geneDesc_rules_target'  => $geneDesc_rules_target
		},2); 
      }
return 0;
}

sub run {
    my ($self)  = @_;

return 0;
}


1;


