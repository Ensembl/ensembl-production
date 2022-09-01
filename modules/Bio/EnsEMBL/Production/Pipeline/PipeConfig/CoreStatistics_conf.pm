=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::PipeConfig::CoreStatistics_conf

=head1 DESCRIPTION

Configuration for calculating statistics and density features.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::CoreStatistics_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::ApiVersion qw/software_version/;
use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    release => software_version(),

    pipeline_name => 'core_statistics_'.$self->o('release'),

    species      => [],
    division     => [],
    run_all      => 0,
    antispecies  => [],
    meta_filters => {},

    bin_count => '150',
    max_run   => '100',

    pepstats_binary => 'pepstats',

    history_file => undef,
    forced_species => [],
    include_readthrough => 0,
    run_all_forced => 0,
  };
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
    %{ $self->SUPER::pipeline_wide_parameters() },
    scratch_dir => $self->o('scratch_large_dir'),
    release     => $self->o('release'),
    bin_count   => $self->o('bin_count'),
    max_run     => $self->o('max_run'),
    forced_species => $self->o('forced_species')
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('scratch_large_dir'),
  ];
}

# Implicit parameter propagation throughout the pipeline.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack'  => 1,
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name      => 'InitialisePipeline',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -input_ids       => [ {} ],
      -max_retry_count => 1,
      -flow_into       => {
                            '1->A' => ['SpeciesFactory_Chromosome'],
                            'A->1' => ['Notify'],
                          },
    },

    {
      -logic_name      => 'SpeciesFactory_Chromosome',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -parameters      => {
                            species      => $self->o('species'),
                            division     => $self->o('division'),
                            run_all      => $self->o('run_all'),
                            antispecies  => $self->o('antispecies'),
                            meta_filters => $self->o('meta_filters'),
                         },
      -max_retry_count => 1,
      -flow_into       => {
                            '3->A' => ['CheckStatistics_Chromosome'],
                            'A->1' => ['SpeciesFactory_All'],
                          },
      -rc_name         => '2GB',
    },

    {
      -logic_name      => 'SpeciesFactory_All',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -parameters      => {
                            species      => $self->o('species'),
                            division     => $self->o('division'),
                            run_all      => $self->o('run_all'),
                            antispecies  => $self->o('antispecies'),
                            meta_filters => $self->o('meta_filters'),
                         },
      -max_retry_count => 1,
      -flow_into       => {
                            '2' => ['CheckStatistics_All'],
                          },
      -rc_name         => '2GB',
    },

    {
      -logic_name      => 'CheckStatistics_Chromosome',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters      => {
                            datacheck_groups => ['core_statistics'],
                            history_file     => $self->o('history_file'),
                            failures_fatal   => 0,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
      -flow_into       => WHEN(
                            '#run_all_forced# || #species# ~~ @{#forced_species#} || #datachecks_failed#'=>
                            [
                              'CodingDensity',
                              'PseudogeneDensity',
                              'ShortNonCodingDensity',
                              'LongNonCodingDensity',
                              'PercentGC',
                              'PercentRepeat',
                            ]
                          ),
      -rc_name         => '2GB',
    },

    {
      -logic_name      => 'CheckStatistics_All',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters      => {
                            datacheck_groups => ['core_statistics'],
                            history_file     => $self->o('history_file'),
                            failures_fatal   => 0,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
      -rc_name         => '2GB',
      -flow_into       => {
                            '1->A' => WHEN(
                              '#run_all_forced# || #species# ~~ @{#forced_species#} || #datachecks_failed#' => [
                                'ConstitutiveExons',
                                'GeneCount',
                                'GeneGC',
                                'PepStats',
                              ]
                            ),
                            'A->1' => WHEN(
                              '#run_all_forced# || #species# ~~ @{#forced_species#} || #datachecks_failed#' => ['GenomeStats']
                            ),
                          },
    },

    {
      -logic_name      => 'ConstitutiveExons',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::ConstitutiveExons',
      -parameters      => {
                            dbtype => 'core',
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
    },

    {
      -logic_name      => 'GeneCount',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::GeneCount',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -parameters      => {
                            include_readthrough => $self->o('include_readthrough'),
                          },
      -flow_into       => {
                             '1' => ['GeneCounts_Datacheck'],
                            '-1' => ['GeneCount_HighMem'],
                          },
    },

    {
      -logic_name      => 'GeneCount_HighMem',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::GeneCount',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -rc_name         => '8GB',
      -flow_into       => ['GeneCounts_Datacheck'],
    },

    {
      -logic_name      => 'GeneCounts_Datacheck',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters      => {
                            datacheck_names => ['GeneCounts'],
                            history_file    => $self->o('history_file'),
                            failures_fatal  => 1,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
    },

    {
      -logic_name      => 'GeneGC',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::GeneGCBatch',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -flow_into       => ['GeneGC_Datacheck'],
    },

    {
      -logic_name      => 'GeneGC_Datacheck',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters      => {
                            datacheck_names => ['GeneGC'],
                            history_file    => $self->o('history_file'),
                            failures_fatal  => 1,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
      -rc_name         => '2GB',
    },

    {
      -logic_name      => 'GenomeStats',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::GenomeStats',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -flow_into       => ['RunDataChecks'],
    },

    {
      -logic_name      => 'RunDataChecks',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters      => {
                            datacheck_names => ['DensityFeatures', 'GenomeStatistics'],
                            history_file    => $self->o('history_file'),
                            failures_fatal  => 1,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
      -rc_name         => '2GB',
    },

    {
      -logic_name      => 'PepStats',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::PepStatsBatch',
      -parameters      => {
                            tmpdir          => '#scratch_dir#',
                            pepstats_binary => $self->o('pepstats_binary'),
                            dbtype          => 'core',
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -rc_name         => '4GB',
      -flow_into       => ['PepStats_Datacheck'],
    },

    {
      -logic_name      => 'PepStats_Datacheck',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters      => {
                            datacheck_names => ['PepstatsAttributes'],
                            history_file    => $self->o('history_file'),
                            failures_fatal  => 1,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
    },

    {
      -logic_name      => 'CodingDensity',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::CodingDensity',
      -parameters      => {
                            logic_name => 'codingdensity',
                            value_type => 'sum',
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
    },

    {
      -logic_name      => 'PseudogeneDensity',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::PseudogeneDensity',
      -parameters      => {
                            logic_name => 'pseudogenedensity',
                            value_type => 'sum',
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
    },

    {
      -logic_name      => 'ShortNonCodingDensity',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::ShortNonCodingDensity',
      -parameters      => {
                            logic_name => 'shortnoncodingdensity',
                            value_type => 'sum',
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
    },

    {
      -logic_name      => 'LongNonCodingDensity',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::LongNonCodingDensity',
      -parameters      => {
                            logic_name => 'longnoncodingdensity',
                            value_type => 'sum',
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
    },

    {
      -logic_name      => 'PercentGC',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::PercentGC',
      -parameters      => {
                            logic_name => 'percentgc',
                            value_type => 'ratio',
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -rc_name         => '2GB',
    },

    {
      -logic_name      => 'PercentRepeat',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::PercentRepeat',
      -parameters      => {
                            logic_name => 'percentagerepeat',
                            value_type => 'ratio',
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -rc_name         => '8GB',
    },

    {
      -logic_name => 'Notify',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::EmailSummaryCore',
      -parameters => {
                       email   => $self->o('email'),
                       subject => $self->o('pipeline_name').' has finished',
                     },
      -flow_into  => ['TidyScratch'],
    },

    {
      -logic_name        => 'TidyScratch',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              cmd => 'rm -rf #scratch_dir#',
                            },
    },

  ];
}

1;
