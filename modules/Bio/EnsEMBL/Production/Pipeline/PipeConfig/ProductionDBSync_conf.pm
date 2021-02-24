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

=head1 NAME
Bio::EnsEMBL::Production::Pipeline::PipeConfig::ProductionDBSync_conf

=head1 DESCRIPTION
A pipeline for synchronising controlled tables and analysis descriptions from
the production database to core, core-like, funcgen, and variation databases.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::ProductionDBSync_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    populate_controlled_tables    => 1,
    populate_analysis_description => 1,
    group => [],
    email_on_completion => 0,

    # DB Factory
    species      => [],
    antispecies  => [
        'fungi_ascomycota1_collection',
        'fungi_ascomycota2_collection',
        'fungi_ascomycota3_collection',
        'mus_caroli',
        'mus_musculus_129s1svimj',
        'mus_musculus_aj',
        'mus_musculus_akrj',
        'mus_musculus_balbcj',
        'mus_musculus_c3hhej',
        'mus_musculus_c57bl6nj',
        'mus_musculus_casteij',
        'mus_musculus_cbaj',
        'mus_musculus_dba2j',
        'mus_musculus_fvbnj',
        'mus_musculus_lpj',
        'mus_musculus_nodshiltj',
        'mus_musculus_nzohlltj',
        'mus_musculus_pwkphj',
        'mus_musculus_wsbeij',
        'mus_pahari1',
        'mus_spretus'
    ],
    division     => [],
    dbname       => [],
    run_all      => 0,
    meta_filters => {},

    # Datachecks
    history_file         => undef,
    datacheck_output_dir => undef,
  };
}

# Implicit parameter propagation throughout the pipeline.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  my @cmds = (
    'mkdir -p '.$self->o('backup_dir')
  );
  if (defined $self->o('datacheck_output_dir')) {
    push @cmds, 'mkdir -p '.$self->o('datacheck_output_dir');
  }

  return [
    @{$self->SUPER::pipeline_create_commands},
    @cmds
  ];
}

sub pipeline_wide_parameters {
 my ($self) = @_;

 return {
   %{$self->SUPER::pipeline_wide_parameters},
   'populate_controlled_tables' => $self->o('populate_controlled_tables'),
   'populate_analysis_description' => $self->o('populate_analysis_description'),
 };
}

sub resource_classes {
  my ($self) = @_;

  return {
    %{$self->SUPER::resource_classes},
    '16GB' => {'LSF' => '-q production-rh74 -M 16000 -R "rusage[mem=16000]"'},
  }
}

sub pipeline_analyses {
  my $self = shift @_;

  return [
    {
      -logic_name        => 'GroupFactory',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -max_retry_count   => 1,
      -input_ids         => [ {} ],
      -parameters        => {
                              inputlist    => $self->o('group'),
                              column_names => ['group'],
                            },
       -flow_into        => {
                              '2->A' => ['DbFactory'],
                              'A->1' => ['ProductionDBSyncEmail'],
                            }
    },
    {
      -logic_name        => 'ProductionDBSyncEmail',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 1,
      -analysis_capacity => 1,
      -parameters        => {
                              email_on_completion => $self->o('email_on_completion')
                            },
      -flow_into         => WHEN('#email_on_completion#' => ['EmailReport']),
    },
    {
      -logic_name        => 'DbFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              species      => $self->o('species'),
                              antispecies  => $self->o('antispecies'),
                              division     => $self->o('division'),
                              dbname       => $self->o('dbname'),
                              run_all      => $self->o('run_all'),
                              meta_filters => $self->o('meta_filters'),
                            },
       -flow_into        => {
                              '2' =>
                                WHEN(
                                  '#populate_controlled_tables# && #group# ne "funcgen"' =>
                                    ['BackupControlledTables'],
                                  '#populate_analysis_description# && #group# ne "variation"' =>
                                    ['BackupAnalysisDescription'],
                                )
                            }
    },
    {
      -logic_name        => 'BackupControlledTables',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DatabaseDumper',
      -max_retry_count   => 1,
      -analysis_capacity => 20,
      -parameters        => {
                              db_type     => '#group#',
                              table_list  => [
                                'attrib_type',
                                'biotype',
                                'external_db',
                                'misc_set',
                                'unmapped_reason',
                                'attrib',
                                'attrib_set'
                              ],
                              output_file => catdir($self->o('backup_dir'), '#dbname#', 'controlled_tables_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['PopulateControlledTables'],
    },
    {
      -logic_name        => 'BackupAnalysisDescription',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DatabaseDumper',
      -max_retry_count   => 1,
      -analysis_capacity => 20,
      -parameters        => {
                              db_type     => '#group#',
                              table_list  => [
                                'analysis_description',
                              ],
                              output_file => catdir($self->o('backup_dir'), '#dbname#', 'analysis_description_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['PopulateAnalysisDescription'],
    },
    {
      -logic_name        => 'PopulateControlledTables',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProductionDBSync::PopulateControlledTables',
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -flow_into         => ['RunDatachecksControlledTables']
    },
    {
      -logic_name        => 'PopulateAnalysisDescription',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProductionDBSync::PopulateAnalysisDescription',
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -flow_into         => {
                              '1->A' => ['RunDatachecksADCritical'],
                              'A->1' => ['RunDatachecksADAdvisory'],
                            },
    },
    {
      -logic_name        => 'RunDatachecksControlledTables',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              datacheck_groups => ['controlled_tables'],
                              datacheck_types  => ['critical'],
                              registry_file    => $self->o('registry'),
                              history_file     => $self->o('history_file'),
                              output_file      => catdir($self->o('datacheck_output_dir'), '#dbname#_ControlledTables.txt'),
                              failures_fatal   => 1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '-1' => ['RunDatachecksControlledTables_HighMem'],
                            },
    },
    {
      -logic_name        => 'RunDatachecksControlledTables_HighMem',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              datacheck_groups => ['controlled_tables'],
                              datacheck_types  => ['critical'],
                              registry_file    => $self->o('registry'),
                              history_file     => $self->o('history_file'),
                              output_file      => catdir($self->o('datacheck_output_dir'), '#dbname#_ControlledTables.txt'),
                              failures_fatal   => 1,
                            },
      -rc_name           => '16GB',
    },
    {
      -logic_name        => 'RunDatachecksADCritical',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              datacheck_groups => ['analysis_description'],
                              datacheck_types  => ['critical'],
                              registry_file    => $self->o('registry'),
                              history_file     => $self->o('history_file'),
                              output_file      => catdir($self->o('datacheck_output_dir'), '#dbname#_ADCritical.txt'),
                              failures_fatal   => 1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '-1' => ['RunDatachecksADCritical_HighMem'],
                            },
    },
    {
      -logic_name        => 'RunDatachecksADCritical_HighMem',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              datacheck_groups => ['analysis_description'],
                              datacheck_types  => ['critical'],
                              registry_file    => $self->o('registry'),
                              history_file     => $self->o('history_file'),
                              output_file      => catdir($self->o('datacheck_output_dir'), '#dbname#_ADCritical.txt'),
                              failures_fatal   => 1,
                            },
      -rc_name           => '16GB',
    },
    {
      -logic_name        => 'RunDatachecksADAdvisory',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              datacheck_groups => ['analysis_description'],
                              datacheck_types  => ['advisory'],
                              registry_file    => $self->o('registry'),
                              history_file     => $self->o('history_file'),
                              output_file      => catdir($self->o('datacheck_output_dir'), '#dbname#_ADAdvisory.txt'),
                              failures_fatal   => 0,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '-1' => 'RunDatachecksADAdvisory_HighMem',
                              '4'  => 'EmailReportADAdvisory'
                            },
    },
    {
      -logic_name        => 'RunDatachecksADAdvisory_HighMem',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              datacheck_groups => ['analysis_description'],
                              datacheck_types  => ['advisory'],
                              registry_file    => $self->o('registry'),
                              history_file     => $self->o('history_file'),
                              output_file      => catdir($self->o('datacheck_output_dir'), '#dbname#_ADAdvisory.txt'),
                              failures_fatal   => 0,
                            },
      -rc_name           => '16GB',
      -flow_into         => {
                              '4' => 'EmailReportADAdvisory'
                            },
    },
    {
      -logic_name        => 'EmailReportADAdvisory',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::EmailNotify',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              email         => $self->o('email'),
                              pipeline_name => $self->o('pipeline_name'),
                            },
      -rc_name           => 'normal',
    },
    {
      -logic_name        => 'EmailReport',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::ProductionDBSync::EmailReport',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              email         => $self->o('email'),
                              pipeline_name => $self->o('pipeline_name'),
                              history_file  => $self->o('history_file'),
                              output_dir    => $self->o('datacheck_output_dir'),
                            },
      -rc_name           => 'normal',
    },

  ];
}

1;
