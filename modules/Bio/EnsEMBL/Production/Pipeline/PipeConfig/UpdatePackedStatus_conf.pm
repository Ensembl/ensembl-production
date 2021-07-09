
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::UpdatePackedStatus_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    
    species      => [],
    antispecies  => [],
    taxons       => [],
    antitaxons   => [],
    division     => [],
    run_all      => 0,
    meta_filters => {},
    dbname       => [],

    packed => 1,

    secondary_release => undef,
  };
}

sub pipeline_analyses {
  my $self = shift @_;
  
  return [
    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -max_retry_count   => 0,
      -input_ids         => [ {} ],
      -parameters        => {
                              species      => $self->o('species'),
                              antispecies  => $self->o('antispecies'),
                              taxons       => $self->o('taxons'),
                              antitaxons   => $self->o('antitaxons'),
                              division     => $self->o('division'),
                              run_all      => $self->o('run_all'),
                              meta_filters => $self->o('meta_filters'),
                              dbname       => $self->o('dbname'),
                            },
      -flow_into         => {
                              '2' => ['UpdatePackedStatus'],
                            },
    },
    {
      -logic_name        => 'UpdatePackedStatus',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::UpdatePackedStatus',
      -max_retry_count   => 0,
      -parameters        => {
                              packed            => $self->o('packed'),
                              ensembl_release   => $self->o('ensembl_release'),
                              secondary_release => $self->o('secondary_release'),
                            },
    },
  ];
}

1;
