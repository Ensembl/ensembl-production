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

sub write_output {
    my ($self)  = @_;

    my $g_config = $self->param_required('g_config');

    foreach my $pair (keys $g_config){
       my $source                 = $g_config->{$pair}->{'source'};
       my $species                = $g_config->{$pair}->{'species'};
       my $antispecies            = $g_config->{$pair}->{'antispecies'};
       my $division               = $g_config->{$pair}->{'division'};
       my $run_all                = $g_config->{$pair}->{'run_all'};       
       my $method_link_type       = $g_config->{$pair}->{'method_link_type'};  
       my $homology_types_allowed = $g_config->{$pair}->{'homology_types_allowed'};
       my $percent_id_filter      = $g_config->{$pair}->{'percent_id_filter'};
       my $percent_cov_filter     = $g_config->{$pair}->{'percent_cov_filter'};
       my $taxon_filter           = $g_config->{$pair}->{'taxon_filter'};
       my $geneName_source        = $g_config->{$pair}->{'geneName_source'};
       my $geneDesc_rules         = $g_config->{$pair}->{'geneDesc_rules'};
       my $geneDesc_rules_target  = $g_config->{$pair}->{'geneDesc_rules_target'};

       $self->dataflow_output_id(
		{'source'      		  => $source, 
		 'species'     		  => $species, 
		 'antispecies' 		  => $antispecies, 
  		 'division'    	  	  => $division, 
		 'run_all' 		  => $run_all,
		 'method_link_type' 	  => $method_link_type,
                 'homology_types_allowed' => $homology_types_allowed,
  		 'percent_id_filter'      => $percent_id_filter,
		 'percent_cov_filter'     => $percent_cov_filter,
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


