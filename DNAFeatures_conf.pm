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

    # Parameters for dumping and splitting Fasta DNA files...
    max_seq_length          => 1000000,
    max_seq_length_per_file => $self->o('max_seq_length'),
    max_seqs_per_file       => undef,
    max_files_per_directory => 50,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),
    
    # ...or for skipping splitting files entirely. If this option
    # is switched on then dust and trf will be run against a single
    # genome file, and repeatmasker will chunk on-the-fly.
    no_file_splitting => 0,
    
    # Default hive capacity is quite low; values >100 are not recommended.
    max_hive_capacity => 25,

    program_dir      => '/nfs/panda/ensemblgenomes/external/bin',
    dust_exe         => catdir($self->o('program_dir'), 'dustmasker'),
    repeatmasker_exe => catdir($self->o('program_dir'), 'RepeatMasker'),
    trf_exe          => catdir($self->o('program_dir'), 'trf'),

    no_dust         => 0,
    no_repeatmasker => 0,
    no_trf          => 0,

    # By default, run RepeatMasker with repbase library, exclude low-complexity
    # annotations, and use slower (and more sensitive) search. By explicitly
    # turning on the GC calculations, the results are made consistent
    # regardless of the number of sequences in the input file. A species
    # parameter is added when the program is called within the pipeline.
    repeatmasker_default_lib => '/nfs/panda/ensemblgenomes/external/RepeatMasker/Libraries/RepeatMaskerLib.embl',
    repeatmasker_library     => {},
    repeatmasker_parameters  => '-nolow -s -gccalc',
    logic_name               => {},
    always_use_repbase       => 0,

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
        'gff_feature'     => 'repeat_region',
        'linked_tables'   => ['repeat_feature'],
      },
      {
        'logic_name'      => 'repeatmask',
        'db'              => 'repbase',
        'db_version'      => '20140131',
        'db_file'         => $self->o('repeatmasker_default_lib'),
        'program'         => 'RepeatMasker',
        'program_version' => '3.3.0',
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
        'program_version' => '3.3.0',
        'program_file'    => $self->o('repeatmasker_exe'),
        'parameters'      => $self->o('repeatmasker_parameters'),
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::RepeatMasker',
        'gff_source'      => 'repeatmasker',
        'gff_feature'     => 'repeat_region',
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
    ],

    # Remove existing DNA features; if => 0 then existing analyses
    # and their features will remain, with the logic_name suffixed by '_bkp'.
    delete_existing => 1,

    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,

    # By default, an email is sent for each species when the pipeline
    # is complete, showing the breakdown of repeat coverage.
    email_repeat_report => 1,
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

  my $programs = [];
  if (!$self->o('no_dust')) {
    push @$programs, 'Dust';
  }
  if (!$self->o('no_repeatmasker')) {
    push @$programs, 'RepeatMaskerFactory';
  }
  if (!$self->o('no_trf')) {
    push @$programs, 'TRF';
  }

  my ($dump_genome_flow, $split_dump_files_flow, $file_name);
  if ($self->o('no_file_splitting')) {
    $dump_genome_flow = $programs;
    $split_dump_files_flow = [];
    $file_name = '#genome_file#';
  } else {
    $dump_genome_flow = ['SplitDumpFiles'];
    $split_dump_files_flow = $programs;
    $file_name = '#split_file#';
  }

  my $update_metadata_flow = [];
  if ($self->o('email_repeat_report')) {
    push @$update_metadata_flow, 'EmailRepeatReport';
  }

  return [
    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              species     => $self->o('species'),
                              antispecies => $self->o('antispecies'),
                              division    => $self->o('division'),
                              run_all     => $self->o('run_all'),
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
                              no_dust              => $self->o('no_dust'),
                              no_repeatmasker      => $self->o('no_repeatmasker'),
                              no_trf               => $self->o('no_trf'),
                              dna_analyses         => $self->o('dna_analyses'),
                              repeatmasker_library => $self->o('repeatmasker_library'),
                              logic_name           => $self->o('logic_name'),
                              always_use_repbase   => $self->o('always_use_repbase'),
                              pipeline_dir         => $self->o('pipeline_dir'),
                              db_backup_file       => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            },
      -flow_into         => {
                              '2->A' => ['AnalysisSetup'],
                              'A->1' => ['DeleteRepeatConsensus'],
                            },
      -meadow_type       => 'LOCAL',
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
      -flow_into         => $dump_genome_flow,
    },

    {
      -logic_name        => 'SplitDumpFiles',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
      -parameters        => {
                              fasta_file              => '#genome_file#',
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                            },
      -rc_name           => '8Gb_mem',
      -flow_into         => $split_dump_files_flow,
    },

    {
      -logic_name        => 'Dust',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNAFeatures::DustMasker',
      -hive_capacity     => $self->o('max_hive_capacity'),
      -max_retry_count   => 1,
      -batch_size        => 100,
      -parameters        => {
                              logic_name      => 'dust',
                              queryfile       => $file_name,
                              parameters_hash => $self->o('dust_parameters_hash'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'RepeatMaskerFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNAFeatures::RepeatMaskerFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              repeatmasker_library => $self->o('repeatmasker_library'),
                              logic_name           => $self->o('logic_name'),
                              queryfile            => $file_name,
                              max_seq_length       => $self->o('max_seq_length'),
                            },
      -rc_name           => '8Gb_mem',
      -flow_into         => ['RepeatMasker'],
    },

    {
      -logic_name        => 'RepeatMasker',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNAFeatures::RepeatMasker',
      -hive_capacity     => $self->o('max_hive_capacity'),
      -max_retry_count   => 1,
      -parameters        => {},
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
                              queryfile       => $file_name,
                              parameters_hash => $self->o('trf_parameters_hash'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'UpdateMetadata',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNAFeatures::UpdateMetadata',
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => $update_metadata_flow,
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
