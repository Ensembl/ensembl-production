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

Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::SourceFactory;

=head1 DESCRIPTION

For the given array of projection configs, flow the species parameters,
to be processed up by a SpeciesFactory module. Run sequentially,
in the given order, by recursively flowing, removing one config
from the hash each time.

=cut
package Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::SourceFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub write_output {
  my ($self) = @_;

  my $config = $self->param_required('config');

  if (scalar @$config) {
    my $params = shift @$config;
    $$params{'config_type'} = $self->param_required('config_type');

    $self->dataflow_output_id($params, 4);
    $self->dataflow_output_id({config => $config}, 3);
  }
}

1;
