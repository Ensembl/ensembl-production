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

Bio::EnsEMBL::EGPipeline::PipeConfig::Exonerate_conf

=head1 DESCRIPTION

Configuration for aligning Fasta files to a genome with Exonerate.
By default, genes are created.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::Exonerate_conf;

use strict;
use warnings;

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

    # Parameters for dumping and splitting Fasta DNA query files;
    # the genome file is not split, so that we can use the
    # 'best in genome' option in the transcript filter.
    max_seq_length_per_file => 100000,
    max_seqs_per_file       => undef,
    max_files_per_directory => 100,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),

    max_hive_capacity => 100,

    program_dir        => '/nfs/panda/ensemblgenomes/external/exonerate-2.2.0-x86_64-Linux/bin',
    exonerate_exe      => catdir($self->o('program_dir'), 'exonerate'),
    fasta2esd_exe      => catdir($self->o('program_dir'), 'fasta2esd'),
    esd2esi_exe        => catdir($self->o('program_dir'), 'esd2esi'),
    server_exe         => catdir($self->o('program_dir'), 'exonerate-server'),
    exonerate_program  => 'exonerate',
    exonerate_version  => '2.2.0',
    log_file           => '/tmp/exonerate-server.'.$self->o('ENV', 'USER').'.out',

    # By default, the pipeline assumes EST data, rather than rnaseq or
    # protein data; that genes should be created based on the alignments;
    # and that the logic name of the analysis will depend on the data type. 
    rnaseq     => 0,
    seq_type   => 'dna',
    no_genes   => 0,
    logic_name => undef,
    
    # Thresholds for filtering transcripts.
    coverage       => 90,
    percent_id     => 97,
    best_in_genome => 1,

    seq_file  => undef,
    seq_files => {},

    exonerate_analyses =>
    [
      {
        'logic_name'      => 'estgene_e2g',
        'program'         => $self->o('exonerate_program'),
        'program_version' => $self->o('exonerate_version'),
        'program_file'    => $self->o('exonerate_exe'),
        'parameters'      => '--model est2genome --forwardcoordinates FALSE --softmasktarget TRUE --exhaustive FALSE --score 300 --saturatethreshold 10 --dnahspthreshold 60 --dnawordlen 12 --fsmmemory 2048 --bestn 10 --maxintron 2500 --intronpenalty -25',
        'module'          => 'Bio::EnsEMBL::Analysis::Runnable::ExonerateTranscript',
        'linked_tables'   => ['dna_align_feature', 'gene', 'transcript'],
      },
      
      {
        'logic_name'      => 'trinity_exonerate',
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
        'parameters'      => '--model affine:local --softmasktarget TRUE --bestn 1',
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

  my ($analysis_name, $biotype, $runnable, $post_dump_flow, $dedupe_flow);
  if ($self->o('rnaseq')) {
    if ($self->o('no_genes')) {
      $analysis_name = 'rnaseq_exonerate';
    } else {
      $analysis_name = 'trinity_exonerate';
      $biotype       = 'RNA-Seq_gene';
    }
  } elsif ($self->o('seq_type') eq 'dna') {
    if ($self->o('no_genes')) {
      $analysis_name = 'est_exonerate';
    } else {
      $analysis_name = 'estgene_e2g';
      $biotype       = 'est';
    }
  } elsif ($self->o('seq_type') eq 'protein') {
    if ($self->o('no_genes')) {
      $analysis_name = 'protein_exonerate';
    } else {
      $analysis_name = 'protein_e2g';
      $biotype       = 'protein_e2g';
    }
  }
  my $logic_name = $self->o('logic_name');
  $logic_name = $analysis_name unless defined $logic_name;
  
  if ($self->o('no_genes')) {
    $runnable       = ['ExonerateAlignFeature'];
    $post_dump_flow = ['MetaCoords'];
    $dedupe_flow    = [];
  } else {
    $runnable       = ['ExonerateTranscript'];
    $post_dump_flow = ['Deduplicate'];
    $dedupe_flow    = ['MetaCoords'];
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
                              db_types    => ['core'],
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
      -module            => 'Bio::EnsEMBL::EGPipeline::Exonerate::CheckOFDatabase',
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
                              output_file => catdir($self->o('pipeline_dir'), '#species#', 'pre_exonerate_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'CreateOFDatabase',
      -module            => 'Bio::EnsEMBL::EGPipeline::Exonerate::CreateOFDatabase',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {},
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'AnalysisFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::Exonerate::AnalysisFactory',
      -max_retry_count   => 0,
      -parameters        => {
                              exonerate_analyses => $self->o('exonerate_analyses'),
                              analysis_name      => $analysis_name,
                              logic_name         => $logic_name,
                              db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'pre_exonerate_bkp.sql.gz'),
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
                              genome_dir  => catdir($self->o('pipeline_dir'), '#species#'),
                              repeat_libs => ['dust', 'repeatmask', 'repeatmask_customlib'],
                              soft_mask   => 1,
                            },
      -rc_name           => 'normal',
      -flow_into         => ['GenomeIndexPart1'],
    },

    {
      -logic_name        => 'GenomeIndexPart1',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 5,
      -batch_size        => 10,
      -parameters        => {
                              cmd => $self->o('fasta2esd_exe').' '.'#genome_file#'.' '.'#genome_file#'.'.esd',
                            },
      -rc_name           => 'normal',
      -flow_into         => ['GenomeIndexPart2'],
    },

    {
      -logic_name        => 'GenomeIndexPart2',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 5,
      -batch_size        => 2,
      -parameters        => {
                              cmd => $self->o('esd2esi_exe').' '.'#genome_file#'.'.esd '.'#genome_file#'.'.esi',
                            },
      -rc_name           => 'normal',
      -flow_into         => ['SplitSeqFileFactory'],
    },

    {
      -logic_name        => 'SplitSeqFileFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::Exonerate::SplitSeqFileFactory',
      -parameters        => {
                              seq_file  => $self->o('seq_file'),
                              seq_files => $self->o('seq_files'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['SplitSeqFile'],
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'SplitSeqFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -parameters        => {
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                              out_dir                 => catdir($self->o('pipeline_dir'), '#species#', 'seqs'),
                            },
      -rc_name           => 'normal',
      -flow_into         => $runnable,
    },

    {
      -logic_name        => 'ExonerateTranscript',
      -module            => 'Bio::EnsEMBL::EGPipeline::Exonerate::ExonerateTranscript',
      -hive_capacity     => $self->o('max_hive_capacity'),
      -max_retry_count   => 1,
      -parameters        => {
                              db_type        => 'otherfeatures',
                              logic_name     => $logic_name,
                              biotype        => $biotype,
                              server_exe     => $self->o('server_exe'),
                              log_file       => $self->o('log_file'),
                              queryfile      => '#genome_file#',
                              index_file     => '#genome_file#'.'.esi',
                              seq_file       => '#split_file#',
                              seq_type       => $self->o('seq_type'),
                              coverage       => $self->o('coverage'),
                              percent_id     => $self->o('percent_id'),
                              best_in_genome => $self->o('best_in_genome'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'ExonerateAlignFeature',
      -module            => 'Bio::EnsEMBL::EGPipeline::Exonerate::ExonerateAlignFeature',
      -hive_capacity     => $self->o('max_hive_capacity'),
      -max_retry_count   => 1,
      -parameters        => {
                              db_type     => 'otherfeatures',
                              logic_name  => $logic_name,
                              server_exe  => $self->o('server_exe'),
                              log_file    => $self->o('log_file'),
                              queryfile   => '#genome_file#',
                              index_file  => '#genome_file#'.'.esi',
                              seq_file    => '#split_file#',
                              seq_type    => $self->o('seq_type'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'PostExonerateBackup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -analysis_capacity => 5,
      -batch_size        => 4,
      -max_retry_count   => 1,
      -parameters        => {
                              db_type     => 'otherfeatures',
                              output_file => catdir($self->o('pipeline_dir'), '#species#', 'post_exonerate_bkp.sql.gz'),
                            },
      -rc_name           => 'normal',
      -flow_into         => $post_dump_flow,
    },

    {
      -logic_name        => 'Deduplicate',
      -module            => 'Bio::EnsEMBL::EGPipeline::Exonerate::Deduplicate',
      -max_retry_count   => 1,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => $dedupe_flow,
    },

    {
      -logic_name        => 'MetaCoords',
      -module            => 'Bio::EnsEMBL::EGPipeline::CoreStatistics::MetaCoords',
      -max_retry_count   => 1,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => ['EmailExonerateReport'],
    },

    {
      -logic_name        => 'EmailExonerateReport',
      -module            => 'Bio::EnsEMBL::EGPipeline::Exonerate::EmailExonerateReport',
      -max_retry_count   => 1,
      -parameters        => {
                              email      => $self->o('email'),
                              subject    => 'Exonerate pipeline: Report for #species#',
                              db_type    => 'otherfeatures',
                              logic_name => $logic_name,
                              seq_file   => $self->o('seq_file'),
                              seq_files  => $self->o('seq_files'),
                              seq_type   => $self->o('seq_type'),
                              no_genes   => $self->o('no_genes'),
                              coverage   => $self->o('coverage'),
                              percent_id => $self->o('percent_id'),
                            },
      -rc_name           => 'normal',
    },

  ];
}

1;
