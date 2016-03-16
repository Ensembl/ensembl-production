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
Bio::EnsEMBL::EGPipeline::PipeConfig::RNAFeatures_conf

=head1 DESCRIPTION

Configuration for running the RNA Features pipeline, which
aligns RNA features against a genome and adds them to a core database.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::RNAFeatures_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'rna_features_'.$self->o('ensembl_release'),

    species => [],
    antispecies => [],
    division => [],
    run_all => 0,
    meta_filters => {},

    # Parameters for dumping and splitting Fasta DNA files...
    max_seq_length          => 10000000,
    max_seq_length_per_file => $self->o('max_seq_length'),
    max_seqs_per_file       => 1000,
    max_files_per_directory => 50,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),

    max_hive_capacity => 100,

    run_cmscan   => 1,
    run_trnascan => 1,

    program_dir => '/nfs/panda/ensemblgenomes/external',
    cmscan_exe  => catdir($self->o('program_dir'), 'bin', 'cmscan'),

    cmscan_cm_file    => {},
    cmscan_logic_name => {},
    cmscan_db_name    => {},
    cmscan_cpu        => 3,
    cmscan_heuristics => 'default',
    cmscan_threshold  => 0.001,
    cmscan_param_hash =>
    {
      cpu            => $self->o('cmscan_cpu'),
      heuristics     => $self->o('cmscan_heuristics'),
      threshold      => $self->o('cmscan_threshold'),
    },
    cmscan_parameters => '',

    # The blacklist is a foolproof method of excluding Rfam models that
    # you do not want to annotate, perhaps because they generate an excess of
    # alignments. The taxonomic filtering tries to address this, but there may
    # be a small number of models that slip past that filter, but which are
    # nonetheless inappropriate. (An alternative is to ratchet up the strictness
    # of the taxonomic filter, but you may then start excluding appropriate
    # models...)
    # In addition, some rRNA models are clade-specific, but have nonetheless
    # been aligned across the entire tree of life; so those are in the
    # blacklist by default. Ditto the U3 and SRP clans.
    rfam_version        => 12,
    rfam_dir            => catdir($self->o('program_dir'), 'Rfam', $self->o('rfam_version')),
    rfam_cm_file        => catdir($self->o('rfam_dir'), 'Rfam.cm'),
    rfam_logic_name     => 'cmscan_rfam_'.$self->o('rfam_version'),
    rfam_db_name        => 'RFAM',
    rfam_rrna           => 1,
    rfam_trna           => 0,
    rfam_blacklist      => {
                            'Archaea' =>
                              ['RF00002', 'RF00169', 'RF00177', 'RF01854', 'RF01960', 'RF02541', 'RF02542', 'RF02543', ],
                            'Bacteria' =>
                              ['RF00002', 'RF00882', 'RF01857', 'RF01959', 'RF01960', 'RF02540', 'RF02542', 'RF02543', ],
                            'Eukaryota' =>
                              ['RF00177', 'RF01118', 'RF00169', 'RF01854', 'RF01857', 'RF01959', 'RF02540', 'RF02541', 'RF02542', ],
                            'Fungi' =>
                              ['RF00012', 'RF00017', 'RF00059', 'RF01847', 'RF01848', 'RF01855', 'RF01856', 'RF02514', ],
                            'Metazoa' =>
                              ['RF00882', 'RF00906', 'RF01502', 'RF01675', 'RF01846', 'RF01847', 'RF01848', 'RF01849', 'RF01855', 'RF01856', 'RF02032', ],
                            'Viridiplantae' =>
                              ['RF00012', 'RF00017', 'RF01118', 'RF01502', 'RF01846', 'RF01848', 'RF01856', ],
                            'EnsemblProtists' =>
                              ['RF00012', 'RF00017', 'RF01118', 'RF01502', 'RF01846', 'RF01847', 'RF01855', ],
                            'Ensembl' =>
                              ['RF01358', 'RF01376', ],
                            },
    rfam_whitelist      => {
                            'EnsemblProtists' =>
                              ['RF00029', ],
                            },
    rfam_taxonomy_file  => catdir($self->o('rfam_dir'), 'taxonomic_levels.txt'),
    taxonomic_filtering => 1,
    taxonomic_lca       => 0,
    taxonomic_levels    => [],
    taxonomic_threshold => 0.02,
    taxonomic_minimum   => 50,

    # There's not much to choose between cmscan and tRNASCAN-SE in terms of
    # annotating tRNA genes, (for some species both produce lots of false
    # positives). If you use tRNASCAN-SE, however, you do have the option of
    # including pseudogenes, and you get info about the anticodon in the
    # gene description.
    trnascan_dir        => catdir($self->o('program_dir'), 'tRNAscan-SE-1.3.1', 'bin'),
    trnascan_exe        => catdir($self->o('program_dir'), 'bin', 'tRNAscan-SE'),
    trnascan_logic_name => 'trnascan',
    trnascan_param_hash =>
    {
      db_name => 'TRNASCAN_SE',
      pseudo  => 0,
    },
    trnascan_parameters => '',

    analyses =>
    [
      {
        'logic_name'      => $self->o('rfam_logic_name'),
        'db'              => 'Rfam',
        'db_version'      => $self->o('rfam_version'),
        'db_file'         => $self->o('rfam_cm_file'),
        'program'         => 'Infernal',
        'program_version' => '1.1',
        'program_file'    => $self->o('cmscan_exe'),
        'parameters'      => $self->o('cmscan_parameters'),
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::CMScan',
        'linked_tables'   => ['dna_align_feature'],
      },
      {
        'logic_name'      => $self->o('rfam_logic_name').'_lca',
        'db'              => 'Rfam',
        'db_version'      => $self->o('rfam_version'),
        'db_file'         => $self->o('rfam_cm_file'),
        'program'         => 'Infernal',
        'program_version' => '1.1',
        'program_file'    => $self->o('cmscan_exe'),
        'parameters'      => $self->o('cmscan_parameters'),
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::CMScan',
        'linked_tables'   => ['dna_align_feature'],
      },
      {
        'logic_name'      => 'cmscan_custom',
        'program'         => 'Infernal',
        'program_version' => '1.1',
        'program_file'    => $self->o('cmscan_exe'),
        'parameters'      => $self->o('cmscan_parameters'),
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::CMScan',
        'linked_tables'   => ['dna_align_feature'],
      },
      {
        'logic_name'      => $self->o('trnascan_logic_name'),
        'program'         => 'tRNAscan-SE',
        'program_version' => '1.3.1',
        'program_file'    => $self->o('trnascan_exe'),
        'parameters'      => $self->o('trnascan_parameters'),
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::tRNAscan',
        'linked_tables'   => ['dna_align_feature'],
      },
    ],

    # Remove existing DNA features; if => 0 then existing analyses
    # and their features will remain, with the logic_name suffixed by '_bkp'.
    delete_existing => 1,

    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,

    # An email is sent summarising the alignments for all species,
    # and plots are produced with evalue cut-offs, each with a different colour. 
    evalue_levels =>  {
                        '1e-3' => 'forestgreen',
                        '1e-6' => 'darkorange',
                        '1e-9' => 'firebrick',
                      },
  };
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
  my ($self) = @_;

  my $options = join(' ',
    $self->SUPER::beekeeper_extra_cmdline_options,
    "-reg_conf ".$self->o('registry')
  );
  
  return $options;
}

# Ensures that species output parameter gets propagated implicitly.
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

sub pipeline_analyses {
  my ($self) = @_;
  
  my $rfam_logic_name = $self->o('rfam_logic_name');
  if ($self->o('taxonomic_filtering') && $self->o('taxonomic_lca')) {
    $rfam_logic_name .= '_lca';
  }

  return [
    {
      -logic_name        => 'RNAFeatures',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 1,
      -parameters        => {
                            },
      -input_ids         => [ {} ],
      -flow_into         => {
                              '1->A' => ['SpeciesFactory_Features'],
                              'A->1' => ['SpeciesFactory_Report'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'SpeciesFactory_Features',
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
      -flow_into         => {
                              '2->A' => ['BackupDatabase'],
                              'A->2' => ['MetaCoords'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'BackupDatabase',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -analysis_capacity => 5,
      -max_retry_count   => 1,
      -parameters        => {
                              output_file => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '1->A' => ['RNAAnalysisFactory'],
                              'A->1' => ['DumpGenome'],
                            },
    },

    {
      -logic_name        => 'RNAAnalysisFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::RNAAnalysisFactory',
      -max_retry_count   => 0,
      -batch_size        => 10,
      -parameters        => {
                              analyses            => $self->o('analyses'),
                              run_cmscan          => $self->o('run_cmscan'),
                              run_trnascan        => $self->o('run_trnascan'),
                              rfam_logic_name     => $rfam_logic_name,
                              trnascan_logic_name => $self->o('trnascan_logic_name'),
                              cmscan_cm_file      => $self->o('cmscan_cm_file'),
                              cmscan_logic_name   => $self->o('cmscan_logic_name'),
                              pipeline_dir        => $self->o('pipeline_dir'),
                              db_backup_file      => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['AnalysisSetup'],
                            },
    },

    {
      -logic_name        => 'AnalysisSetup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count   => 0,
      -batch_size        => 10,
      -parameters        => {
                              db_backup_required => 1,
                              delete_existing    => $self->o('delete_existing'),
                              production_lookup  => $self->o('production_lookup'),
                              production_db      => $self->o('production_db'),
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'DumpGenome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DumpGenome',
      -analysis_capacity => 5,
      -parameters        => {
                              genome_dir => catdir($self->o('pipeline_dir'), '#species#'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['TaxonomicFilter'],
    },

    {
      -logic_name        => 'TaxonomicFilter',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::TaxonomicFilter',
      -batch_size        => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              rfam_cm_file        => $self->o('rfam_cm_file'),
                              filtered_cm_file    => catdir($self->o('pipeline_dir'), '#species#', 'Rfam.filtered.cm'),
                              rfam_logic_name     => $rfam_logic_name,
                              rfam_rrna           => $self->o('rfam_rrna'),
                              rfam_trna           => $self->o('rfam_trna'),
                              rfam_blacklist      => $self->o('rfam_blacklist'),
                              rfam_whitelist      => $self->o('rfam_whitelist'),
                              rfam_taxonomy_file  => $self->o('rfam_taxonomy_file'),
                              taxonomic_filtering => $self->o('taxonomic_filtering'),
                              taxonomic_lca       => $self->o('taxonomic_lca'),
                              taxonomic_levels    => $self->o('taxonomic_levels'),
                              taxonomic_threshold => $self->o('taxonomic_threshold'),
                              taxonomic_minimum   => $self->o('taxonomic_minimum'),
                            },
      -rc_name           => '4Gb_mem',
      -flow_into         => ['SplitDumpFile'],
    },

    {
      -logic_name        => 'SplitDumpFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::SplitDumpFile',
      -parameters        => {
                              fasta_file              => '#genome_file#',
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                              run_cmscan              => $self->o('run_cmscan'),
                              run_trnascan            => $self->o('run_trnascan'),
                            },
      -rc_name           => '8Gb_mem',
      -flow_into         => {
                              '3' => ['CMScanFactory'],
                              '4' => ['tRNAscan'],
                            },
    },

    {
      -logic_name        => 'CMScanFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::CMScanFactory',
      -batch_size        => 100,
      -max_retry_count   => 1,
      -parameters        => {
                              rfam_cm_file      => catdir($self->o('pipeline_dir'), '#species#', 'Rfam.filtered.cm'),
                              rfam_logic_name   => $rfam_logic_name,
                              cmscan_cm_file    => $self->o('cmscan_cm_file'),
                              cmscan_logic_name => $self->o('cmscan_logic_name'),
                              cmscan_db_name    => $self->o('cmscan_db_name'),
                              parameters_hash   => $self->o('cmscan_param_hash'),
                              max_seq_length    => $self->o('max_seq_length'),
                            },
      -rc_name           => '8Gb_mem',
      -flow_into         => {
                              '2' => ['CMScan'],
                            },
    },

    {
      -logic_name        => 'CMScan',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::CMScan',
      -hive_capacity     => $self->o('max_hive_capacity'),
      -max_retry_count   => 1,
      -parameters        => {
                              escape_branch => -1,
                            },
      -rc_name           => 'cmscan_4Gb_mem',
      -flow_into         => {
                              '-1' => ['CMScan_HighMem'],
                            },
    },

    {
      -logic_name        => 'CMScan_HighMem',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::CMScan',
      -can_be_empty      => 1,
      -hive_capacity     => $self->o('max_hive_capacity'),
      -max_retry_count   => 0,
      -parameters        => {},
      -rc_name           => 'cmscan_8Gb_mem',
    },

    {
      -logic_name        => 'tRNAscan',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::tRNAscan',
      -hive_capacity     => $self->o('max_hive_capacity'),
      -max_retry_count   => 1,
      -parameters        => {
                              trnascan_dir    => $self->o('trnascan_dir'),
                              logic_name      => $self->o('trnascan_logic_name'),
                              parameters_hash => $self->o('trnascan_param_hash'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'MetaCoords',
      -module            => 'Bio::EnsEMBL::EGPipeline::CoreStatistics::MetaCoords',
      -max_retry_count   => 1,
      -parameters        => {},
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'SpeciesFactory_Report',
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
      -flow_into         => {
                              '2->A' => ['FetchAlignments'],
                              'A->1' => ['SummariseAlignments'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'FetchAlignments',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::FetchAlignments',
      -batch_size        => 100,
      -max_retry_count   => 1,
      -parameters        => {
                              run_cmscan          => $self->o('run_cmscan'),
                              run_trnascan        => $self->o('run_trnascan'),
                              rfam_logic_name     => $rfam_logic_name,
                              trnascan_logic_name => $self->o('trnascan_logic_name'),
                              cmscan_cm_file      => $self->o('cmscan_cm_file'),
                              cmscan_logic_name   => $self->o('cmscan_logic_name'),
                              alignment_dir       => catdir($self->o('pipeline_dir'), '#species#'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'SummariseAlignments',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::SummariseAlignments',
      -max_retry_count   => 1,
      -parameters        => {
                              run_cmscan     => $self->o('run_cmscan'),
                              run_trnascan   => $self->o('run_trnascan'),
                              pipeline_dir   => $self->o('pipeline_dir'),
                              evalue_levels  => $self->o('evalue_levels'),
                            },
      -flow_into         => {
                              '2->A' => ['SummaryPlots'],
                              'A->1' => ['EmailRNAReport'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'SummaryPlots',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              scripts_dir => catdir($self->o('eg_pipelines_dir'), 'scripts', 'rna_features'),
                              cmd => 'Rscript #scripts_dir#/summary_plots.r -l #scripts_dir#/R_lib -i #cmscanfile# -e #evalue# -b #biotypesfile# -d #distinctfile# -c #plotcolour#',
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'EmailRNAReport',
      -module            => 'Bio::EnsEMBL::EGPipeline::RNAFeatures::EmailRNAReport',
      -max_retry_count   => 1,
      -parameters        => {
                              email         => $self->o('email'),
                              subject       => 'RNA features pipeline report',
                              run_cmscan    => $self->o('run_cmscan'),
                              run_trnascan  => $self->o('run_trnascan'),
                              pipeline_dir  => $self->o('pipeline_dir'),
                              evalue_levels => $self->o('evalue_levels'),
                            },
      -rc_name           => 'normal',
    },

  ];
}

sub resource_classes {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::resource_classes},
    'cmscan_4Gb_mem' => {'LSF' => '-q production-rh6 -n '.$self->o('cmscan_cpu').' -M 4000 -R "rusage[mem=4000]" -R "span[hosts=1]"'},
    'cmscan_8Gb_mem' => {'LSF' => '-q production-rh6 -n '.$self->o('cmscan_cpu').' -M 8000 -R "rusage[mem=8000]" -R "span[hosts=1]"'},
  }
}

1;
