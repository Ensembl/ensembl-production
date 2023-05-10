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

=cut


=pod

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_conf

=head1 DESCRIPTION

Gene name and description projection

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneNameDescProjection_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use File::Spec::Functions qw(catdir);
use Bio::EnsEMBL::Compara::PipeConfig::Parts::UpdateMemberNamesDescriptions;


use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

sub default_options {
  my ($self) = @_;

  return {
    %{ $self->SUPER::default_options() },

    compara_division => undef, # Eg: protists, fungi, plants, metazoa, multi
    pipeline_name    => 'gene_name_desc_projection_'.$self->o('compara_division').'_'.$self->o('ensembl_release'),

    # Analysis associated with gene name projection
    logic_name => 'xref_projection',

    store_projections => 1,
    exclude_species  => [],

    backup_tables => [
      'analysis',
      'analysis_description',
      'external_db',
      'external_synonym',
      'gene',
      'object_xref',
      'xref',
    ],

    gn_subject => $self->o('pipeline_name').' report: gene name projection',
    gd_subject => $self->o('pipeline_name').' report: gene description projection',

    # Default parameters, redefined if necessary in gn_config and gd_config
    # hashes in sub-classes of this pipeline config.
    method_link_type       => 'ENSEMBL_ORTHOLOGUES',
    homology_types_allowed => ['ortholog_one2one'],
    is_tree_compliant      => 1,
    percent_id_filter      => 30,
    percent_cov_filter     => 66,
    gene_name_source       => [],
    project_xrefs          => 0,
    project_trans_names    => 0,
    white_list             => [],
    gene_desc_rules        => ['hypothetical', 'putative', 'unknown protein'],
    gene_desc_rules_target => ['Uncharacterized protein', 'Predicted protein', 'Gene of unknown', 'hypothetical protein'],

    # Configuration for gene name projection must be defined in sub classes
    gn_config => [],
    gd_config => [],

    # Datachecks
    history_file   => undef,
    config_file    => undef,
    old_server_uri => undef,

    # Compara update parameters
    update_capacity => '5',

  };
}

sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('pipeline_dir'),
  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    pipeline_dir => $self->o('pipeline_dir'),
    compara_db => $self->o('compara_db'),
    store_projections => $self->o('store_projections'),
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name        => 'ProjectionPipeline',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -input_ids         => [ {} ],
      -rc_name           => 'default',
      -flow_into         => {
                              '1->A' => ['BackupAndProject'],
                              'A->1' => ['EmailReport'],
                            },
    },
    {
      -logic_name        => 'BackupAndProject',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -rc_name           => 'default',
      -flow_into         => {
                              '1->A' => WHEN('#store_projections#' => ['Backup']),
                              'A->1' => ['Project'],
                            },
    },
    {
      -logic_name        => 'Backup',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -rc_name           => 'default',
      -flow_into         => {
                              '1->A' => ['SourceFactory_Backup_Names'],
                              'A->1' => ['SourceFactory_Backup_Descs'],
                            },
    },
    {
      -logic_name        => 'SourceFactory_Backup_Names',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::SourceFactory',
      -parameters        => {
                              config      => $self->o('gn_config'),
                              config_type => 'names',
                            },
      -rc_name           => 'default',
      -flow_into         => {
                              '4->A' => ['DbFactory'],
                              'A->3' => ['SourceFactory_Backup_Names'],
                            },
    },
    {
      -logic_name        => 'SourceFactory_Backup_Descs',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::SourceFactory',
      -parameters        => {
                              config      => $self->o('gd_config'),
                              config_type => 'descs',
                            },
      -rc_name           => 'default',
      -flow_into         => {
                              '4->A' => ['DbFactory'],
                              'A->3' => ['SourceFactory_Backup_Descs'],
                            },
    },
    {
      -logic_name        => 'DbFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
      -analysis_capacity => 5,
      -rc_name           => 'default',
      -flow_into         => {
                              '2' => ['BackupDatabase'],
                            },
    },
    {
      -logic_name        => 'BackupDatabase',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DatabaseDumper',
      -analysis_capacity => 5,
      -parameters        => {
                              output_file => catdir('#pipeline_dir#', '#config_type#', '#dbname#_bkp.sql.gz'),
                              table_list  => $self->o('backup_tables'),
                            },
      -rc_name           => '2GB',
      -flow_into         => ['DeleteExisting'],
    },
    {
      -logic_name        => 'DeleteExisting',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::DeleteExisting',
      -analysis_capacity => 5,
      -max_retry_count   => 0,
      -parameters        => {
                              output_file => catdir('#pipeline_dir#', '#config_type#', '#dbname#_bkp.sql.gz'),
                              table_list  => $self->o('backup_tables'),
                            },
      -flow_into         => [  WHEN('#config_type# eq "names"' => ['AnalysisSetup']) ],
    },
    {
      -logic_name        => 'AnalysisSetup',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::AnalysisSetup',
      -analysis_capacity => 5,
      -max_retry_count   => 0,
      -parameters        => {
                              logic_name => $self->o('logic_name'),
                              production_lookup  => 1,
                              delete_existing => 1,
                              db_backup_file => catdir('#pipeline_dir#', '#config_type#', '#dbname#_bkp.sql.gz'),
                            },
      -rc_name           => '2GB',
    },
    {
      -logic_name        => 'Project',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -flow_into         => {
                              '1->A' => ['SourceFactory_Names'],
                              'A->1' => ['SourceFactory_Descs'],
                             },
    },
    {
      -logic_name        => 'SourceFactory_Names',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::SourceFactory',
      -parameters        => {
                              config      => $self->o('gn_config'),
                              config_type => 'names',
                            },
      -flow_into         => {
                              '4->A' => ['TargetFactory_Names'],
                              'A->3' => ['SourceFactory_Names'],
                            },
    },
    {
      -logic_name        => 'TargetFactory_Names',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -analysis_capacity => 5,
      -rc_name           => 'default',
      -flow_into         => {
                              '2' => ['GeneNamesProjection'],
                            },
    },
    {
      -logic_name        => 'GeneNamesProjection',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::GeneNamesProjection',
      -analysis_capacity => 20,
      -parameters        => {
                              compara                => $self->o('compara_division'),
                              release                => $self->o('ensembl_release'),
                              output_dir             => $self->o('pipeline_dir'),
                              store_projections      => $self->o('store_projections'),
                              method_link_type       => $self->o('method_link_type'),
                              homology_types_allowed => $self->o('homology_types_allowed'),
                              is_tree_compliant      => $self->o('is_tree_compliant'),
                              percent_id_filter      => $self->o('percent_id_filter'),
                              percent_cov_filter     => $self->o('percent_cov_filter'),
                              gene_name_source       => $self->o('gene_name_source'),
                              project_xrefs          => $self->o('project_xrefs'),
                              project_trans_names    => $self->o('project_trans_names'),
                              white_list             => $self->o('white_list'),
                              gene_desc_rules        => $self->o('gene_desc_rules'),
                              gene_desc_rules_target => $self->o('gene_desc_rules_target'),
                            },
      -rc_name           => '2GB',
      -flow_into         => {
                              '1->A' => ['RunXrefCriticalDatacheck'],
                              'A->1' => ['RunXrefAdvisoryDatacheck']
                            }
    },
    {
      -logic_name        => 'SourceFactory_Descs',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::SourceFactory',
      -parameters        => {
                              config      => $self->o('gd_config'),
                              config_type => 'descs',
                            },
      -flow_into         => {
                              '4->A' => ['TargetFactory_Descs'],
                              'A->3' => ['SourceFactory_Descs'],
                            },
    },
    {
      -logic_name        => 'TargetFactory_Descs',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -analysis_capacity => 5,
      -rc_name           => 'default',
      -flow_into         => {
                              '2' => ['GeneDescProjection'],
                            },
    },
    {
      -logic_name        => 'GeneDescProjection',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::GeneDescProjection',
      -analysis_capacity => 20,
      -parameters        => {
                              compara                => $self->o('compara_division'),
                              release                => $self->o('ensembl_release'),
                              output_dir             => $self->o('pipeline_dir'),
                              store_projections      => $self->o('store_projections'),
                              method_link_type       => $self->o('method_link_type'),
                              homology_types_allowed => $self->o('homology_types_allowed'),
                              is_tree_compliant      => $self->o('is_tree_compliant'),
                              percent_id_filter      => $self->o('percent_id_filter'),
                              percent_cov_filter     => $self->o('percent_cov_filter'),
                              gene_name_source       => $self->o('gene_name_source'),
                              gene_desc_rules        => $self->o('gene_desc_rules'),
                              gene_desc_rules_target => $self->o('gene_desc_rules_target'),
                            },
      -rc_name           => '2GB',
      -flow_into         => {
                              '1->A' => ['RunXrefCriticalDatacheck'],
                              'A->1' => ['RunXrefAdvisoryDatacheck']
                            }
    },
    {
      -logic_name        => 'RunXrefCriticalDatacheck',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -batch_size        => 10,
      -parameters        => {
                              datacheck_names  => ['ForeignKeys'],
                              datacheck_groups => ['xref'],
                              datacheck_types  => ['critical'],
                              registry_file    => $self->o('registry'),
                              config_file      => $self->o('config_file'),
                              history_file     => $self->o('history_file'),
                              old_server_uri   => $self->o('old_server_uri'),
                              failures_fatal   => 1,
                            },
    },
    {
      -logic_name        => 'RunXrefAdvisoryDatacheck',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -max_retry_count   => 1,
      -batch_size        => 10,
      -analysis_capacity => 10,
      -parameters        => {
                              datacheck_groups => ['xref_name_projection'],
                              datacheck_types  => ['advisory'],
                              registry_file    => $self->o('registry'),
                              config_file      => $self->o('config_file'),
                              history_file     => $self->o('history_file'),
                              old_server_uri   => $self->o('old_server_uri'),
                              failures_fatal   => 0,
                            },
      -flow_into         => {
                              '4' => 'EmailReportXrefAdvisory'
                            },
    },
    {
      -logic_name        => 'EmailReportXrefAdvisory',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::EmailNotify',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              email         => $self->o('email'),
                              pipeline_name => $self->o('pipeline_name'),
                            },
    },
    {
      -logic_name      => 'EmailReport',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::EmailReport',
      -parameters      => {
                            email   => $self->o('email'),
                            subject => $self->o('pipeline_name').' has completed',
                            text    => 'Log files: '.$self->o('pipeline_dir'),
                          },
      -flow_into => ['species_update_factory'],
    },
    @{Bio::EnsEMBL::Compara::PipeConfig::Parts::UpdateMemberNamesDescriptions::pipeline_analyses_member_names_descriptions($self)},
  ];
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
        '1Gb_job'    => { 'LSF' => [' -q production -M 1000 '] },
    };
}
1;
