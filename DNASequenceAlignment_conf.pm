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

package Bio::EnsEMBL::EGPipeline::PipeConfig::DNASequenceAlignment_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{ $self->SUPER::default_options() },

    pipeline_name => 'dna_seq_alignment_'.$self->o('ensembl_release'),

    species => [],
    antispecies => [],
    division => [],
    run_all => 0,
    meta_filters => {},

    # This pipeline can align data from one or more files, or direct
    # from ENA; it _could_ use data from both sources, but you're liable
    # to get in a muddle if you do that, so it's not recommended.
    file          => [],
    file_species  => {},
    study         => [],
    study_species => {},
    merge_level   => 'sample',
    
    # RNA-seq options
    ini_type      => 'rnaseq_align',
    bigwig        => 0,
    vcf           => 0,
    use_csi       => 0,
    clean_up      => 1,
    
    # EST/cDNA options
    reformat_header => 1,
    trim_est        => 1,

    # Can put results into a core or otherfeatures database, although the
    # default is not to, since a BAM file is usually enough. Also, loading
    # currently only seems to work for results from the STAR aligner.
    load_db   => 0,
    db_type   => 'otherfeatures',
    insdc_ids => 1,

    # Parameters for dumping and splitting Fasta DNA query files.
    max_seq_length_per_file => 30000000,
    max_seqs_per_file       => undef,
    max_files_per_directory => 50,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),

    # Parameters for repeatmasking the genome files.
    repeat_masking   => 'soft',
    repeat_libs      => [],
    min_slice_length => 0,

    # Aligner options.
    aligner    => 'star',
    threads    => 4,
    data_type  => 'rnaseq',
    read_type  => 'default',

    logic_name => $self->o('data_type').'_'.$self->o('aligner'),

    program_dir        => '/nfs/panda/ensemblgenomes/external/exonerate-2.2.0-x86_64-Linux/bin',
    exonerate_exe      => catdir($self->o('program_dir'), 'exonerate'),
    exonerate_program  => 'exonerate',
    exonerate_version  => '2.2.0',
    # Thresholds for filtering transcripts.
    coverage       => 90,
    percent_id     => 97,
    best_in_genome => 1,
      {
        'logic_name'      => 'est_exonerate',
        'program'         => $self->o('exonerate_program'),
        'program_version' => $self->o('exonerate_version'),
        'program_file'    => $self->o('exonerate_exe'),
        'parameters'      => '--model affine:local --softmasktarget TRUE --bestn 1',
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::ExonerateAlignFeature',
        'linked_tables'   => ['dna_align_feature'],
      },
      
    
    # STAR_2.4.2a was tested on one species, and it used more memory than the
    # default (STAR_2.3.1z), and had less coverage. But if you want to test
    # it, set the following path for STAR:
    # /nfs/panda/ensemblgenomes/external/STAR_2.4.2a.Linux_x86_64

    bowtie2_dir  => '/nfs/panda/ensemblgenomes/external/bowtie2-2.2.6',
    #bwa_dir      => '/nfs/panda/ensemblgenomes/external/bwa',
    bwa_dir      => '/nfs/panda/ensemblgenomes/external/bwa0.7.12_x64-Linux',
    gsnap_dir    => '/nfs/panda/ensemblgenomes/external/gmap-gsnap/bin',
    #gsnap_dir    => '/nfs/panda/ensemblgenomes/external/gmap-gsnap-2015-07-23/bin',
    #star_dir     => '/nfs/panda/ensemblgenomes/external/STAR',
    star_dir     => '/nfs/panda/ensemblgenomes/external/STAR_2.4.2a.Linux_x86_64',

    samtools_dir  => '/nfs/panda/ensemblgenomes/external/samtools',
    bedtools_dir  => '/nfs/panda/ensemblgenomes/external/bedtools/bin',
    ucscutils_dir => '/nfs/panda/ensemblgenomes/external/ucsc_utils',

    trimest_exe => '/nfs/panda/ensemblgenomes/external/EMBOSS/bin/trimest',

    # Remove existing alignments; if => 0 then existing analyses
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

  my %aligner_classes =
  (
    'bowtie2' => 'Bio::EnsEMBL::EGPipeline::Common::Aligner::Bowtie2Aligner',
    'bwa'     => 'Bio::EnsEMBL::EGPipeline::Common::Aligner::BwaAligner',
    'gsnap'   => 'Bio::EnsEMBL::EGPipeline::Common::Aligner::GsnapAligner',
    'star'    => 'Bio::EnsEMBL::EGPipeline::Common::Aligner::StarAligner',
  );
  my $aligner_class = $aligner_classes{$self->o('aligner')};
  
  my %aligner_dirs =
  (
    'bowtie2' => $self->o('bowtie2_dir'),
    'bwa'     => $self->o('bwa_dir'),
    'gsnap'   => $self->o('gsnap_dir'),
    'star'    => $self->o('star_dir'),
  );
  my $aligner_dir = $aligner_dirs{$self->o('aligner')};

  my $read_type = $self->o('read_type');
  $read_type = 'long_reads' if ($self->o('data_type') !~ /rna_?seq/i);

  my $load_db_analyses = [];
  my $species_factory_flow = { '2' => ['DumpGenome'] };
  
  if ($self->o('load_db')) {
    $load_db_analyses = $self->load_db_analyses($aligner_class);
    
    if ($self->o('db_type') eq 'core') {
      $species_factory_flow = {
        '2->A' => ['CheckCoreDatabase'],
        'A->2' => ['DNASequenceAlignment'],
      };
    } else {
      $species_factory_flow = {
        '2->A' => ['CheckOFDatabase'],
        'A->2' => ['DNASequenceAlignment'],
      };
    }
    
    #push @$merge_bam_flow, 'LoadAlignments';
  }

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
      -flow_into         => $species_factory_flow,
      -meadow_type       => 'LOCAL',
    },

    @$load_db_analyses,

    {
      -logic_name        => 'DumpGenome',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNASequenceAlignment::DumpGenome',
      -analysis_capacity => 5,
      -batch_size        => 2,
      -max_retry_count   => 1,
      -parameters        => {
                              genome_dir       => catdir($self->o('pipeline_dir'), '#species#'),
                              repeat_masking   => $self->o('repeat_masking'),
                              repeat_libs      => $self->o('repeat_libs'),
                              min_slice_length => $self->o('min_slice_length'),
                              bigwig           => $self->o('bigwig'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '3' => ['IndexGenome'],
                              '4' => ['SequenceLengths'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'SequenceLengths',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNASequenceAlignment::SequenceLengths',
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
                              escape_branch => -1,
                            },
      -rc_name           => '16Gb_threads',
      -flow_into         => {
                              '-1' => ['IndexGenome_HighMem'],
                               '1' => ['SequenceFactory'],
                            },
      -meadow_type       => 'LOCAL',
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
      -rc_name           => '32Gb_threads',
      -flow_into         => {
                              '1' => ['SequenceFactory'],
                            },
    },

    {
      -logic_name        => 'SequenceFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNASequenceAlignment::SequenceFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              file            => $self->o('file'),
                              file_species    => $self->o('file_species'),
                              study           => $self->o('study'),
                              study_species   => $self->o('study_species'),
                              merge_level     => $self->o('merge_level'),
                              data_type       => $self->o('data_type'),
                              reformat_header => $self->o('reformat_header'),
                              trim_est        => $self->o('trim_est'),
                              trimest_exe     => $self->o('trimest_exe'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '3' => ['SplitSeqFile'],
                              '4' => ['SRASeqFile'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'SplitSeqFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNASequenceAlignment::SplitSeqFile',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                              out_dir                 => catdir($self->o('pipeline_dir'), '#species#', 'seqs'),
                              delete_existing_files   => 0,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2->A' => ['AlignSequence'],
                              'A->1' => ['MergeBam'],
                            },
    },

    {
      -logic_name        => 'SRASeqFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNASequenceAlignment::SRASeqFile',
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              work_directory => catdir($self->o('pipeline_dir'), '#species#'),
                              merge_level    => $self->o('merge_level'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2->A' => ['AlignSequence'],
                              'A->1' => ['MergeBam'],
                            },
    },

    {
      -logic_name        => 'AlignSequence',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNASequenceAlignment::AlignSequence',
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
      -rc_name           => '16Gb_threads',
      -flow_into         => {
                              '-1' => ['AlignSequence_HighMem'],
                               '1' => {
                                        ':////accu?merge={bam_file}' => {'merge' => '#merge_id#'},
                                        ':////accu?study_id=[]'      => ['#study_id#'],
                                      },
                            },
    },

    {
      -logic_name        => 'AlignSequence_HighMem',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNASequenceAlignment::AlignSequence',
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
      -rc_name           => '32Gb_threads',
      -flow_into         => {
                               '1' => {
                                        ':////accu?merge={bam_file}' => {'merge' => '#merge_id#'},
                                        ':////accu?study_id=[]'      => ['#study_id#'],
                                      },
                            },
    },

    {
      -logic_name        => 'ExonerateAlignFeature',
      -module            => 'Bio::EnsEMBL::EGPipeline::Exonerate::ExonerateAlignFeature',
      -analysis_capacity => $self->o('max_exonerate_jobs'),
      -max_retry_count   => 1,
      -parameters        => {
                              db_type     => 'otherfeatures',
                              logic_name  => $logic_name,
                              queryfile   => '#genome_file#',
                              daemon_file => '#genome_file#'.'.daemon',
                              seq_file    => '#split_file#',
                              seq_type    => $self->o('seq_type'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'MergeBam',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNASequenceAlignment::MergeBam',
      -max_retry_count   => 1,
      -parameters        => {
                              merge          => '#merge#',
                              study_id       => '#study_id#',
                              work_directory => catdir($self->o('pipeline_dir'), '#species#'),
                              samtools_dir   => $self->o('samtools_dir'),
                              vcf            => $self->o('vcf'),
                              use_csi        => $self->o('use_csi'),
                              clean_up       => $self->o('clean_up'),
                              bigwig         => $self->o('bigwig'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '3' => ['WriteIniFile'],
                              '4' => ['CreateBigWig'],
                            },
    },

    {
      -logic_name        => 'CreateBigWig',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNASequenceAlignment::CreateBigWig',
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              bedtools_dir  => $self->o('bedtools_dir'),
                              ucscutils_dir => $self->o('ucscutils_dir'),
                              length_file   => '#genome_file#'.'.lengths.txt',
                              clean_up      => $self->o('clean_up'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['WriteIniFile'],
    },

    {
      -logic_name        => 'WriteIniFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNASequenceAlignment::WriteIniFile',
      -max_retry_count   => 1,
      -parameters        => {
                              work_directory => catdir($self->o('pipeline_dir'), '#species#'),
                              ini_type       => $self->o('ini_type'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['EmailBamReport'],
    },

    {
      -logic_name        => 'EmailBamReport',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNASequenceAlignment::EmailBamReport',
      -max_retry_count   => 1,
      -parameters        => {
                              email        => $self->o('email'),
                              subject      => 'DNA Alignment pipeline: Report for #species#',
                              samtools_dir => $self->o('samtools_dir'),
                            },
      -rc_name           => 'normal',
    },

  ];
}

sub resource_classes {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::resource_classes},
    '16Gb_threads' => {'LSF' => '-q production-rh6 -n '.$self->o('threads').' -R "span[hosts=1]" -M 16000 -R "rusage[mem=16000,tmp=16000]"'},
    '32Gb_threads' => {'LSF' => '-q production-rh6 -n '.$self->o('threads').' -R "span[hosts=1]" -M 32000 -R "rusage[mem=32000,tmp=32000]"'},
  }
}

sub load_db_analyses {
  my ($self, $aligner_class) = @_;
  
  return [
  
    {
      -logic_name        => 'CheckCoreDatabase',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 1,
      -can_be_empty      => 1,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => {
                              '2->A' => ['PreAlignmentBackup'],
                              'A->1' => ['AnalysisSetup'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'CheckOFDatabase',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::CheckOFDatabase',
      -max_retry_count   => 1,
      -can_be_empty      => 1,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => {
                              '2->A' => ['PreAlignmentBackup'],
                              '3->A' => ['CreateOFDatabase'],
                              'A->1' => ['AnalysisSetup'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'PreAlignmentBackup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              db_type     => $self->o('db_type'),
                              output_file => catdir($self->o('pipeline_dir'), '#species#', 'pre_alignment_bkp.sql.gz'),
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
      -logic_name        => 'AnalysisSetup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count   => 0,
      -parameters        => {
                              logic_name         => $self->o('logic_name'),
                              program            => $self->o('aligner'),
                              module             => $aligner_class,
                              db_type            => $self->o('db_type'),
                              linked_tables      => ['dna_align_feature'],
                              db_backup_required => '#db_exists#',
                              delete_existing    => $self->o('delete_existing'),
                              production_lookup  => $self->o('production_lookup'),
                              production_db      => $self->o('production_db'),
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'DNASequenceAlignment',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -parameters        => {},
      -flow_into         => {
                              '1->A' => ['DumpGenome'],
                              'A->1' => ['PostAlignmentBackup'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'LoadAlignments',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNASequenceAlignment::LoadAlignments',
      -analysis_capacity => 25,
      -max_retry_count   => 1,
      -parameters        => {
                              db_type      => $self->o('db_type'),
                              logic_name   => $self->o('logic_name'),
                              insdc_ids    => $self->o('insdc_ids'),
                              samtools_dir => $self->o('samtools_dir'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'PostAlignmentBackup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -max_retry_count   => 1,
      -parameters        => {
                              db_type     => $self->o('db_type'),
                              output_file => catdir($self->o('pipeline_dir'), '#species#', 'post_alignment_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['MetaCoords'],
    },

    {
      -logic_name        => 'MetaCoords',
      -module            => 'Bio::EnsEMBL::EGPipeline::CoreStatistics::MetaCoords',
      -max_retry_count   => 1,
      -parameters        => {
                              db_type => $self->o('db_type'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['MetaLevels'],
    },

    {
      -logic_name        => 'MetaLevels',
      -module            => 'Bio::EnsEMBL::EGPipeline::CoreStatistics::MetaLevels',
      -max_retry_count   => 1,
      -parameters        => {
                              db_type => $self->o('db_type'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['EmailOtherFeaturesReport'],
    },

    {
      -logic_name        => 'EmailOtherFeaturesReport',
      -module            => 'Bio::EnsEMBL::EGPipeline::DNASequenceAlignment::EmailOtherFeaturesReport',
      -max_retry_count   => 1,
      -parameters        => {
                              email        => $self->o('email'),
                              subject      => 'DNA Alignment pipeline: Report for #species#',
                              db_type      => $self->o('db_type'),
                              file         => $self->o('file'),
                              file_species => $self->o('file_species'),
                              aligner      => $self->o('aligner'),
                              data_type    => $self->o('data_type'),
                              logic_name   => $self->o('logic_name'),
                            },
      -rc_name           => 'normal',
    },

  ];
}

1;
