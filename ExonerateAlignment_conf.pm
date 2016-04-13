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

Bio::EnsEMBL::EGPipeline::PipeConfig::ExonerateAlignment_conf

=head1 DESCRIPTION

Configuration for aligning Fasta files to a genome with Exonerate.
By default, genes are created.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::ExonerateAlignment_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'exonerate_'.$self->o('ensembl_release'),

    species => [],
    antispecies => [],
    division => [],
    run_all => 0,
    meta_filters => {},

    # Parameters for dumping and splitting Fasta DNA query files;
    # the genome file is not split, so that we can use the
    # 'best in genome' option in the transcript filter.
    max_seq_length_per_file => 50000,
    max_seqs_per_file       => undef,
    max_files_per_directory => 100,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),

    # Parameters for repeatmasking the genome files.
    repeat_masking     => 'soft',
    repeat_logic_names => [],
    min_slice_length   => 0,

    program_dir       => '/nfs/panda/ensemblgenomes/external',
    exonerate_2_2_dir => catdir($self->o('program_dir'), 'exonerate-2.2.0-x86_64-Linux/bin'),
    exonerate_exe     => catdir($self->o('exonerate_2_2_dir'), 'exonerate'),
    exonerate_program => 'exonerate',
    exonerate_version => '2.2.0',

    use_exonerate_server => 1,
    server_memory        => 8000,
    max_exonerate_jobs   => undef,
    exonerate_2_4_dir    => catdir($self->o('program_dir'), 'exonerate-2.4.0-fork/bin'),
    fasta2esd_exe        => catdir($self->o('exonerate_2_4_dir'), 'fasta2esd'),
    esd2esi_exe          => catdir($self->o('exonerate_2_4_dir'), 'esd2esi'),
    server_exe           => catdir($self->o('exonerate_2_4_dir'), 'exonerate-server'),
    log_file             => '/tmp/exonerate-server.'.$self->o('ENV', 'USER').'.out',

    reformat_header => 1,
    trim_est        => 1,
    trimest_exe     => catdir($self->o('program_dir'), 'EMBOSS/bin/trimest'),

    # By default, the pipeline assumes EST data, rather than rnaseq or
    # protein data; that genes should not be created based on the alignments;
    # and that the logic name of the analysis will depend on the data type.
    data_type  => 'est',
    make_genes => 0,
    logic_name => undef,

    # Thresholds for filtering transcripts.
    coverage       => 90,
    percent_id     => 97,
    best_in_genome => 1,

    seq_file         => [],
    seq_file_species => {},

    exonerate_analyses =>
    [
      {
        'logic_name'      => 'est_e2g',
        'program'         => $self->o('exonerate_program'),
        'program_version' => $self->o('exonerate_version'),
        'program_file'    => $self->o('exonerate_exe'),
        'parameters'      => '--model est2genome --forwardcoordinates FALSE --softmasktarget TRUE --exhaustive FALSE --score 300 --saturatethreshold 10 --dnahspthreshold 60 --dnawordlen 12 --fsmmemory 2048 --bestn 10 --maxintron 2500 --intronpenalty -25',
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::ExonerateTranscript',
        'linked_tables'   => ['dna_align_feature', 'gene', 'transcript'],
      },
      
      {
        'logic_name'      => 'cdna_e2g',
        'program'         => $self->o('exonerate_program'),
        'program_version' => $self->o('exonerate_version'),
        'program_file'    => $self->o('exonerate_exe'),
        'parameters'      => '--model est2genome --forwardcoordinates FALSE --softmasktarget TRUE --exhaustive FALSE --score 300 --saturatethreshold 10 --dnahspthreshold 60 --dnawordlen 12 --fsmmemory 2048 --bestn 10 --maxintron 2500 --intronpenalty -25',
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::ExonerateTranscript',
        'linked_tables'   => ['dna_align_feature', 'gene', 'transcript'],
      },
      
      {
        'logic_name'      => 'rnaseq_e2g',
        'program'         => $self->o('exonerate_program'),
        'program_version' => $self->o('exonerate_version'),
        'program_file'    => $self->o('exonerate_exe'),
        'parameters'      => '--model est2genome --forwardcoordinates FALSE --softmasktarget TRUE --exhaustive FALSE --score 300 --saturatethreshold 10 --dnahspthreshold 60 --dnawordlen 12 --fsmmemory 2048 --bestn 10 --maxintron 2500 --intronpenalty -25',
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::ExonerateTranscript',
        'linked_tables'   => ['dna_align_feature', 'gene', 'transcript'],
      },
      
      {
        'logic_name'      => 'protein_e2g',
        'program'         => $self->o('exonerate_program'),
        'program_version' => $self->o('exonerate_version'),
        'program_file'    => $self->o('exonerate_exe'),
        'parameters'      => '--model protein2genome --softmasktarget TRUE --exhaustive FALSE --bestn 1',
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::ExonerateTranscript',
        'linked_tables'   => ['dna_align_feature', 'gene', 'transcript'],
      },
      
      {
        'logic_name'      => 'est_exonerate',
        'program'         => $self->o('exonerate_program'),
        'program_version' => $self->o('exonerate_version'),
        'program_file'    => $self->o('exonerate_exe'),
        'parameters'      => '--model affine:local --softmasktarget TRUE --bestn 1',
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::ExonerateAlignFeature',
        'linked_tables'   => ['dna_align_feature'],
      },
      
      {
        'logic_name'      => 'cdna_exonerate',
        'program'         => $self->o('exonerate_program'),
        'program_version' => $self->o('exonerate_version'),
        'program_file'    => $self->o('exonerate_exe'),
        'parameters'      => '--model affine:local --softmasktarget TRUE --bestn 1',
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::ExonerateAlignFeature',
        'linked_tables'   => ['dna_align_feature'],
      },
      
      {
        'logic_name'      => 'rnaseq_exonerate',
        'program'         => $self->o('exonerate_program'),
        'program_version' => $self->o('exonerate_version'),
        'program_file'    => $self->o('exonerate_exe'),
        'parameters'      => '--model affine:local --softmasktarget TRUE --bestn 1',
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::ExonerateAlignFeature',
        'linked_tables'   => ['dna_align_feature'],
      },
      
      {
        'logic_name'      => 'protein_exonerate',
        'program'         => $self->o('exonerate_program'),
        'program_version' => $self->o('exonerate_version'),
        'program_file'    => $self->o('exonerate_exe'),
        'parameters'      => '--model protein2dna --softmasktarget TRUE --bestn 1',
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::ExonerateAlignFeature',
        'linked_tables'   => ['dna_align_feature'],
      },
    ],

    # Remove existing exonerate alignments; if => 0 then existing analyses
    # and their features will remain, with the logic_name suffixed by '_bkp'.
    delete_existing => 1,

    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,
  };
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
  my ($self) = @_;

  my $options = join(' ',
    $self->SUPER::beekeeper_extra_cmdline_options,
    "-reg_conf ".$self->o('registry'),
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
  
  my $max_exonerate_jobs = $self->o('max_exonerate_jobs');
  if (!defined $max_exonerate_jobs) {
    if ($self->o('use_exonerate_server')) {
      $max_exonerate_jobs = 10;
    } else {
      $max_exonerate_jobs = 100;
    }
  }

  my $make_genes = $self->o('make_genes');
  my $data_type  = $self->o('data_type');
  my $logic_name = $self->o('logic_name');

  if ($self->o('use_exonerate_server')) {
    if ($data_type eq 'protein') {
      die "exonerate-server cannot be used with data_type '$data_type'";
    }
  }
      
  my $analysis_name;
  if ($make_genes) {
    $analysis_name = "$data_type\_e2g";
  } else {
    $analysis_name = "$data_type\_exonerate";
  }
  $logic_name = $analysis_name unless defined $logic_name;
  
  my $dir = $self->o('pipeline_dir');
  
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
                              '2->A' => ['CheckOFDatabase'],
                              'A->2' => ['RunExonerate'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'CheckOFDatabase',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::CheckOFDatabase',
      -max_retry_count   => 1,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => {
                              '2->A' => ['PreExonerateBackup'],
                              '3->A' => ['CreateOFDatabase'],
                              'A->1' => ['AnalysisFactory'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'PreExonerateBackup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              db_type     => 'otherfeatures',
                              output_file => catdir($dir, '#species#', 'pre_exonerate_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'CreateOFDatabase',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::CreateOFDatabase',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {},
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'AnalysisFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::Exonerate::AnalysisFactory',
      -max_retry_count   => 0,
      -parameters        => {
                              exonerate_analyses   => $self->o('exonerate_analyses'),
                              analysis_name        => $analysis_name,
                              logic_name           => $logic_name,
                              db_backup_file       => catdir($dir, '#species#', 'pre_exonerate_bkp.sql.gz'),
                              use_exonerate_server => $self->o('use_exonerate_server'),
                            },
      -flow_into         => {
                              '2->A' => ['AnalysisSetup'],
                              'A->1' => ['RemoveOrphans'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'AnalysisSetup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count   => 0,
      -parameters        => {
                              db_type            => 'otherfeatures',
                              db_backup_required => '#db_exists#',
                              delete_existing    => $self->o('delete_existing'),
                              production_lookup  => $self->o('production_lookup'),
                              production_db      => $self->o('production_db'),
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'RemoveOrphans',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::SqlCmd',
      -max_retry_count   => 0,
      -parameters        => {
                              db_type => 'otherfeatures',
                              sql     => [
                                'DELETE e.*, et.*, sf.* FROM '.
                                  'exon e INNER JOIN '.
                                  'exon_transcript et USING (exon_id) INNER JOIN '.
                                  'supporting_feature sf USING (exon_id) LEFT OUTER JOIN '.
                                  'transcript t USING (transcript_id) '.
                                  'WHERE t.transcript_id IS NULL',
                                'DELETE tsf.* FROM '.
                                  'transcript_supporting_feature tsf LEFT OUTER JOIN '.
                                  'transcript t USING (transcript_id) '.
                                  'WHERE t.transcript_id IS NULL',
                              ]
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'RunExonerate',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -parameters        => {},
      -flow_into         => {
                              '1->A' => ['DumpGenome'],
                              'A->1' => ['PostExonerateBackup'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'DumpGenome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DumpGenome',
      -analysis_capacity => 5,
      -batch_size        => 2,
      -parameters        => {
                              genome_dir         => catdir($dir, '#species#'),
                              repeat_masking     => $self->o('repeat_masking'),
                              repeat_logic_names => $self->o('repeat_logic_names'),
                              min_slice_length   => $self->o('min_slice_length'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['SeqFileFactory'],
    },
    
    {
      -logic_name        => 'SeqFileFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::Exonerate::SeqFileFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              data_type            => $self->o('data_type'),
                              seq_file             => $self->o('seq_file'),
                              seq_file_species     => $self->o('seq_file_species'),
                              use_exonerate_server => $self->o('use_exonerate_server'),
                              reformat_header      => $self->o('reformat_header'),
                              trim_est             => $self->o('trim_est'),
                              trimest_exe          => $self->o('trimest_exe'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['SplitSeqFile'],
                              '3' => ['IndexGenome'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'IndexGenome',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 5,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => 
                            {
                              cmd =>
                              'rm -f '.catdir($dir, '#species#', '#out_subdir#', 'index.es*').'; '.
                              'mkdir -p '.catdir($dir, '#species#', '#out_subdir#').'; '.
                              $self->o('fasta2esd_exe').' '.
                                '#genome_file#'.' '.
                                catdir($dir, '#species#', '#out_subdir#', 'index.esd').'; '.
                              $self->o('esd2esi_exe').' '.
                                catdir($dir, '#species#', '#out_subdir#', 'index.esd').' '.
                                catdir($dir, '#species#', '#out_subdir#', 'index.esi'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '1' => ['StartServer', 'VerifyServer', 'StopServer'],
                            },
    },

    {
      -logic_name        => 'StartServer',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::Exonerate::StartServer',
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              server_exe      => $self->o('server_exe'),
                              index_file      => catdir($dir, '#species#', '#out_subdir#', 'index.esi'),
                              log_file        => $self->o('log_file'),
                              server_file     => catdir($dir, '#species#', '#out_subdir#', 'index.server'),
                              max_connections => $max_exonerate_jobs,
                            },
      -rc_name           => 'server',
    },

    {
      -logic_name        => 'VerifyServer',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::Exonerate::VerifyServer',
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              server_file => catdir($dir, '#species#', '#out_subdir#', 'index.server'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['SplitSeqFile'],
    },

    {
      -logic_name        => 'SplitSeqFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -max_retry_count   => 1,
      -parameters        => {
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                              out_dir                 => catdir($dir, '#species#', '#out_subdir#'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['ExonerateAnalysis'],
                            },
    },

    $self->exonerate_analysis($max_exonerate_jobs, $data_type, $make_genes, $logic_name),

    {
      -logic_name        => 'StopServer',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => 'rm '.catdir($dir, '#species#', '#out_subdir#', 'index.server'),
                            },
      -rc_name           => 'normal',
      -wait_for          => ['ExonerateAnalysis'],
    },

    {
      -logic_name        => 'PostExonerateBackup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -max_retry_count   => 1,
      -parameters        => {
                              db_type     => 'otherfeatures',
                              output_file => catdir($dir, '#species#', 'post_exonerate_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['MakeGenesFlowControl'],
    },

    {
      -logic_name        => 'MakeGenesFlowControl',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FlowControl',
      -max_retry_count   => 1,
      -parameters        => {
                              control_value => $self->o('make_genes'),
                              control_flow  => { '0' => '1', '1' => '2', },
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '1' => ['MetaCoords'],
                              '2' => ['Deduplicate'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'Deduplicate',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::Exonerate::Deduplicate',
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => ['MetaCoords'],
    },

    {
      -logic_name        => 'MetaCoords',
      -module            => 'Bio::EnsEMBL::EGPipeline::CoreStatistics::MetaCoords',
      -max_retry_count   => 1,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => ['EmailReport'],
    },

    {
      -logic_name        => 'EmailReport',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::Exonerate::EmailReport',
      -max_retry_count   => 1,
      -parameters        => {
                              email            => $self->o('email'),
                              subject          => 'Exonerate pipeline: Report for #species#',
                              db_type          => 'otherfeatures',
                              logic_name       => $logic_name,
                              seq_file         => $self->o('seq_file'),
                              seq_file_species => $self->o('seq_file_species'),
                              data_type        => $self->o('data_type'),
                              make_genes       => $self->o('make_genes'),
                              coverage         => $self->o('coverage'),
                              percent_id       => $self->o('percent_id'),
                            },
      -rc_name           => 'normal',
    },

  ];
}

sub exonerate_analysis {
  my ($self, $analysis_capacity, $data_type, $make_genes, $logic_name) = @_;
  
  my ($seq_type, $biotype);
  if ($self->o('data_type') eq 'est') {
    $seq_type = 'dna';
    $biotype  = 'est';
  } elsif ($self->o('data_type') eq 'cdna') {
    $seq_type = 'dna';
    $biotype  = 'cdna';
  } elsif ($self->o('data_type') eq 'rnaseq') {
    $seq_type = 'dna';
    $biotype  = 'RNA-Seq_gene';
  } elsif ($self->o('data_type') eq 'protein') {
    $seq_type = 'protein';
    $biotype  = 'protein_e2g';
  }
  
  my $dir = $self->o('pipeline_dir');
  
  my $exonerate_analysis;
  
  if ($make_genes) {
    $exonerate_analysis = 
    {
      -logic_name        => 'ExonerateAnalysis',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::Exonerate::ExonerateTranscript',
      -analysis_capacity => $analysis_capacity,
      -max_retry_count   => 1,
      -parameters        => {
                              db_type              => 'otherfeatures',
                              logic_name           => $logic_name,
                              biotype              => $biotype,
                              use_exonerate_server => $self->o('use_exonerate_server'),
                              queryfile            => '#genome_file#',
                              server_file          => catdir($dir, '#species#', '#out_subdir#', 'index.server'),
                              seq_file             => '#split_file#',
                              seq_type             => $seq_type,
                              coverage             => $self->o('coverage'),
                              percent_id           => $self->o('percent_id'),
                              best_in_genome       => $self->o('best_in_genome'),
                            },
      -rc_name           => 'normal',
    };
  
  } else {
    $exonerate_analysis =
    {
      -logic_name        => 'ExonerateAnalysis',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::Exonerate::ExonerateAlignFeature',
      -analysis_capacity => $analysis_capacity,
      -max_retry_count   => 1,
      -parameters        => {
                              db_type              => 'otherfeatures',
                              logic_name           => $logic_name,
                              use_exonerate_server => $self->o('use_exonerate_server'),
                              queryfile            => '#genome_file#',
                              server_file          => catdir($dir, '#species#', '#out_subdir#', 'index.server'),
                              seq_file             => '#split_file#',
                              seq_type             => $seq_type,
                            },
      -rc_name           => 'normal',
    };
  
  }
  
  return $exonerate_analysis;
}

sub resource_classes {
  my ($self) = @_;
  
  my $server_memory = $self->o('server_memory');
  my $max_exonerate_jobs = $self->o('max_exonerate_jobs');
  if (!defined $max_exonerate_jobs) {
    if ($self->o('use_exonerate_server')) {
      $max_exonerate_jobs = 10;
    } else {
      $max_exonerate_jobs = 100;
    }
  }

  return {
    %{$self->SUPER::resource_classes},
    'server' => {'LSF' => '-q production-rh6 -n ' . ($max_exonerate_jobs + 1) . ' -R "span[hosts=1]" -M ' . $server_memory . ' -R "rusage[mem=' . $server_memory . '] span[hosts=1]"'},
  }
}

1;
