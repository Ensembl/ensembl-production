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

Bio::EnsEMBL::EGPipeline::PipeConfig::BlastMergeVB_conf

=head1 DESCRIPTION

Merge alignments tracks into taxonomically sensible groups.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::BlastMergeVB_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');

use Bio::EnsEMBL::Hive::Version 2.4;

use File::Spec::Functions qw(catdir);

sub default_options {
  my $self = shift @_;
  return {
    %{$self->SUPER::default_options},
    
    pipeline_name => 'blast_merge_vb_'.$self->o('ensembl_release'),
    backup_dir    => catdir($self->o('pipeline_dir'), 'premerge'),
    
    species      => [],
    antispecies  => [],
    division     => [],
    run_all      => 0,
    meta_filters => {},
    
    program          => 'blastx',
    linked_tables    => ['protein_align_feature'],
    db_type          => 'otherfeatures',
    gff_source       => 'VectorBase',
    external_db_name => 'VectorBase_Proteome',
    
    # Use the following settings for blastp analyses instead of those above.
    # program          => 'blastp',
    # linked_tables    => ['protein_feature'],
    # db_type          => 'core',
    
    analysis_groups =>
    {
      anophelinae => [
        'aalbimanus',
        'aarabiensis',
        'aatroparvus',
        'achristyi',
        'acoluzzii',
        'aculicifacies',
        'adarlingi',
        'adirus',
        'aepiroticus',
        'afarauti',
        'afunestus',
        'agambiae',
        'amaculatus',
        'amelas',
        'amerus',
        'aminimus',
        'aquadriannulatus',
        'asinensisc',
        'asinensis',
        'astephensii',
        'astephensi',
        ],
      brachycera => [
        'dmelanogaster',
        'gausteni',
        'gbrevipalpis',
        'gfuscipes',
        'gmorsitans',
        'gpallidipes',
        'gpalpalis',
        'mdomestica',
        'scalcitrans',
        ],
      chelicerata => [
        'iscapularis',
        'sscabiei',
        ],
      culicinae => [
        'aaegypti',
        'aalbopictus',
        'cquinquefasciatus',
        ],
      gastropoda => [
        'bglabrata',
        ],
      hemiptera => [
        'clectularius',
        'rprolixus',
        ],
      phlebotominae => [
        'llongipalpis',
        'ppapatasi',
        ],
      phthiraptera => [
        'phumanus',
        ],
    },
    
    id_prefixes =>
    {
      'aalbimanus'        => 'AALB',
      'aarabiensis'       => 'AARA',
      'aatroparvus'       => 'AATE',
      'achristyi'         => 'ACHR',
      'acoluzzii'         => 'ACOM',
      'aculicifacies'     => 'ACUA',
      'adarlingi'         => 'ADAC',
      'adirus'            => 'ADIR',
      'aepiroticus'       => 'AEPI',
      'afarauti'          => 'AFAF',
      'afunestus'         => 'AFUN',
      'agambiae'          => 'AGAP',
      'amaculatus'        => 'AMAM',
      'amelas'            => 'AMEC',
      'amerus'            => 'AMEM',
      'aminimus'          => 'AMIN',
      'aquadriannulatus'  => 'AQUA',
      'asinensisc'        => 'ASIC',
      'asinensis'         => 'ASIS',
      'astephensii'       => 'ASTEI',
      'astephensi'        => 'ASTE',
      'dmelanogaster'     => 'FB',
      'gausteni'          => 'GAUT',
      'gbrevipalpis'      => 'GBRI',
      'gfuscipes'         => 'GFUI',
      'gmorsitans'        => 'GMOY',
      'gpallidipes'       => 'GPAI',
      'gpalpalis'         => 'GPPI',
      'mdomestica'        => 'MDOA',
      'scalcitrans'       => 'SCAU',
      'iscapularis'       => 'ISCW',
      'sscabiei'          => 'SSCA',
      'aaegypti'          => 'AAEL',
      'aalbopictus'       => 'AALF',
      'cquinquefasciatus' => 'CPIJ',
      'bglabrata'         => 'BGLB',
      'clectularius'      => 'CLEC',
      'rprolixus'         => 'RPRC',
      'llongipalpis'      => 'LLOJ',
      'ppapatasi'         => 'PPAI',
      'phumanus'          => 'PHUM',
    },
    
    analyses =>
    [
      {
        'program'       => $self->o('program'),
        'gff_source'    => $self->o('gff_source'),
        'linked_tables' => $self->o('linked_tables'),
        'db_type'       => $self->o('db_type'),
      },
    ],
    
    # Remove existing *_align_features; if => 0 then existing analyses
    # and their features will remain, with the logic_name suffixed by '_bkp'.
    delete_existing => 1,

    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,

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
    'mkdir -p '.$self->o('backup_dir'),
  ];
}

sub pipeline_analyses {
  my $self = shift @_;
  
  return [
    {
      -logic_name      => 'SpeciesFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -max_retry_count => 1,
      -input_ids       => [{}],
      -parameters      => {
                            species         => $self->o('species'),
                            antispecies     => $self->o('antispecies'),
                            division        => $self->o('division'),
                            run_all         => $self->o('run_all'),
                            meta_filters    => $self->o('meta_filters'),
                            chromosome_flow => 0,
                            regulation_flow => 0,
                            variation_flow  => 0,
                          },
      -flow_into       => {
                            '2->A' => ['BackupOFDatabase'],
                            'A->2' => ['AnalyzeTables'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'BackupOFDatabase',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -max_retry_count => 1,
      -parameters      => {
                            db_type     => $self->o('db_type'),
                            output_file => catdir($self->o('backup_dir'), '#species#', 'of_bkp.sql.gz'),
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '1->A' => ['AnalysisUnmergeFactory'],
                            'A->1' => ['AnalysisSetupFactory'],
                          },
    },

    {
      -logic_name      => 'AnalysisUnmergeFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::AnalysisUnmergeFactory',
      -max_retry_count => 0,
      -batch_size      => 10,
      -parameters      => {
                            program          => $self->o('program'),
                            external_db_name => $self->o('external_db_name'),
                            analysis_groups  => $self->o('analysis_groups'),
                            id_prefixes      => $self->o('id_prefixes'),
                            linked_tables    => $self->o('linked_tables'),
                            db_type          => $self->o('db_type'),
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2' => ['AnalysisUnmerge'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name        => 'AnalysisUnmerge',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::SqlCmd',
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -batch_size        => 10,
      -parameters        => {
                              db_type => $self->o('db_type'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name      => 'AnalysisSetupFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::AnalysisSetupFactory',
      -max_retry_count => 0,
      -batch_size      => 10,
      -parameters      => {
                            program         => $self->o('program'),
                            analysis_groups => $self->o('analysis_groups'),
                            analyses        => $self->o('analyses'),
                          },
      -flow_into       => {
                            '2' => ['AnalysisSetup'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'AnalysisSetup',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count => 0,
      -batch_size      => 10,
      -parameters      => {
                            db_type            => $self->o('db_type'),
                            db_backup_required => 1,
                            db_backup_file     => catdir($self->o('backup_dir'), '#species#', 'of_bkp.sql.gz'),
                            delete_existing    => $self->o('delete_existing'),
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                          },
      -flow_into       => {
                            '1' => ['AnalysisMergeFactory'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'AnalysisMergeFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::AnalysisMergeFactory',
      -max_retry_count => 0,
      -batch_size      => 10,
      -parameters      => {
                            program           => $self->o('program'),
                            external_db_name  => $self->o('external_db_name'),
                            analysis_groups   => $self->o('analysis_groups'),
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2' => ['AnalysisMerge'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name        => 'AnalysisMerge',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::SqlCmd',
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -batch_size        => 10,
      -parameters        => {
                              db_type => $self->o('db_type'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'AnalyzeTables',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalyzeTables',
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -parameters        => {
                              optimize_tables => 1,
                            },
      -rc_name           => 'normal',
    },
    
  ];
}

1;
