=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::PipeConfig::SampleDataCopy_conf

=head1 DESCRIPTION

Copy sample data from the previous release.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::SampleDataCopy_conf;

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
    division     => [],
    run_all      => 0,
    meta_filters => {},

    # Config/history files for storing record of datacheck run.
    config_file  => undef,
    history_file => undef,
  };
}

# Ensures that species output parameter gets propagated implicitly.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name      => 'SpeciesFactory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -max_retry_count => 1,
      -input_ids       => [ {} ],
      -parameters      => {
                            species      => $self->o('species'),
                            division     => $self->o('division'),
                            run_all      => $self->o('run_all'),
                            antispecies  => $self->o('antispecies'),
                            meta_filters => $self->o('meta_filters'),
                           },
      -flow_into       => {
                            '2' => ['CopySampleData'],
                          },
    },

    {
      -logic_name      => 'CopySampleData',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::SampleData::CopySampleData',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -parameters      => {
                            release => $self->o('ensembl_release'),
                            prev_server_url => $self->o('prev_server_url'),
                          },
      -flow_into       => {
                            '3' => ['RunDataChecks'],
                          },
    },

    {
      -logic_name      => 'RunDataChecks',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
      -parameters      => {
                            datacheck_groups => ['meta_sample'],
                            config_file      => $self->o('config_file'),
                            history_file     => $self->o('history_file'),
                            registry_file    => $self->o('registry'),
                            failures_fatal   => 1,
                          },
    },
  ];
}

1;
