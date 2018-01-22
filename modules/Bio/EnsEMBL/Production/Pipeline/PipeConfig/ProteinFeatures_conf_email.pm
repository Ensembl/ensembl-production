=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::ProteinFeatures_vb_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::ProteinFeatures_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

sub pipeline_analyses {
  my $self = shift @_;
  my $analyses = $self->SUPER::pipeline_analyses;
  for my $a (@{$analyses}) {
    if($a->{-logic_name} eq 'StoreGoXrefs') {
      $a->{-flow_into} = ['EmailReport'];
    }
  }
  push @$analyses, {
                    -logic_name        => 'EmailReport',
                    -module            => 'Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::EmailReport',
                    -hive_capacity     => 10,
                    -max_retry_count   => 1,
                    -parameters        => {
                                           email   => $self->o('email'),
                                           subject => 'Protein features pipeline: report for #species#',
                                          },
                    -rc_name           => 'normal',
                   };
  return $analyses;
}
1;
