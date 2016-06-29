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

=head1 Author

Naveen Kumar

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

    species => [],
    antispecies => [],
    division => [],
    run_all => 0,
    meta_filters => {},
    
    # Analysis settings
    rfam_version      => '12.1',
    source_logic_name => 'cmscan_rfam_'.$self->o('rfam_version'),
    target_logic_name => 'rfam_'.$self->o('rfam_version').'_gene',
    analysis_module   => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::GeneFilter',
    
    # Remove existing genes; if => 0 then existing analyses
    # and their features will remain, with the logic_name suffixed by '_bkp'.
    delete_existing => 1,
    
    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,
    
    # Filter thresholds
    evalue_threshold => 1e-6,
    truncated        => 0,
    nonsignificant   => 0,
    bias_threshold   => 0.3,
    
    # Allow gene creation within a repeat feature
    within_repeat => 0,
    
    # Allow gene creation within an exon
    within_exon => 0,
    
    # Connection details for database that tracks IDs
    id_db_host   => 'mysql-eg-pan-prod.ebi.ac.uk',
    id_db_port   => 4276,
    id_db_user   => 'ensrw',
    id_db_dbname => 'ena_identifiers',
    id_db => {
      -driver => $self->o('hive_driver'),
      -host   => $self->o('id_db_host'),
      -port   => $self->o('id_db_port'),
      -user   => $self->o('id_db_user'),
      -pass   => $self->o('id_db_pass'),
      -dbname => $self->o('id_db_dbname'),
    },
    
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
   'delete_existing' => $self->o('delete_existing'),
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
                              '1' => WHEN('#delete_existing#' =>
                                      ['DeleteGenes'],
                                     ELSE
                                      ['AnalysisSetup']),
                            },
    },

    {
      -logic_name        => 'DeleteGenes',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::DeleteGenes',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              logic_name => $self->o('target_logic_name'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['AnalysisSetup'],

    },

    {
      -logic_name        => 'AnalysisSetup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count   => 0,
      -batch_size        => 10,
      -parameters        => {
                              db_backup_required => 1,
                              db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                              logic_name   	     => $self->o('target_logic_name'), 
                              module             => $self->o('analysis_module'), 
                              delete_existing    => $self->o('delete_existing'),
                              production_lookup  => $self->o('production_lookup'),
                              production_db      => $self->o('production_db'),
                            },
      -meadow_type       => 'LOCAL',
      -flow_into         => {
                              '1' => ['GeneFilter'],
                            },
    },

    {
      -logic_name        => 'GeneFilter',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::GeneFilter',
      -max_retry_count   => 1,
      -parameters        => {
                              source_logic_name => $self->o('source_logic_name'),
                              target_logic_name => $self->o('target_logic_name'),
                              evalue_threshold  => $self->o('evalue_threshold'),
                              truncated         => $self->o('truncated'),
                              nonsignificant    => $self->o('nonsignificant'),
                              bias_threshold    => $self->o('bias_threshold'),
                              within_repeat     => $self->o('within_repeat'),
                              within_exon       => $self->o('within_exon'),
                              id_db             => $self->o('id_db'),
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
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EmailReport',
      -max_retry_count   => 1,
      -parameters        => {
                              email   => $self->o('email'),
                              subject => 'RNA genes pipeline has completed',
                              text    => 'The RNA genes pipeline has completed.',
                            },
      -rc_name           => 'normal',
    },

  ];
}
1;
