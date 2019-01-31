=head1 LICENSE

Copyright [1999-2019] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=pod

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::PipeConfig::PostCompara_conf_metazoa

=head1 DESCRIPTION

Configuration for running the Post Compara pipeline, which
run the Gene name, description and GO projections as well as Gene coverage.

=head1 Author

ckong

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::PostCompara_conf_metazoa;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::PostCompara_conf');
use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
  my ($self) = @_;    
  return {
          # inherit other stuff from the base class
          %{ $self->SUPER::default_options() },
          
          flag_GeneNames    => '0',
          flag_GeneDescr    => '0',
          flag_GeneCoverage => '1',
          ## GeneName Projection 
          gn_config => { 
                        '1'=>{
                             }, 
                       },
          
          ## GeneDescription Projection 
          gd_config => { 
                        '1'=>{
                             }, 
                       },
         };
}
1;
