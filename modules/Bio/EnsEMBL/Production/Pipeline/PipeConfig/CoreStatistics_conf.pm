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
    pepstats_tmpdir => '/scratch',

    history_file => undef,
  };
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
    %{ $self->SUPER::pipeline_wide_parameters() },
    release   => $self->o('release'),
    bin_count => $self->o('bin_count'),
    max_run   => $self->o('max_run'),
  };
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
      -rc_name         => 'normal',
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
                            '3->A' => ['ChromosomeRelatedTasks'],
                            'A->1' => ['SpeciesFactory_All'],
                          },
      -rc_name         => 'normal',
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
                            '2' => ['GeneRelatedTasks'],
                          },
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'GeneRelatedTasks',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 1,
      -flow_into       => {
                            '1->A' => [
                                        'ConstitutiveExons',
                                        'GeneCount',
                                        'GeneGC',
                                        'PepStats',
                                      ],
                            'A->1' => ['GenomeStats'],
                          },
    },

    {
      -logic_name      => 'ChromosomeRelatedTasks',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 1,
      -flow_into       => [
                            'CodingDensity',
                            'PseudogeneDensity',
                            'ShortNonCodingDensity',
                            'LongNonCodingDensity',
                            'PercentGC',
                            'PercentRepeat',
                          ],
    },

    {
      -logic_name      => 'ConstitutiveExons',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::ConstitutiveExons',
      -parameters      => {
                            dbtype => 'core',
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'GeneCount',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::GeneCount',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -rc_name         => 'normal',
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
      -rc_name         => 'mem_high',
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
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'GeneGC',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::GeneGCBatch',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -rc_name         => 'normal',
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
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'GenomeStats',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::GenomeStats',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -rc_name         => 'normal',
      -flow_into       => ['GenomeStats_Datacheck'],
    },

    {
      -logic_name      => 'GenomeStats_Datacheck',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters      => {
                            datacheck_names => ['GenomeStatistics'],
                            history_file    => $self->o('history_file'),
                            failures_fatal  => 1,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'PepStats',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Production::PepStatsBatch',
      -parameters      => {
                            tmpdir          => $self->o('pepstats_tmpdir'),
                            pepstats_binary => $self->o('pepstats_binary'),
                            dbtype          => 'core',
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -rc_name         => 'mem_scratch',
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
      -rc_name         => 'normal',
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
      -rc_name         => 'normal',
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
      -rc_name         => 'normal',
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
      -rc_name         => 'normal',
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
      -rc_name         => 'normal',
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
      -rc_name         => 'normal',
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
      -rc_name         => 'normal',
    },

    {
      -logic_name => 'Notify',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::EmailSummaryCore',
      -parameters => {
                       email   => $self->o('email'),
                       subject => $self->o('pipeline_name').' has finished',
                     },
      -rc_name    => 'normal',
    },

  ];
}

sub resource_classes {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::resource_classes},
    'mem_high'    => {'LSF' => '-q production-rh7 -M 8000 -R "rusage[mem=8000]"'},
    'mem_scratch' => {'LSF' => '-q production-rh7 -M 4000 -R "rusage[mem=4000,scratch=1000]"'},
  }
}

1;
