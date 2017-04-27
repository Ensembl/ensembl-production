=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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
Bio::EnsEMBL::EGPipeline::PipeConfig::RNAGenes_conf

=head1 DESCRIPTION

Configuration for generating RNA genes from alignments of RNA covariance
models (probably from Rfam).

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::RNAGenes_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::default_options},
    
    pipeline_name => 'rna_genes_'.$self->o('ensembl_release'),

    species      => [],
    antispecies  => [],
    division     => [],
    run_all      => 0,
    meta_filters => {},
    
    use_cmscan   => 1,
    use_mirbase  => 1,
    use_trnascan => 1,
    
    run_context => 'eg',
    
    # Analysis settings
    rfam_version             => '12.2',
    cmscan_source_logic_name => 'cmscan_rfam_'.$self->o('rfam_version').'_lca',
    cmscan_target_logic_name => 'rfam_'.$self->o('rfam_version').'_gene',
    cmscan_analysis_module   => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::CreateCmscanGenes',

    mirbase_source_logic_name => 'mirbase',
    mirbase_target_logic_name => 'mirbase_gene',
    mirbase_analysis_module   => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::CreateMirbaseGenes',

    trnascan_source_logic_name => 'trnascan_align',
    trnascan_target_logic_name => 'trnascan_gene',
    trnascan_analysis_module   => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::CreateTrnascanGenes',

    # Config for genes
    gene_source => undef,
    
    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,
    
    # tRNAscan-specific thresholds (note that we could provide the option
    # to allow overlap with repeat features or coding exons; but tRNA genes
    # are almost always overpredicted, so we don't bother adding the extra
    # complexity)
    score_threshold => 40,
    
    # CMScan-specific thresholds
    evalue_threshold     => 1e-6,
    truncated            => 0,
    nonsignificant       => 0,
    bias_threshold       => 0.3,
    allow_repeat_overlap => 1,
    allow_coding_overlap => 0,
    
    # Connection details for database that tracks IDs
    id_db_host   => 'mysql-eg-pan-prod.ebi.ac.uk',
    id_db_port   => 4276,
    id_db_user   => 'ensrw',
    id_db_pass   => undef,
    id_db_dbname => 'ena_identifiers',
    id_db => {
      -driver => $self->o('hive_driver'),
      -host   => $self->o('id_db_host'),
      -port   => $self->o('id_db_port'),
      -user   => $self->o('id_db_user'),
      -pass   => $self->o('id_db_pass'),
      -dbname => $self->o('id_db_dbname'),
    },
    
    # Registry for core dbs from previous release, for stable ID mapping
    old_registry => undef,
    
    # We always want to do stable ID mapping, the only reason not to is
    # if all the species are asserted to be new.
    all_new_species => 0,
  };
}

sub beekeeper_extra_cmdline_options {
  my ($self) = @_;

  my $options = join(' ',
    $self->SUPER::beekeeper_extra_cmdline_options,
    "-reg_conf ".$self->o('registry')
  );

  return $options;
}

sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack'  => 1,
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
   'use_cmscan'      => $self->o('use_cmscan'),
   'use_mirbase'     => $self->o('use_mirbase'),
   'use_trnascan'    => $self->o('use_trnascan'),
 };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              species         => $self->o('species'),
                              antispecies     => $self->o('antispecies'),
                              division        => $self->o('division'),
                              run_all         => $self->o('run_all'),
                              meta_filters    => $self->o('meta_filters'),
                              chromosome_flow => 0,
                              regulation_flow => 0,
                              variation_flow  => 0,
                            },
      -input_ids         => [ {} ],
      -flow_into         => {
                              '2->A' => ['BackupDatabase'],
                              'A->2' => ['MetaCoords'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'BackupDatabase',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              output_file => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '1->A' => WHEN(
                                '#use_cmscan#'   => ['DeleteCmscanGenes'],
                                '#use_mirbase#'  => ['DeleteMirbaseGenes'],
                                '#use_trnascan#' => ['DeleteTrnascanGenes'],
                              ),
                              'A->1' => ['ConfigureStableIDMapping'],
                            },
    },

    {
      -logic_name        => 'DeleteCmscanGenes',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::DeleteGenes',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              logic_name => $self->o('cmscan_target_logic_name'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['AnalysisSetupCmscan'],

    },

    {
      -logic_name        => 'DeleteMirbaseGenes',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::DeleteGenes',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              logic_name => $self->o('mirbase_target_logic_name'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['AnalysisSetupMirbase'],

    },

    {
      -logic_name        => 'DeleteTrnascanGenes',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::DeleteGenes',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              logic_name => $self->o('trnascan_target_logic_name'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['AnalysisSetupTrnascan'],

    },

    {
      -logic_name        => 'AnalysisSetupCmscan',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count   => 0,
      -batch_size        => 10,
      -parameters        => {
                              db_backup_required => 1,
                              db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                              logic_name         => $self->o('cmscan_target_logic_name'), 
                              module             => $self->o('cmscan_analysis_module'), 
                              delete_existing    => 1,
                              production_lookup  => $self->o('production_lookup'),
                              production_db      => $self->o('production_db'),
                            },
      -meadow_type       => 'LOCAL',
      -flow_into         => ['CreateCmscanGenes'],
    },

    {
      -logic_name        => 'AnalysisSetupMirbase',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count   => 0,
      -batch_size        => 10,
      -parameters        => {
                              db_backup_required => 1,
                              db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                              logic_name         => $self->o('mirbase_target_logic_name'), 
                              module             => $self->o('mirbase_analysis_module'), 
                              delete_existing    => 1,
                              production_lookup  => $self->o('production_lookup'),
                              production_db      => $self->o('production_db'),
                            },
      -meadow_type       => 'LOCAL',
      -flow_into         => ['CreateMirbaseGenes'],
    },

    {
      -logic_name        => 'AnalysisSetupTrnascan',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count   => 0,
      -batch_size        => 10,
      -parameters        => {
                              db_backup_required => 1,
                              db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                              logic_name         => $self->o('trnascan_target_logic_name'), 
                              module             => $self->o('trnascan_analysis_module'), 
                              delete_existing    => 1,
                              production_lookup  => $self->o('production_lookup'),
                              production_db      => $self->o('production_db'),
                            },
      -meadow_type       => 'LOCAL',
      -flow_into         => ['CreateTrnascanGenes'],
    },

    {
      -logic_name        => 'CreateCmscanGenes',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::CreateCmscanGenes',
      -max_retry_count   => 1,
      -parameters        => {
                              source_logic_name    => $self->o('cmscan_source_logic_name'),
                              target_logic_name    => $self->o('cmscan_target_logic_name'),
                              gene_source          => $self->o('gene_source'),
                              stable_id_type       => $self->o('run_context'),
                              id_db                => $self->o('id_db'),
                              evalue_threshold     => $self->o('evalue_threshold'),
                              truncated            => $self->o('truncated'),
                              nonsignificant       => $self->o('nonsignificant'),
                              bias_threshold       => $self->o('bias_threshold'),
                              allow_repeat_overlap => $self->o('allow_repeat_overlap'),
                              allow_coding_overlap => $self->o('allow_coding_overlap'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'CreateMirbaseGenes',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::CreateMirbaseGenes',
      -max_retry_count   => 1,
      -parameters        => {
                              source_logic_name => $self->o('mirbase_source_logic_name'),
                              target_logic_name => $self->o('mirbase_target_logic_name'),
                              gene_source       => $self->o('gene_source'),
                              stable_id_type    => $self->o('run_context'),
                              id_db             => $self->o('id_db'),
                            },
      -rc_name           => 'normal',

    },

    {
      -logic_name        => 'CreateTrnascanGenes',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::CreateTrnascanGenes',
      -max_retry_count   => 1,
      -parameters        => {
                              source_logic_name    => $self->o('trnascan_source_logic_name'),
                              target_logic_name    => $self->o('trnascan_target_logic_name'),
                              gene_source          => $self->o('gene_source'),
                              stable_id_type       => $self->o('run_context'),
                              id_db                => $self->o('id_db'),
                              score_threshold      => $self->o('score_threshold'),
                              allow_repeat_overlap => 0,
                              allow_coding_overlap => 0,
                            },
      -rc_name           => 'normal',

    },

    {
      -logic_name        => 'ConfigureStableIDMapping',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::ConfigureStableIDMapping',
      -max_retry_count   => 1,
      -parameters        => {
                              all_new_species => $self->o('all_new_species'),
                              old_reg_conf    => $self->o('old_registry'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['StableIDMapping'],

    },

    {
      -logic_name        => 'StableIDMapping',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::StableIDMapping',
      -max_retry_count   => 1,
      -parameters        => {
                              report_style => $self->o('run_context'),
                              report_dir   => $self->o('pipeline_dir'),
                            },
      -rc_name           => 'normal',

    },

    {
      -logic_name        => 'MetaCoords',
      -module            => 'Bio::EnsEMBL::EGPipeline::CoreStatistics::MetaCoords',
      -max_retry_count   => 1,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => ['EmailRNAGenesReport'],
    },

    {
      -logic_name        => 'EmailRNAGenesReport',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::EmailRNAGenesReport',
      -max_retry_count   => 1,
      -parameters        => {
                              email               => $self->o('email'),
                              subject             => 'RNA genes pipeline has completed for #species#',
                              mirbase_logic_name  => $self->o('mirbase_target_logic_name'),
                              trnascan_logic_name => $self->o('trnascan_target_logic_name'),
                              cmscan_logic_name   => $self->o('cmscan_target_logic_name'),
                            },
      -rc_name           => 'normal',
    },

  ];
}
1;
