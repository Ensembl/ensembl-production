=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::EGPipeline::PipeConfig::ShortReadAlignment_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

use File::Spec::Functions qw(catdir);

# To-do list:
# Work out how to stop STAR from filtering short reads in EST-mode.
# For STAR report its statistics rather than the less meaningful BAM stats.

sub default_options {
  my ($self) = @_;
  return {
    %{ $self->SUPER::default_options() },

    pipeline_name => 'short_read_alignment_'.$self->o('ensembl_release'),

    species => [],
    antispecies => [],
    division => [],
    run_all => 0,
    meta_filters => {},

    # Calculating genome indexes is time-consuming, so it may be useful
    # to store them separately (semi-permanently).
    index_dir => catdir($self->o('pipeline_dir'), 'index'),

    # This pipeline can align data from one or more files, or direct
    # from ENA; it _could_ use data from both sources, but you're liable
    # to get in a muddle if you do that, so it's not recommended.
    seq_file         => [],
    seq_file_pair    => [],
    run              => [],
    study            => [],
    merge_level      => 'run',
    merge_id         => undef,
    tax_id_restrict  => 1,
    
    # RNA-seq options
    ini_type      => 'rnaseq_align',
    bigwig        => 0,
    vcf           => 0,
    use_csi       => 0,
    clean_up      => 1,
    
    # Parameters for dumping and splitting Fasta DNA query files.
    max_seq_length_per_file => 30000000,
    max_seqs_per_file       => undef,
    max_files_per_directory => 50,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),

    # Parameters for repeatmasking the genome files.
    repeat_masking     => 'soft',
    repeat_logic_names => [],
    min_slice_length   => 0,

    # Aligner options.
    aligner    => 'bwa',
    threads    => 4,
    data_type  => 'rnaseq',
    read_type  => 'default',

    # Some of the aligners have newer versions, but it's not a given that
    # these will be better than the version we've used up till now. So the
    # latter is the default, but you can experiment with the latest versions
    # by commenting/uncommenting below.
    bowtie2_dir  => '/nfs/panda/ensemblgenomes/external/bowtie2-2.2.6',
    
    bwa_dir      => '/nfs/panda/ensemblgenomes/external/bwa',
    #bwa_dir      => '/nfs/panda/ensemblgenomes/external/bwa0.7.12_x64-Linux',
    
    gsnap_dir    => '/nfs/panda/ensemblgenomes/external/gmap-gsnap/bin',
    #gsnap_dir    => '/nfs/panda/ensemblgenomes/external/gmap-gsnap-2015-11-20/bin',
    
    star_dir     => '/nfs/panda/ensemblgenomes/external/STAR',
    #star_dir     => '/nfs/panda/ensemblgenomes/external/STAR_2.4.2a.Linux_x86_64',

    # Different aligners have different memory requirements; unless explicitly
    # over-ridden, use defaults, which should work on a genome that isn't too
    # fragmented, of size < 1Gb. (Values here are MB.)
    index_memory      => undef,
    index_memory_high => undef,
    align_memory      => undef,
    align_memory_high => undef,
    
    index_memory_default => {
      'bowtie2' =>  8000,
      'bwa'     => 16000,
      'gsnap'   => 16000,
      'star'    => 32000,
    },
    index_memory_high_default => {
      'bowtie2' => 16000,
      'bwa'     => 32000,
      'gsnap'   => 32000,
      'star'    => 64000,
    },
    align_memory_default => {
      'bowtie2' =>  8000,
      'bwa'     => 32000,
      'gsnap'   => 32000,
      'star'    => 16000,
    },
    align_memory_high_default => {
      'bowtie2' => 16000,
      'bwa'     => 64000,
      'gsnap'   => 64000,
      'star'    => 32000,
    },

    samtools_dir  => '/nfs/panda/ensemblgenomes/external/samtools',
    bedtools_dir  => '/nfs/panda/ensemblgenomes/external/bedtools/bin',
    ucscutils_dir => '/nfs/panda/ensemblgenomes/external/ucsc_utils',
    
    # 4GB per thread for samtools sort
    sort_memory => 4000,
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
  
  my $merge_bam_table =
    'CREATE TABLE merge_bam ('.
      'merge_id varchar(255) NOT NULL, '.
      'bam_file varchar(255) NOT NULL) ';
  
  my $align_cmds_table =
    'CREATE TABLE align_cmds ('.
      'auto_id INT AUTO_INCREMENT PRIMARY KEY, '.
      'merge_id varchar(255) NOT NULL, '.
      'run_id varchar(255) NULL, '.
      'cmds text NOT NULL, '.
      'version varchar(255) NULL)';

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.catdir($self->o('pipeline_dir'), $self->o('aligner')),
    'mkdir -p '.catdir($self->o('results_dir'), $self->o('aligner')),
    $self->db_cmd($merge_bam_table),
    $self->db_cmd($align_cmds_table),
  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    'bigwig' => $self->o('bigwig'),
  };
}

sub pipeline_analyses {
  my ($self) = @_;
  
  # The analyses are defined within a function, to allow inheriting conf
  # files to easily modify the core functionality of this pipeline.
  my $alignment_analyses = $self->alignment_analyses();
  $self->modify_analyses($alignment_analyses);
  
  return $alignment_analyses;
}

sub aligner_parameters {
  my ($self, $aligner, $data_type, $read_type) = @_;
  
  my %aligner_classes =
  (
    'bowtie2' => 'Bio::EnsEMBL::EGPipeline::Common::Aligner::Bowtie2Aligner',
    'bwa'     => 'Bio::EnsEMBL::EGPipeline::Common::Aligner::BwaAligner',
    'gsnap'   => 'Bio::EnsEMBL::EGPipeline::Common::Aligner::GsnapAligner',
    'star'    => 'Bio::EnsEMBL::EGPipeline::Common::Aligner::StarAligner',
  );
  my $aligner_class = $aligner_classes{$aligner};
  
  my %aligner_dirs =
  (
    'bowtie2' => $self->o('bowtie2_dir'),
    'bwa'     => $self->o('bwa_dir'),
    'gsnap'   => $self->o('gsnap_dir'),
    'star'    => $self->o('star_dir'),
  );
  my $aligner_dir = $aligner_dirs{$aligner};
  
  $read_type = 'long_reads' if $data_type !~ /rna_?seq/i;
  
  return ($aligner_class, $aligner_dir, $read_type);
}

sub alignment_analyses {
  my ($self) = @_;
  
  my ($aligner_class, $aligner_dir, $read_type) =
    $self->aligner_parameters(
      $self->o('aligner'),
      $self->o('data_type'),
      $self->o('read_type')
    );
  
  my $pipeline_dir = catdir($self->o('pipeline_dir'), $self->o('aligner'));
  my $results_dir  = catdir($self->o('results_dir'), $self->o('aligner'));
  my $index_dir    = catdir($self->o('index_dir'), $self->o('aligner'));
  
  return
  [
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
                              '2' => ['DumpGenome'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'DumpGenome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DumpGenome',
      -analysis_capacity => 5,
      -batch_size        => 2,
      -max_retry_count   => 1,
      -parameters        => {
                              genome_dir         => catdir($index_dir, '#species#'),
                              repeat_masking     => $self->o('repeat_masking'),
                              repeat_logic_names => $self->o('repeat_logic_names'),
                              min_slice_length   => $self->o('min_slice_length'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '1' => WHEN('#bigwig#' =>
                                       ['SequenceLengths'],
                                     ELSE
                                       ['IndexGenome']),
                            },
    },

    {
      -logic_name        => 'SequenceLengths',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::ShortRead::SequenceLengths',
      -analysis_capacity => 5,
      -batch_size        => 2,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              fasta_file  => '#genome_file#',
                              length_file => '#genome_file#'.'.lengths.txt',
                            },
      -rc_name           => 'normal',
      -flow_into         => ['IndexGenome'],
    },

    {
      -logic_name        => 'IndexGenome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::IndexGenome',
      -analysis_capacity => 5,
      -batch_size        => 2,
      -max_retry_count   => 1,
      -parameters        => {
                              aligner_class => $aligner_class,
                              aligner_dir   => $aligner_dir,
                              samtools_dir  => $self->o('samtools_dir'),
                              threads       => $self->o('threads'),
                              memory_mode   => 'default',
                              overwrite     => 0,
                              escape_branch => -1,
                            },
      -rc_name           => 'index_default',
      -flow_into         => {
                              '-1' => ['IndexGenome_HighMem'],
                               '1' => ['SequenceFactory'],
                            },
    },

    {
      -logic_name        => 'IndexGenome_HighMem',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::IndexGenome',
      -analysis_capacity => 5,
      -batch_size        => 2,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              aligner_class => $aligner_class,
                              aligner_dir   => $aligner_dir,
                              samtools_dir  => $self->o('samtools_dir'),
                              threads       => $self->o('threads'),
                              memory_mode   => 'himem',
                            },
      -rc_name           => 'index_himem',
      -flow_into         => {
                              '1' => ['SequenceFactory'],
                            },
    },

    {
      -logic_name        => 'SequenceFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::ShortRead::SequenceFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              seq_file        => $self->o('seq_file'),
                              seq_file_pair   => $self->o('seq_file_pair'),
                              run             => $self->o('run'),
                              study           => $self->o('study'),
                              merge_level     => $self->o('merge_level'),
                              merge_id        => $self->o('merge_id'),
                              tax_id_restrict => $self->o('tax_id_restrict'),
                              data_type       => $self->o('data_type'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2->A' => ['SeqFile'],
                              '3->B' => ['PairedSeqFile'],
                              '4->C' => ['SRASeqFile'],
                              '5->D' => ['SplitSeqFile'],
                              'A->1' => ['MergeBam'],
                              'B->1' => ['MergeBam'],
                              'C->1' => ['MergeBam'],
                              'D->1' => ['MergeBam'],
                            },
    },

    {
      -logic_name        => 'SeqFile',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -can_be_empty      => 1,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => {
                              '1' => ['AlignSequence'],
                            },
    },

    {
      -logic_name        => 'PairedSeqFile',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -can_be_empty      => 1,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => {
                              '1' => ['AlignSequence'],
                            },
    },

    {
      -logic_name        => 'SRASeqFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::ShortRead::SRASeqFile',
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              work_dir => catdir($pipeline_dir, '#species#'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['AlignSequence'],
                            },
    },

    {
      -logic_name        => 'SplitSeqFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                              out_dir                 => catdir($pipeline_dir, '#species#', 'seqs'),
                              delete_existing_files   => 0,
                              file_varname            => 'seq_file_1',
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['AlignSequence'],
                            },
    },

    {
      -logic_name        => 'AlignSequence',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::ShortRead::AlignSequence',
      -analysis_capacity => 25,
      -max_retry_count   => 1,
      -parameters        => {
                              aligner_class  => $aligner_class,
                              aligner_dir    => $aligner_dir,
                              samtools_dir   => $self->o('samtools_dir'),
                              threads        => $self->o('threads'),
                              read_type      => $read_type,
                              clean_up       => $self->o('clean_up'),
                              escape_branch  => -1,
                            },
      -rc_name           => 'align_default',
      -flow_into         => {
                              '-1' => ['AlignSequence_HighMem'],
                               '1' => ['?table_name=merge_bam', '?table_name=align_cmds'],
                            },
    },

    {
      -logic_name        => 'AlignSequence_HighMem',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::ShortRead::AlignSequence',
      -analysis_capacity => 25,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              aligner_class  => $aligner_class,
                              aligner_dir    => $aligner_dir,
                              samtools_dir   => $self->o('samtools_dir'),
                              threads        => $self->o('threads'),
                              read_type      => $read_type,
                              clean_up       => $self->o('clean_up'),
                            },
      -rc_name           => 'align_himem',
      -flow_into         => {
                               '1' => ['?table_name=merge_bam', '?table_name=align_cmds'],
                            },
    },

    {
      -logic_name        => 'MergeBam',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::ShortRead::MergeBam',
      -max_retry_count   => 1,
      -parameters        => {
                              results_dir  => catdir($results_dir, '#species#'),
                              samtools_dir => $self->o('samtools_dir'),
                              vcf          => $self->o('vcf'),
                              use_csi      => $self->o('use_csi'),
                              clean_up     => $self->o('clean_up'),
                              sort_memory  => $self->o('sort_memory'),
                            },
      -rc_name           => 'merge_sort',
      -flow_into         => {
                              '2' => ['?table_name=align_cmds',
                                     
                                     WHEN('#bigwig#' =>
                                       ['CreateBigWig'],
                                     ELSE
                                       ['WriteIniFile']),
                                     
                                     ],
                            },
    },

    {
      -logic_name        => 'CreateBigWig',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::ShortRead::CreateBigWig',
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              bedtools_dir  => $self->o('bedtools_dir'),
                              ucscutils_dir => $self->o('ucscutils_dir'),
                              length_file   => '#genome_file#'.'.lengths.txt',
                              clean_up      => $self->o('clean_up'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['WriteIniFile', '?table_name=align_cmds'],
    },

    {
      -logic_name        => 'WriteIniFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::ShortRead::WriteIniFile',
      -max_retry_count   => 1,
      -parameters        => {
                              results_dir => catdir($results_dir, '#species#'),
                              merge_level => $self->o('merge_level'),
                              ini_type    => $self->o('ini_type'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['WriteCmdFile'],
    },

    {
      -logic_name        => 'WriteCmdFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::ShortRead::WriteCmdFile',
      -max_retry_count   => 1,
      -parameters        => {
                              aligner     => $self->o('aligner'),
                              results_dir => catdir($results_dir, '#species#'),
                              merge_level => $self->o('merge_level'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['EmailReport'],
    },

    {
      -logic_name        => 'EmailReport',
      -module            => 'Bio::EnsEMBL::EGPipeline::SequenceAlignment::ShortRead::EmailReport',
      -max_retry_count   => 1,
      -parameters        => {
                              email        => $self->o('email'),
                              subject      => 'Short Read Alignment pipeline: Report for #species#',
                              samtools_dir => $self->o('samtools_dir'),
                            },
      -rc_name           => 'normal',
    },
  ];
}

sub modify_analyses {
  my ($self, $analyses) = @_;
}

sub resource_classes {
  my ($self) = @_;
  
  my $threads                   = $self->o('threads');
  my $aligner                   = $self->o('aligner');
  my $index_memory_default      = $self->o('index_memory_default');
  my $index_memory_high_default = $self->o('index_memory_high_default');
  my $align_memory_default      = $self->o('align_memory_default');
  my $align_memory_high_default = $self->o('align_memory_high_default');
  
  my $index_mem      = $self->o('index_memory')      || $$index_memory_default{$aligner};
  my $index_himem    = $self->o('index_memory_high') || $$index_memory_high_default{$aligner};
  my $align_mem      = $self->o('align_memory')      || $$align_memory_default{$aligner};
  my $align_himem    = $self->o('align_memory_high') || $$align_memory_high_default{$aligner};
  my $merge_sort_mem = $self->o('sort_memory') * 1.25;  # Samtools sort is more greedy than we ask
  my $merge_sort_threads = 1;  # Looks like more is counterproductive...
  
  return {
    %{$self->SUPER::resource_classes},
    'index_default' => {'LSF' => '-q production-rh6 -n '. ($threads + 1) .' -M '.$index_mem.     ' -R "rusage[mem='.$index_mem.     ',tmp=16000] span[hosts=1]"'},
    'index_himem'   => {'LSF' => '-q production-rh6 -n '. ($threads + 1) .' -M '.$index_himem.   ' -R "rusage[mem='.$index_himem.   ',tmp=16000] span[hosts=1]"'},
    'align_default' => {'LSF' => '-q production-rh6 -n '. ($threads + 1) .' -M '.$align_mem.     ' -R "rusage[mem='.$align_mem.     ',tmp=16000] span[hosts=1]"'},
    'align_himem'   => {'LSF' => '-q production-rh6 -n '. ($threads + 1) .' -M '.$align_himem.   ' -R "rusage[mem='.$align_himem.   ',tmp=16000] span[hosts=1]"'},
    'merge_sort'    => {'LSF' => '-q production-rh6 -n '. ($merge_sort_threads + 1) .' -M '.$merge_sort_mem.' -R "rusage[mem='.$merge_sort_mem.',tmp=16000] span[hosts=1]"'},
  }
}

1;
