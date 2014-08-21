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

Bio::EnsEMBL::EGPipeline::PipeConfig::ProteinSimilarity_conf

=head1 DESCRIPTION

Configuration for running the Protein Similarity pipeline, which
BLASTs data for a given set of species against UniProt or a set
of core databases.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::ProteinSimilarity_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my $self = shift @_;
  return {
    %{$self->SUPER::default_options},
    
    pipeline_name => 'protein_similarity_'.$self->o('ensembl_release'),
    
    species      => [],
    antispecies  => [],
    division     => [],
    run_all      => 0,
    
    # Parameters for dumping and splitting Fasta query files.
    max_seq_length_per_file => 1000000,
    max_seqs_per_file       => undef,
    max_files_per_directory => 100,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),
    
    max_hive_capacity => 25,
    
    # Taxonomic level is one of 'fungi', 'invertebrates', 'plants';
    # the UniProt source can be 'sprot' or 'trembl'.
    uniprot_ftp_uri  => 'ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/taxonomic_divisions',
    taxonomic_level  => 'invertebrates',
    uniprot_source   => 'sprot',
    taxonomic_levels => [$self->o('taxonomic_level')],
    uniprot_sources  => [$self->o('uniprot_source')],
    uniprot_dir      => catdir($self->o('pipeline_dir'), 'uniprot'),
    
    # Default is to use ncbi-blast; wu-blast is possible, for backwards
    # compatability, but it is now unsupported and orders of magnitude
    # slower than ncbi-blast. Setting BLASTMAT is irrelevant for ncbi-blast,
    # but the Ensembl code requires it to be set as an environment variable,
    # pointing to a directory that exists (for now - I will email Ensembl).
    blast_type       => 'ncbi',
    blast_dir        => '/nfs/panda/ensemblgenomes/external/ncbi-blast-2+',
    makeblastdb_exe  => catdir($self->o('blast_dir'), 'bin/makeblastdb'),
    blastp_exe       => catdir($self->o('blast_dir'), 'bin/blastp'),
    blastx_exe       => catdir($self->o('blast_dir'), 'bin/blastx'),
    blast_matrix     => undef,
    blast_parameters => '-word_size 3 -num_alignments 100000 -num_descriptions 100000 -lcase_masking -seg yes',
    
    # For wu-blast, set the following  parameters instead of the above.
    # blast_type       => 'wu',
    # blast_dir        => '/nfs/panda/ensemblgenomes/external/wublast',
    # makeblastdb_exe  => catdir($self->o('blast_dir'), 'wu-formatdb'),
    # blastp_exe       => catdir($self->o('blast_dir'), 'blastp'),
    # blastx_exe       => catdir($self->o('blast_dir'), 'blastx'),
    # blast_matrix     => catdir($self->o('blast_dir'), 'matrix'),
    # blast_parameters => '-W 3 -B 100000 -V 100000 -hspmax=0 -lcmask -wordmask=seg',
    
    # For parsing the output; these values shouldn't need to be changed.
    output_regex     => '^\s*(\w+)',
    pvalue_threshold => 0.01,
    
    # By default, run against a UniProt database; and do both blastp and blastx.
    # Specify blast_db if you don't want it in the directory alongside db_file.
    db       => 'UniProt',
    db_file  => 'uniprot_'.$self->o('uniprot_source').'_'.$self->o('taxonomic_level').'.dat.gz',
    blast_db => undef,
    blastp   => 1,
    blastx   => 1,
    
    analyses =>
    [
      {
        'logic_name'    => $self->o('db').'_blastp',
        'display_label' => $self->o('db').' Proteins',
        'description'   => $self->o('db').' proteins aligned with BLAST-P',
        'program'       => 'blastp',
        'program_file'  => $self->o('blastp_exe'),
        'parameters'    => $self->o('blast_parameters'),
        'db'            => $self->o('db'),
        'db_file'       => $self->o('db_file'),
        'module'        => 'Bio::EnsEMBL::Analysis::Runnable::BlastEG',
        'linked_tables' => ['protein_feature'],
        'db_type'       => 'core',
      },
      
      {                 
        'logic_name'    => $self->o('db').'_blastx',
        'display_label' => $self->o('db').' Proteins',
        'description'   => $self->o('db').' proteins aligned with BLAST-X',
        'program'       => 'blastx',
        'program_file'  => $self->o('blastx_exe'),
        'parameters'    => $self->o('blast_parameters'),
        'db'            => $self->o('db'),
        'db_file'       => $self->o('db_file'),
        'module'        => 'Bio::EnsEMBL::Analysis::Runnable::BlastEG',
        'linked_tables' => ['protein_align_feature'],
        'db_type'       => 'otherfeatures',
      },
      
    ],

    # Remove existing *_align_features; if => 0 then existing analyses
    # and their features will remain, with the logic_name suffixed by '_bkp'.
    delete_existing => 1,

    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 0,

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

sub pipeline_analyses {
  my $self = shift @_;
  
  my $lc_db = lc($self->o('db'));
  
  my $inital_flow;
  if ($lc_db eq 'uniprot') {
    $inital_flow = ['FetchUniprot'];
  } else {
    $inital_flow = ['FetchFile'];
  }
  
  my $dump_flow = [];
  if ($self->o('blastp')) {
    push @$dump_flow, 'DumpProteome';
  }
  if ($self->o('blastx')) {
    push @$dump_flow, 'DumpGenome';
  }
  
  return [
    {
      -logic_name      => 'ProteinSimilarity',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -input_ids       => [{}],
      -flow_into       => $inital_flow,
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'FetchFile',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -can_be_empty    => 1,
      -max_retry_count => 0,
      -parameters      => {
                            db_fasta_file => $self->o('db_file'),
                          },
      -flow_into       => ['CreateBlastDB'],
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'FetchUniprot',
      -module          => 'Bio::EnsEMBL::EGPipeline::ProteinSimilarity::FetchUniprot',
      -can_be_empty    => 1,
      -max_retry_count => 2,
      -parameters      => {
                            ftp_uri          => $self->o('uniprot_ftp_uri'),
                            taxonomic_levels => $self->o('taxonomic_levels'),
                            uniprot_sources  => $self->o('uniprot_sources'),
                            out_dir          => $self->o('uniprot_dir'),
                          },
      -rc_name         => 'normal',
      -flow_into       => ['CreateBlastDB'],
    },

    {
      -logic_name      => 'CreateBlastDB',
      -module          => 'Bio::EnsEMBL::EGPipeline::ProteinSimilarity::CreateBlastDB',
      -max_retry_count => 2,
      -parameters      => {
                            makeblastdb_exe => $self->o('makeblastdb_exe'),
                            blast_db_type   => 'prot',
                          },
      -rc_name         => 'normal',
      -flow_into       => ['SpeciesFactory'],
    },

    {
      -logic_name      => 'SpeciesFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -max_retry_count => 1,
      -parameters      => {
                            species     => $self->o('species'),
                            antispecies => $self->o('antispecies'),
                            division    => $self->o('division'),
                            run_all     => $self->o('run_all'),
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2' => ['BackupDatabase'],
                          },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name      => 'BackupDatabase',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -max_retry_count => 1,
      -parameters      => {
                            output_file => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '1->A' => ['AnalysisFactory'],
                            'A->1' => ['DumpData'],
                          },
    },

    {
      -logic_name      => 'AnalysisFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::ProteinSimilarity::AnalysisFactory',
      -max_retry_count => 0,
      -batch_size      => 10,
      -parameters      => {
                            analyses => $self->o('analyses'),
                            db       => $lc_db,
                            blastp   => $self->o('blastp'),
                            blastx   => $self->o('blastx'),
                          },
      -rc_name         => 'normal',
      -flow_into       => ['AnalysisSetup'],
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'AnalysisSetup',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count => 0,
      -batch_size      => 10,
      -parameters      => {
                            db_backup_required => 1,
                            db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'pre_pipeline_bkp.sql.gz'),
                            delete_existing    => $self->o('delete_existing'),
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'DumpData',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -parameters      => {},
      -flow_into       => $dump_flow,
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name        => 'DumpProteome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DumpProteome',
      -can_be_empty      => 1,
      -analysis_capacity => 5,
      -parameters        => {
                              proteome_dir => catdir($self->o('pipeline_dir'), '#species#', 'proteome'),
                              use_dbID     => 1,
                            },
      -rc_name           => 'normal',
      -flow_into         => ['SplitProteome'],
    },

    {
      -logic_name        => 'DumpGenome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DumpGenome',
      -can_be_empty      => 1,
      -analysis_capacity => 5,
      -parameters        => {
                              genome_dir => catdir($self->o('pipeline_dir'), '#species#', 'genome'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['SplitGenome'],
    },

    {
      -logic_name        => 'SplitProteome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
      -can_be_empty      => 1,
      -analysis_capacity => 5,
      -parameters        => {
                              fasta_file              => '#proteome_file#',
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['BlastP'],
    },

    {
      -logic_name        => 'SplitGenome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
      -can_be_empty      => 1,
      -analysis_capacity => 5,
      -parameters        => {
                              fasta_file              => '#genome_file#',
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['BlastX'],
    },

    {
      -logic_name      => 'BlastP',
      -module          => 'Bio::EnsEMBL::EGPipeline::ProteinSimilarity::Blast',
      -can_be_empty    => 1,
      -hive_capacity   => $self->o('max_hive_capacity'),
      -max_retry_count => 1,
      -parameters      => {
                            db_type          => 'core',
                            logic_name       => $lc_db.'_blastp',
                            queryfile        => '#split_file#',
                            blast_type       => $self->o('blast_type'),
                            blast_matrix     => $self->o('blast_matrix'),
                            output_regex     => $self->o('output_regex'),
                            query_type       => 'pep',
                            database_type    => 'pep',
                            pvalue_threshold => $self->o('pvalue_threshold'),
                          },
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'BlastX',
      -module          => 'Bio::EnsEMBL::EGPipeline::ProteinSimilarity::Blast',
      -can_be_empty    => 1,
      -hive_capacity   => $self->o('max_hive_capacity'),
      -max_retry_count => 1,
      -parameters      => {
                            db_type          => 'otherfeatures',
                            logic_name       => $lc_db.'_blastx',
                            queryfile        => '#split_file#',
                            blast_type       => $self->o('blast_type'),
                            blast_matrix     => $self->o('blast_matrix'),
                            output_regex     => $self->o('output_regex'),
                            query_type       => 'dna',
                            database_type    => 'pep',
                            pvalue_threshold => $self->o('pvalue_threshold'),
                          },
      -rc_name         => 'normal',
    },

  ];
}

1;
