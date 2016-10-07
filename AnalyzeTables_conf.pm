package Bio::EnsEMBL::EGPipeline::PipeConfig::AnalyzeTables_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    
    pipeline_name => 'analyze_tables_'.$self->o('ensembl_release'),
    
    species      => [],
    division     => [],
    run_all      => 0,
    antispecies  => [],
    meta_filters => {},
    
    optimize_tables => 0,
  };
}

sub beekeeper_extra_cmdline_options {
  my $self = shift;
  return "-reg_conf ".$self->o("registry");
}

sub pipeline_analyses {
  my ($self) = @_;
  
  return [
    {
      -logic_name      => 'SpeciesFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -parameters      => {
                            species         => $self->o('species'),
                            division        => $self->o('division'),
                            run_all         => $self->o('run_all'),
                            antispecies     => $self->o('antispecies'),
                            meta_filters    => $self->o('meta_filters'),
                            core_flow       => 2,
                            chromosome_flow => 0,
                            regulation_flow => 3,
                            variation_flow  => 4,
                          },
      -input_ids       => [ {} ],
      -max_retry_count => 1,
      -flow_into       => {
                            '2' => ['AnalyzeTablesCore', 'AnalyzeTablesOtherFeatures'],
                            '3' => ['AnalyzeTablesRegulation'],
                            '4' => ['AnalyzeTablesVariation'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name        => 'AnalyzeTablesCore',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalyzeTables',
      -parameters        => {
                              optimize_tables => $self->o('optimize_tables'),
                              db_types        => ['core'],
                            },
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -rc_name           => 'normal-rh7',
    },
    
    {
      -logic_name        => 'AnalyzeTablesOtherFeatures',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalyzeTables',
      -parameters        => {
                              optimize_tables => $self->o('optimize_tables'),
                              db_types        => ['otherfeatures'],
                            },
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -rc_name           => 'normal-rh7',
    },
    
    {
      -logic_name        => 'AnalyzeTablesRegulation',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalyzeTables',
      -parameters        => {
                              optimize_tables => $self->o('optimize_tables'),
                              db_types        => ['funcgen'],
                            },
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -rc_name           => 'normal-rh7',
    },
    
    {
      -logic_name        => 'AnalyzeTablesVariation',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalyzeTables',
      -parameters        => {
                              optimize_tables => $self->o('optimize_tables'),
                              db_types        => ['variation'],
                            },
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -rc_name           => 'normal-rh7',
    },
  ];
}

1;
