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
Bio::EnsEMBL::EGPipeline::PipeConfig::DNAFeatures_conf

=head1 DESCRIPTION

Configuration for running the DNA Features pipeline, which
primarily adds repeat features to a core database.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::DNAFeatures_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'dna_features_'.$self->o('ensembl_release'),

    species => [],
    antispecies => [],
    division => [],
    run_all => 0,
    meta_filters => {},

    # Parameters for dumping and splitting Fasta DNA files.
    max_seq_length          => 1000000,
    max_seq_length_per_file => $self->o('max_seq_length'),
    max_seqs_per_file       => undef,
    max_files_per_directory => 50,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),
    
    # Dust and TRF can handle large files; this size should mean
    # that jobs take a few minutes.
    dust_trf_max_seq_length    => 100000000,
    dust_trf_max_seqs_per_file => 10000,
    
    # Values >100 are not recommended, because you tend to overload
    # the mysql server with connections.
    max_hive_capacity => 100,

    program_dir      => '/nfs/software/ensembl/RHEL7/linuxbrew/bin',
    dust_exe         => catdir($self->o('program_dir'), 'dustmasker'),
    trf_exe          => catdir($self->o('program_dir'), 'trf'),
    repeatmasker_exe => catdir($self->o('program_dir'), 'RepeatMasker'),

    dust         => 1,
    trf          => 1,
    repeatmasker => 1,

    # By default, run RepeatMasker with repbase library and exclude
    # low-complexity annotations. By explicitly turning on the GC calculations,
    # the results are made consistent regardless of the number of sequences in 
    # the input file. For repbase a species parameter is added when the program 
    # is called within the pipeline. The sensitivity of the search, including
    # which engine is used, is also added within the pipeline.
    always_use_repbase       => 0,
    repeatmasker_library     => {},
    repeatmasker_sensitivity => {},
    repeatmasker_logic_name  => {},
    repeatmasker_parameters  => ' -nolow -gccalc ',
    repeatmasker_cache       => catdir($self->o('pipeline_dir'), 'cache'),

    # The ensembl-analysis Dust and TRF modules take a parameters hash which
    # is parsed, rather than requiring explicit command line options.
    # It's generally not necessary to override default values, but below are
    # examples of the syntax for dust and trf, showing the current defaults.
    # (See the help for those programs for parameter descriptions.)
    # dust_parameters_hash => {
    #   'MASKING_THRESHOLD' => 20,
    #   'WORD_SIZE'         => 3,
    #   'WINDOW_SIZE'       => 64,
    #   'SPLIT_LENGTH'      => 50000,
    # },
    # trf_parameters_hash => {
    #   'MATCH'      => 2,
    #   'MISMATCH'   => 5,
    #   'DELTA'      => 7,
    #   'PM'         => 80,
    #   'PI'         => 10,
    #   'MINSCORE'   => 40,
    #   'MAX_PERIOD' => 500,
    # },
    dust_parameters_hash => {},
    trf_parameters_hash  => {},

    dna_analyses =>
    [
      {
        'logic_name'      => 'dust',
        'program'         => 'dustmasker',
        'program_file'    => $self->o('dust_exe'),
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::DustMasker',
        'gff_source'      => 'dust',
        'gff_feature'     => 'low_complexity_region',
        'linked_tables'   => ['repeat_feature'],
      },
      {
        'logic_name'      => 'trf',
        'program'         => 'trf',
        'program_version' => '4.0',
        'program_file'    => $self->o('trf_exe'),
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::TRF',
        'gff_source'      => 'trf',
        'gff_feature'     => 'tandem_repeat',
        'linked_tables'   => ['repeat_feature'],
      },
      {
        'logic_name'      => 'repeatmask_repbase',
        'db'              => 'repbase',
        'program'         => 'RepeatMasker',
        'program_version' => '4.0.5',
        'program_file'    => $self->o('repeatmasker_exe'),
        'parameters'      => $self->o('repeatmasker_parameters'),
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::RepeatMasker',
        'gff_source'      => 'repeatmasker',
        'gff_feature'     => 'repeat_region',
        'linked_tables'   => ['repeat_feature'],
      },
      {
        'logic_name'      => 'repeatmask_customlib',
        'db'              => 'custom',
        'program'         => 'RepeatMasker',
        'program_version' => '4.0.5',
        'program_file'    => $self->o('repeatmasker_exe'),
        'parameters'      => $self->o('repeatmasker_parameters'),
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::RepeatMasker',
        'gff_source'      => 'repeatmasker',
        'gff_feature'     => 'repeat_region',
        'linked_tables'   => ['repeat_feature'],
      },
    ],

    # Remove existing DNA features; if => 0 then existing analyses
    # and their features will remain, with the logic_name suffixed by '_bkp'.
    delete_existing => 1,

    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,

    # By default, an email is sent for each species when the pipeline
    # is complete, showing the breakdown of repeat coverage.
    email_report => 1,
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
    'mkdir -p '.$self->o('repeatmasker_cache'),
  ];
}

sub pipeline_wide_parameters {
 my ($self) = @_;
 
 return {
   %{$self->SUPER::pipeline_wide_parameters},
   'dust'         => $self->o('dust'),
   'trf'          => $self->o('trf'),
   'repeatmasker' => $self->o('repeatmasker'),
   'email_report' => $self->o('email_report'),
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
                              'A->2' => ['UpdateMetadata'],
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
                              '1->A' => ['DNAAnalysisFactory'],
                              'A->1' => ['DumpGenome'],
                            },
    },

    {
      -logic_name        => 'DNAAnalysisFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNAFeatures::DNAAnalysisFactory',
      -max_retry_count   => 0,
      -batch_size        => 10,
      -parameters        => {
                              dust               => $self->o('dust'),
                              trf                => $self->o('trf'),
                              repeatmasker       => $self->o('repeatmasker'),
                              dna_analyses       => $self->o('dna_analyses'),
                              max_seq_length     => $self->o('max_seq_length'),
                              always_use_repbase => $self->o('always_use_repbase'),
                              rm_library         => $self->o('repeatmasker_library'),
                              rm_sensitivity     => $self->o('repeatmasker_sensitivity'),
                              rm_logic_name      => $self->o('repeatmasker_logic_name'),
                              pipeline_dir       => $self->o('pipeline_dir'),
                              db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2->A' => ['AnalysisSetup'],
                              'A->1' => ['DeleteRepeatConsensus'],
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
      -logic_name        => 'DeleteRepeatConsensus',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::SqlCmd',
      -max_retry_count   => 1,
      -batch_size        => 10,
      -parameters        => {
                              sql => [
                                'DELETE rc.* FROM '.
                                'repeat_consensus rc LEFT OUTER JOIN '.
                                'repeat_feature rf USING (repeat_consensus_id) '.
                                'WHERE rf.repeat_consensus_id IS NULL'
                              ]
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
      -flow_into         => [
                              WHEN('#dust# || #trf#' => ['SplitDumpFiles_1']),
                              WHEN('#repeatmasker#'  => ['SplitDumpFiles_2']),
                            ],
    },

    {
      -logic_name        => 'SplitDumpFiles_1',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
      -parameters        => {
                              fasta_file              => '#genome_file#',
                              max_seq_length_per_file => $self->o('dust_trf_max_seq_length'),
                              max_seqs_per_file       => $self->o('dust_trf_max_seqs_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                              out_dir                 => catdir($self->o('pipeline_dir'), '#species#', 'dust_trf'),
                              file_varname            => 'queryfile',
                            },
      -rc_name           => '8Gb_mem',
      -flow_into         => {
                              '2' => [
                                WHEN('#dust#' => ['Dust']),
                                WHEN('#trf#'  => ['TRF']),
                              ],
                            },
    },

    {
      -logic_name        => 'SplitDumpFiles_2',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
      -parameters        => {
                              fasta_file              => '#genome_file#',
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                              out_dir                 => catdir($self->o('pipeline_dir'), '#species#', 'repeatmasker'),
                              file_varname            => 'queryfile',
                            },
      -rc_name           => '8Gb_mem',
      -flow_into         => {
                              '2' => ['RepeatMaskerFactory'],
                            },
    },

    {
      -logic_name        => 'Dust',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNAFeatures::DustMasker',
      -hive_capacity     => $self->o('max_hive_capacity'),
      -max_retry_count   => 1,
      -batch_size        => 100,
      -parameters        => {
                              logic_name      => 'dust',
                              parameters_hash => $self->o('dust_parameters_hash'),
                            },
      -rc_name           => 'normal',
    },
    
    {
      -logic_name        => 'TRF',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNAFeatures::TRF',
      -hive_capacity     => $self->o('max_hive_capacity'),
      -max_retry_count   => 1,
      -batch_size        => 10,
      -parameters        => {
                              logic_name      => 'trf',
                              parameters_hash => $self->o('trf_parameters_hash'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'RepeatMaskerFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNAFeatures::RepeatMaskerFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              always_use_repbase => $self->o('always_use_repbase'),
                              rm_library         => $self->o('repeatmasker_library'),
                              rm_logic_name      => $self->o('repeatmasker_logic_name'),
                              max_seq_length     => $self->o('max_seq_length'),
                            },
      -rc_name           => '8Gb_mem',
      -flow_into         => ['RepeatMasker'],
    },

    {
      -logic_name        => 'RepeatMasker',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNAFeatures::RepeatMasker',
      -hive_capacity     => $self->o('max_hive_capacity'),
      -max_retry_count   => 1,
      -parameters        => {
                              repeatmasker_cache => $self->o('repeatmasker_cache'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'UpdateMetadata',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNAFeatures::UpdateMetadata',
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => WHEN('#email_report#' => ['EmailRepeatReport']),
    },

    {
      -logic_name        => 'EmailRepeatReport',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNAFeatures::EmailRepeatReport',
      -parameters        => {
                              email   => $self->o('email'),
                              subject => 'DNA features pipeline: Repeat report for #species#',
                            },
      -rc_name           => 'normal',
    }

  ];
}

1;
