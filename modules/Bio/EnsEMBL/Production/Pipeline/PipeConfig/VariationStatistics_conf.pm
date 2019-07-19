=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::PipeConfig::VariationStatistics_conf

=head1 DESCRIPTION

Configuration for calculating variation statistics.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::VariationStatistics_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::CoreStatistics_conf');

use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'variation_statistics_'.$self->o('release'),
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name       => 'SpeciesFactory',
      -module           => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -input_ids        => [ {} ],
      -parameters       => {
                             species      => $self->o('species'),
                             division     => $self->o('division'),
                             run_all      => $self->o('run_all'),
                             antispecies  => $self->o('antispecies'),
                             meta_filters => $self->o('meta_filters'),
                           },
      -max_retry_count  => 0,
      -flow_into        => {
                             '4->A' => ['VariationTasks'],
                             'A->1' => ['Notify'],
                           },
      -rc_name          => 'normal',
    },

    {
      -logic_name      => 'VariationTasks',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 1,
      -flow_into       => {
                            '1->A' => [
                                        'SnpCount',
                                        'SnpDensity',
                                      ],
                            'A->1' => ['GenomeStats'],
                          },
      -rc_name         => 'normal',
    },

    {
      -logic_name       => 'SnpCount',
      -module           => 'Bio::EnsEMBL::Production::Pipeline::Production::SnpCount',
      -max_retry_count  => 1,
      -hive_capacity    => 50,
      -rc_name          => 'normal',
    },

    {
      -logic_name       => 'SnpDensity',
      -module           => 'Bio::EnsEMBL::Production::Pipeline::Production::SnpDensity',
      -parameters       => {
                             table      => 'gene', 
                             logic_name => 'snpdensity',
                             value_type => 'sum',
                           },
      -max_retry_count  => 1,
      -hive_capacity    => 50,
      -rc_name          => 'normal',
    },

    {
      -logic_name      => 'GenomeStats',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::GenomeStats',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -flow_into       => {
                            1 => { 'RunDataChecks' => {'group' => 'core'} }
                          },
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'RunDataChecks',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters      => {
                            datacheck_names => ['DensitySNPs', 'GenomeStatistics', 'SNPCounts'],
                            history_file    => $self->o('history_file'),
                            registry_file   => $self->o('registry_file'),
                            failures_fatal  => 1,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
      -rc_name         => 'normal',
    },

    {
      -logic_name => 'Notify',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::EmailSummaryVariation',
      -parameters => {
                       email   => $self->o('email'),
                       subject => $self->o('pipeline_name').' has finished',
                     },
      -rc_name    => 'normal',
    },

  ];
}

1;
