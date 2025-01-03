=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2025] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::XrefProcess_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub default_options {
  my ($self) = @_;

  return {
    %{$self->SUPER::default_options()},
    'release'          => $self->o('ensembl_release'),
    'work_dir'         => $self->o('ENV', 'BASE_DIR'),
    'sql_dir'          => $self->o('work_dir')."/ensembl/misc-scripts/xref_mapping",

    # Parameters for source data
    'config_file'      => $self->o('work_dir')."/ensembl-production/modules/Bio/EnsEMBL/Production/Pipeline/Xrefs/xref_sources.json",
    'source_url'       => '',
    'source_xref'      => '',

    # Parameters for 'job_factory'
    'species'          => [],
    'antispecies'      => [],
    'division'         => [],
    'run_all'          => 0,

    # Parameters for xref database
    'xref_url'         => '',
    'xref_user'        => '',
    'xref_pass'        => '',
    'xref_host'        => '',
    'xref_port'        => '',

    # Don't need lots of retries for most analyses
    'hive_default_max_retry_count' => 1,

    # Datachecks
    history_file   => undef,
    dc_config_file => undef,
    old_server_uri => undef
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
  {
    -logic_name => 'init_pipeline',
    -module => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
    -input_ids  => [{}],
    -flow_into  => {
      '1->A' => 'schedule_species',
      'A->1' => 'EmailAdvisoryXrefReport'
    },
    -rc_name    => 'default',
  },
  {
    -logic_name => 'schedule_species',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
    -comment    => 'Creates a job for each species for the pipeline to run on, depending on -species, -antispecies, and -run_all options.',
    -parameters => {
      db_url => $self->o('source_url'),
      species     => $self->o('species'),
      antispecies => $self->o('antispecies'),
      division    => $self->o('division'),
      run_all     => $self->o('run_all'),
    },
    -flow_into  => {
      '2->A' => 'schedule_source',
      'A->2' => 'schedule_dependent_source'
    },
    -rc_name    => 'default',
  },
  {
    -logic_name => 'schedule_source',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::ScheduleSource',
    -comment    => '',
    -parameters => {
      release    => $self->o('release'),
      sql_dir    => $self->o('sql_dir'),
      priority   => 1,
      source_url => $self->o('source_url'),
      source_xref => $self->o('source_xref'),
      xref_url   => $self->o('xref_url'),
      xref_host  => $self->o('xref_host'),
      xref_port  => $self->o('xref_port'),
      xref_user  => $self->o('xref_user'),
      xref_pass  => $self->o('xref_pass'),
    },
    -flow_into  => { '2' => 'parse_source' },
    -rc_name    => '1GB_D',
    -analysis_capacity => 10,
  },
  {
    -logic_name => 'schedule_dependent_source',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::ScheduleSource',
    -parameters => {
      release    => $self->o('release'),
      sql_dir    => $self->o('sql_dir'),
      priority   => 2,
      source_url => $self->o('source_url'),
      xref_url   => $self->o('xref_url'),
      xref_host  => $self->o('xref_host'),
      xref_port  => $self->o('xref_port'),
      xref_user  => $self->o('xref_user'),
      xref_pass  => $self->o('xref_pass'),
    },
    -flow_into  => {
      '2->A' => 'parse_source',
      'A->1' => 'schedule_tertiary_source',
    },
    -rc_name    => '4GB_D',
  },
  {
    -logic_name => 'schedule_tertiary_source',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::ScheduleSource',
    -parameters => {
      release    => $self->o('release'),
      sql_dir    => $self->o('sql_dir'),
      priority   => 3,
      source_url => $self->o('source_url'),
      xref_url   => $self->o('xref_url'),
      xref_host  => $self->o('xref_host'),
      xref_port  => $self->o('xref_port'),
      xref_user  => $self->o('xref_user'),
      xref_pass  => $self->o('xref_pass'),
    },
    -flow_into  => {
      '2->A' => 'parse_source',
      'A->1' => 'dump_ensembl',
    },
    -rc_name    => 'default',
  },
  {
    -logic_name        => 'parse_source',
    -module            => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::ParseSource',
    -rc_name           => '16GB_D',
    -hive_capacity     => 300,
    -analysis_capacity => 50,
    -batch_size        => 30,
    -parameters => {
      source_xref => $self->o('source_xref'),
    },
  },
  {
    -logic_name => 'dump_ensembl',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::DumpEnsembl',
    -parameters => {
      base_path => $self->o('base_path'),
      release   => $self->o('release')
    },
    -max_retry_count => 0,
    -flow_into  => {
      '2->A' => 'dump_xref',
      'A->1' => 'schedule_mapping'
    },
    -rc_name    => '16GB_D',
  },
  {
    -logic_name => 'dump_xref',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::DumpXref',
    -parameters => {
      base_path   => $self->o('base_path'),
      release     => $self->o('release'),
      config_file => $self->o('config_file')
    },
    -max_retry_count => 0,
    -flow_into  => { 2 => 'align_factory' },
    -rc_name    => '1GB',
  },
  {
    -logic_name => 'align_factory',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::AlignmentFactory',
    -parameters => {
      base_path => $self->o('base_path'),
      release   => $self->o('release')},
    -flow_into  => { 2 => 'align' },
    -rc_name    => 'default',
  },
  {
    -logic_name        => 'align',
    -module            => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::Alignment',
    -parameters        => {
      base_path => $self->o('base_path')
    },
    -rc_name           => '16GB_D',
    -hive_capacity     => 300,
    -analysis_capacity => 300,
    -batch_size        => 5,
  },
  {
    -logic_name => 'schedule_mapping',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::ScheduleMapping',
    -parameters => {
      base_path  => $self->o('base_path'),
      release    => $self->o('release'),
      source_url => $self->o('source_url')
    },
    -flow_into  => {
      '2->A' => ['direct_xrefs', 'rnacentral_mapping'],
      'A->1' => 'mapping'
    },
    -rc_name    => '1GB',
  },
  {
    -logic_name => 'direct_xrefs',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::DirectXrefs',
    -parameters => {
      base_path => $self->o('base_path'),
      release   => $self->o('release')
    },
    -flow_into  => { 1 => 'process_alignment' },
    -rc_name    => '1GB_D',
    -analysis_capacity => 30
  },
  {
    -logic_name => 'process_alignment',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::ProcessAlignment',
    -parameters => {
      base_path => $self->o('base_path'),
      release   => $self->o('release')
    },
    -rc_name    => '1GB_D',
    -analysis_capacity => 30
  },
  {
    -logic_name => 'rnacentral_mapping',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::RNAcentralMapping',
    -parameters => {
      base_path => $self->o('base_path'),
      release   => $self->o('release')
    },
    -flow_into  => { 1 => 'uniparc_mapping' },
    -rc_name    => 'default',
    -hive_capacity => 300,
    -analysis_capacity => 30
  },
  {
    -logic_name => 'uniparc_mapping',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::UniParcMapping',
    -parameters => {
      base_path => $self->o('base_path'),
      release   => $self->o('release')
    },
    -flow_into  => { 1 => 'coordinate_mapping' },
    -rc_name    => '1GB',
    -hive_capacity => 300,
    -analysis_capacity => 30
  },
  {
    -logic_name => 'coordinate_mapping',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::CoordinateMapping',
    -parameters => {
      base_path => $self->o('base_path'),
      release   => $self->o('release')
    },
    -rc_name    => '16GB',
    -analysis_capacity => 30
  },
  {
    -logic_name => 'mapping',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::Mapping',
    -parameters => {
      base_path => $self->o('base_path'),
      release   => $self->o('release')
    },
    -flow_into  => {
      '1->A' => 'RunXrefCriticalDatacheck',
      'A->1' => 'RunXrefAdvisoryDatacheck'
    },
    -rc_name    => '16GB_D',
    -analysis_capacity => 30,
  },
  {
      -logic_name        => 'RunXrefCriticalDatacheck',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -batch_size        => 10,
      -parameters        => {
          datacheck_names  => [ 'ForeignKeys' ],
          datacheck_groups => [ 'xref_mapping' ],
          datacheck_types  => [ 'critical' ],
          registry_file    => $self->o('registry'),
          config_file      => $self->o('dc_config_file'),
          history_file     => $self->o('history_file'),
          old_server_uri   => $self->o('old_server_uri'),
          failures_fatal   => 1,
      },
      -rc_name           => '1GB',
  },
  {
    -logic_name        => 'RunXrefAdvisoryDatacheck',
    -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
    -max_retry_count   => 1,
    -batch_size        => 10,
    -analysis_capacity => 10,
    -parameters        => {
      datacheck_groups => ['xref_mapping'],
      datacheck_types  => ['advisory'],
      registry_file    => $self->o('registry'),
      config_file      => $self->o('dc_config_file'),
      history_file     => $self->o('history_file'),
      old_server_uri   => $self->o('old_server_uri'),
      failures_fatal   => 0,
    },
    -flow_into         => { 4 => 'AdvisoryXrefReport' },
    -rc_name           => '1GB',

  },
  {
    -logic_name => 'AdvisoryXrefReport',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::AdvisoryXrefReport',
    -rc_name    => 'default'
  },
  {
    -logic_name => 'EmailAdvisoryXrefReport',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::EmailAdvisoryXrefReport',
    -parameters => {
      email        => $self->o('email'),
      pipeline_name => $self->o('pipeline_name'),
      base_path => $self->o('base_path')
    },
    -rc_name    => 'default',
    -flow_into  => { 1 => 'notify_by_email' }
  },
  {
    -logic_name => 'notify_by_email',
    -module     => 'Bio::EnsEMBL::Production::Pipeline::Xrefs::EmailNotification',
    -parameters => {
      email        => $self->o('email'),
      pipeline_name => $self->o('pipeline_name')
    },
    -rc_name    => 'default'
  }
  ];
}


sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    'pipeline_part' => 'process'
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands},
    $self->db_cmd('CREATE TABLE updated_species (species_name varchar(255) NOT NULL)'),
    $self->db_cmd('CREATE TABLE advisory_dc_report (db_name varchar(255) NOT NULL, datacheck_name varchar(255), datacheck_output MEDIUMTEXT)')
  ];
}

1;
