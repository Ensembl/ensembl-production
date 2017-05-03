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

Bio::EnsEMBL::EGPipeline::PipeConfig::BlastProtein_conf

=head1 DESCRIPTION

Align amino acids sequences against a set of core databases.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::BlastProtein_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

use File::Spec::Functions qw(catdir);

sub default_options {
  my $self = shift @_;
  return {
    %{$self->SUPER::default_options},
    
    pipeline_name => 'blast_protein_'.$self->o('ensembl_release'),
    
    species      => [],
    antispecies  => [],
    division     => [],
    run_all      => 0,
    meta_filters => {},
    
    # Parameters for dumping and splitting Fasta query files.
    max_seq_length          => 10000000,
    max_seq_length_per_file => $self->o('max_seq_length'),
    max_seqs_per_file       => 500,
    max_files_per_directory => 100,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),
    
    max_hive_capacity => 100,
    
    # Source for proteomes can be one of: 'file', 'database', 'uniprot'
    proteome_source    => 'file',
    logic_name_prefix  => $self->o('proteome_source'),
    source_label       => 'Protein alignments',
    is_canonical       => 1,
    
    # This parameter should only be specified if proteome_source = 'file'
    db_fasta_file => undef,
    
    # Dump the proteomes of other species and align them.
    source_species      => [],
    source_antispecies  => [],
    source_division     => [],
    source_run_all      => 0,
    source_meta_filters => {},
    
    # Taxonomic level is one of 'fungi', 'invertebrates', 'plants';
    # the UniProt source can be 'sprot' or 'trembl'.
    uniprot_ebi_path  => '/ebi/ftp/pub/databases/uniprot/current_release/knowledgebase',
    uniprot_ftp_uri   => 'ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase',
    uniprot_tax_level => undef,
    uniprot_source    => 'sprot',
    uniprot_dir       => catdir($self->o('pipeline_dir'), 'uniprot'),
    
    blast_dir        => '/nfs/software/ensembl/RHEL7/linuxbrew',
    makeblastdb_exe  => catdir($self->o('blast_dir'), 'bin/makeblastdb'),
    blastp_exe       => catdir($self->o('blast_dir'), 'bin/blastp'),
    blastx_exe       => catdir($self->o('blast_dir'), 'bin/blastx'),
    blast_threads    => 3,
    blast_parameters => '-word_size 3 -num_alignments 100000 -num_descriptions 100000 -lcase_masking -seg yes -num_threads '.$self->o('blast_threads'),
    
    # For parsing the output.
    output_regex     => '^\s*(\w+)',
    pvalue_threshold => 0.01,
    filter_prune     => 1,
    filter_min_score => 200,
    
    # By default, do both blastp and blastx.
    # Specify blast_db if you don't want it in the directory alongside db_file.
    blast_db => undef,
    blastp   => 1,
    blastx   => 1,
    
    # Filter so that only best X hits get saved.
    blastp_top_x => 1,
    blastx_top_x => 10,
    
    # blastx results go in an otherfeatures db by default.
    blastx_db_type => 'otherfeatures',
    
    # Generate a GFF file for loading into, e.g., WebApollo
    create_gff    => 0,
    gt_exe        => 'gt',
    gff3_tidy     => $self->o('gt_exe').' gff3 -tidy -sort -retainids',
    gff3_validate => $self->o('gt_exe').' gff3validator',
    gff_source    => undef,
    
    analyses =>
    [
      {
        'logic_name'    => 'blastp',
        'display_label' => $self->o('source_label'),
        'description'   => 'Peptide sequences aligned to the proteome with <em>blastp</em>.',
        'displayable'   => 1,
        'web_data'      => '{"type" => "protein"}',
        'db'            => $self->o('proteome_source'),
        'program'       => 'blastp',
        'program_file'  => $self->o('blastp_exe'),
        'parameters'    => $self->o('blast_parameters'),
        'module'        => 'Bio::EnsEMBL::Analysis::Runnable::BlastEG',
        'gff_source'    => $self->o('gff_source'),
        'linked_tables' => ['protein_feature'],
        'db_type'       => 'core',
      },
      
      {                 
        'logic_name'    => 'blastx',
        'display_label' => $self->o('source_label'),
        'description'   => 'Peptide sequences aligned to the genome with <em>blastx</em>.',
        'displayable'   => 1,
        'web_data'      => '{"type" => "protein"}',
        'db'            => $self->o('proteome_source'),
        'program'       => 'blastx',
        'program_file'  => $self->o('blastx_exe'),
        'parameters'    => $self->o('blast_parameters'),
        'module'        => 'Bio::EnsEMBL::Analysis::Runnable::BlastEG',
        'gff_source'    => $self->o('gff_source'),
        'linked_tables' => ['protein_align_feature'],
        'db_type'       => $self->o('blastx_db_type'),
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
    'mkdir -p '.$self->o('pipeline_dir'),
    $self->db_cmd("CREATE TABLE split_genome (species varchar(100) NOT NULL, split_file varchar(255) NOT NULL)"),
    $self->db_cmd("CREATE TABLE split_proteome (species varchar(100) NOT NULL, split_file varchar(255) NOT NULL)"),
  ];
}

sub pipeline_wide_parameters {
 my ($self) = @_;
 
 return {
   %{$self->SUPER::pipeline_wide_parameters},
   'blastp'         => $self->o('blastp'),
   'blastx'         => $self->o('blastx'),
   'blastx_db_type' => $self->o('blastx_db_type'),
   'uniprot_source' => $self->o('uniprot_source'),
 };
}

sub pipeline_analyses {
  my $self = shift @_;
  
  return [
    {
      -logic_name      => 'InitialisePipeline',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -input_ids       => [{}],
      -flow_into       => {
                            '1->A' => ['SpeciesFactory'],
                            'A->1' => ['BlastProtein'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'SpeciesFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -max_retry_count => 1,
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
      -rc_name         => 'normal',
      -flow_into       => {
                            '2' => ['TargetDatabase'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'TargetDatabase',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -parameters      => {},
      -rc_name         => 'normal',
      -flow_into       => WHEN(
                            '#blastp#' => ['DumpProteome'],
                            '#blastx#' => ['DumpGenome'],
                            '#blastp# || (#blastx# && #blastx_db_type# eq "core")' => ['BackupCoreDatabase'],
                            '#blastx# && #blastx_db_type# eq "otherfeatures"' => ['CheckOFDatabase'],
                          ),
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'BackupCoreDatabase',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -can_be_empty      => 1,
      -max_retry_count => 1,
      -parameters      => {
                            output_file => catdir($self->o('pipeline_dir'), '#species#', 'core_bkp.sql.gz'),
                          },
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'CheckOFDatabase',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::CheckOFDatabase',
      -can_be_empty    => 1,
      -max_retry_count => 1,
      -parameters      => {},
      -rc_name         => 'normal',
      -flow_into       => {
                            '2' => ['BackupOFDatabase'],
                            '3' => ['CreateOFDatabase'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'BackupOFDatabase',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -can_be_empty    => 1,
      -max_retry_count => 1,
      -parameters      => {
                            db_type     => 'otherfeatures',
                            output_file => catdir($self->o('pipeline_dir'), '#species#', 'otherfeatures_bkp.sql.gz'),
                          },
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'CreateOFDatabase',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::CreateOFDatabase',
      -can_be_empty    => 1,
      -max_retry_count => 1,
      -parameters      => {},
      -rc_name         => 'normal',
      -flow_into       => ['BackupOFDatabase'],
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
      -flow_into         => {
                              '2' => [ '?table_name=split_proteome' ],
                            }
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
      -flow_into         => {
                              '2' => [ '?table_name=split_genome' ],
                            }
    },

    {
      -logic_name      => 'BlastProtein',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::BlastProtein',
      -max_retry_count => 0,
      -parameters      => {
                            proteome_source => $self->o('proteome_source'),
                            db_fasta_file   => $self->o('db_fasta_file'),
                          },
      -flow_into       => {
                            '2' => ['FetchFile'],
                            '3' => ['SourceSpeciesFactory'],
                            '4' => WHEN('#uniprot_source# eq "sprot"' =>
                                      ['FetchUniprot'],
                                     ELSE
                                      ['FetchUniprot_HighMem']),
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'FetchFile',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -can_be_empty    => 1,
      -max_retry_count => 0,
      -flow_into       => ['CreateBlastDB'],
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'SourceSpeciesFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -can_be_empty    => 1,
      -max_retry_count => 1,
      -parameters      => {
                            species         => $self->o('source_species'),
                            antispecies     => $self->o('source_antispecies'),
                            division        => $self->o('source_division'),
                            run_all         => $self->o('source_run_all'),
                            meta_filters    => $self->o('source_meta_filters'),
                            chromosome_flow => 0,
                            variation_flow  => 0,
                            species_varname => 'source_species',
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2' => ['FetchDatabase'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name        => 'FetchDatabase',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DumpProteome',
      -can_be_empty      => 1,
      -analysis_capacity => 5,
      -parameters        => {
                              species      => '#source_species#',
                              proteome_dir => catdir($self->o('pipeline_dir'), 'proteomes'),
                              is_canonical => $self->o('is_canonical'),
                              file_varname => 'db_fasta_file',
                            },
      -rc_name           => 'normal',
      -flow_into         => ['CreateBlastDB'],
    },

    {
      -logic_name      => 'FetchUniprot',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::FetchUniprot',
      -can_be_empty    => 1,
      -max_retry_count => 2,
      -parameters      => {
                            ebi_path        => $self->o('uniprot_ebi_path'),
                            ftp_uri         => $self->o('uniprot_ftp_uri'),
                            taxonomic_level => $self->o('uniprot_tax_level'),
                            data_source     => $self->o('uniprot_source'),
                            out_dir         => $self->o('uniprot_dir'),
                            file_varname    => 'db_fasta_file',
                          },
      -rc_name         => 'normal',
      -flow_into       => ['CreateBlastDB'],
    },

    {
      -logic_name      => 'FetchUniprot_HighMem',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::FetchUniprot',
      -can_be_empty    => 1,
      -max_retry_count => 2,
      -parameters      => {
                            ebi_path        => $self->o('uniprot_ebi_path'),
                            ftp_uri         => $self->o('uniprot_ftp_uri'),
                            taxonomic_level => $self->o('uniprot_tax_level'),
                            data_source     => $self->o('uniprot_source'),
                            out_dir         => $self->o('uniprot_dir'),
                            file_varname    => 'db_fasta_file',
                          },
      -rc_name         => '32Gb_mem_4Gb_tmp',
      -flow_into       => ['CreateBlastDB'],
    },

    {
      -logic_name      => 'CreateBlastDB',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::CreateBlastDB',
      -max_retry_count => 2,
      -parameters      => {
                            makeblastdb_exe   => $self->o('makeblastdb_exe'),
                            blast_db          => $self->o('blast_db'),
                            database_type     => 'pep',
                            proteome_source   => $self->o('proteome_source'),
                            logic_name_prefix => $self->o('logic_name_prefix'),
                          },
      -rc_name         => 'normal',
      -flow_into       => ['TargetSpeciesFactory'],
    },

    {
      -logic_name      => 'TargetSpeciesFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -max_retry_count => 1,
      -parameters      => {
                            species         => $self->o('species'),
                            antispecies     => $self->o('antispecies'),
                            division        => $self->o('division'),
                            run_all         => $self->o('run_all'),
                            meta_filters    => $self->o('meta_filters'),
                            chromosome_flow => 0,
                            variation_flow  => 0,
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2' => ['AnalysisFactory'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'AnalysisFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::AnalysisFactory',
      -max_retry_count => 0,
      -batch_size      => 10,
      -parameters      => {
                            analyses     => $self->o('analyses'),
                            blastp       => $self->o('blastp'),
                            blastx       => $self->o('blastx'),
                            blastp_top_x => $self->o('blastp_top_x'),
                            blastx_top_x => $self->o('blastx_top_x'),
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2->A' => ['AnalysisSetupBlastP'],
                            'A->4' => ['FetchProteomeFiles'],
                            '3->B' => ['AnalysisSetupBlastX'],
                            'B->5' => ['FetchGenomeFiles'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'AnalysisSetupBlastP',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -can_be_empty    => 1,
      -max_retry_count => 0,
      -batch_size      => 10,
      -parameters      => {
                            db_backup_required => 1,
                            db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'core_bkp.sql.gz'),
                            delete_existing    => $self->o('delete_existing'),
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'AnalysisSetupBlastX',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -can_be_empty    => 1,
      -max_retry_count => 0,
      -batch_size      => 10,
      -parameters      => {
                            db_type            => $self->o('blastx_db_type'),
                            db_backup_required => 1,
                            db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', '#blastx_db_type#_bkp.sql.gz'),
                            delete_existing    => $self->o('delete_existing'),
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'FetchProteomeFiles',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::FetchSplitFiles',
      -can_be_empty    => 1,
      -max_retry_count => 1,
      -parameters      => {
                            seq_type => 'proteome',
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2->A' => ['BlastPFactory'],
                            'A->1' => ['FilterBlastPHits'],
                          },
    },

    {
      -logic_name      => 'FetchGenomeFiles',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::FetchSplitFiles',
      -can_be_empty    => 1,
      -max_retry_count => 1,
      -parameters      => {
                            seq_type => 'genome',
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2->A' => ['BlastXFactory'],
                            'A->1' => ['FilterBlastXHits'],
                          },
    },

    {
      -logic_name      => 'BlastPFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::BlastFactory',
      -can_be_empty    => 1,
      -max_retry_count => 1,
      -parameters      => {
                            max_seq_length => $self->o('max_seq_length'),
                            queryfile      => '#split_file#',
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2' => ['BlastP'],
                          },
    },

    {
      -logic_name      => 'BlastXFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::BlastFactory',
      -can_be_empty    => 1,
      -hive_capacity   => $self->o('max_hive_capacity'),
      -max_retry_count => 1,
      -parameters      => {
                            max_seq_length => $self->o('max_seq_length'),
                            queryfile      => '#split_file#',
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2' => ['BlastX'],
                          },
    },

    {
      -logic_name      => 'BlastP',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::Blast',
      -can_be_empty    => 1,
      -hive_capacity   => $self->o('max_hive_capacity'),
      -max_retry_count => 1,
      -parameters      => {
                            db_type          => 'core',
                            logic_name       => '#logic_name_prefix#_blastp',
                            query_type       => 'pep',
                            database_type    => 'pep',
                            output_regex     => $self->o('output_regex'),
                            pvalue_threshold => $self->o('pvalue_threshold'),
                            filter_prune     => $self->o('filter_prune'),
                            filter_min_score => $self->o('filter_min_score'),
                            escape_branch    => -1,
                          },
      -rc_name         => '8GB_threads',
      -flow_into       => {
                            '-1' => ['BlastP_HighMem'],
                          },
    },

    {
      -logic_name      => 'BlastP_HighMem',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::Blast',
      -can_be_empty    => 1,
      -hive_capacity   => $self->o('max_hive_capacity'),
      -max_retry_count => 1,
      -parameters      => {
                            db_type          => 'core',
                            logic_name       => '#logic_name_prefix#_blastp',
                            query_type       => 'pep',
                            database_type    => 'pep',
                            output_regex     => $self->o('output_regex'),
                            pvalue_threshold => $self->o('pvalue_threshold'),
                            filter_prune     => $self->o('filter_prune'),
                            filter_min_score => $self->o('filter_min_score'),
                            escape_branch    => -1,
                          },
      -rc_name         => '16GB_threads',
      -flow_into       => {
                            '-1' => ['BlastP_HigherMem'],
                          },
    },

    {
      -logic_name      => 'BlastP_HigherMem',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::Blast',
      -can_be_empty    => 1,
      -hive_capacity   => $self->o('max_hive_capacity'),
      -max_retry_count => 1,
      -parameters      => {
                            db_type          => 'core',
                            logic_name       => '#logic_name_prefix#_blastp',
                            query_type       => 'pep',
                            database_type    => 'pep',
                            output_regex     => $self->o('output_regex'),
                            pvalue_threshold => $self->o('pvalue_threshold'),
                            filter_prune     => $self->o('filter_prune'),
                            filter_min_score => $self->o('filter_min_score'),
                          },
      -rc_name         => '32GB_threads',
    },

    {
      -logic_name      => 'BlastX',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::Blast',
      -can_be_empty    => 1,
      -hive_capacity   => $self->o('max_hive_capacity'),
      -max_retry_count => 1,
      -parameters      => {
                            db_type          => $self->o('blastx_db_type'),
                            logic_name       => '#logic_name_prefix#_blastx',
                            query_type       => 'dna',
                            database_type    => 'pep',
                            output_regex     => $self->o('output_regex'),
                            pvalue_threshold => $self->o('pvalue_threshold'),
                            filter_prune     => $self->o('filter_prune'),
                            filter_min_score => $self->o('filter_min_score'),
                            escape_branch    => -1,
                          },
      -rc_name         => '8GB_threads',
      -flow_into       => {
                            '-1' => ['BlastX_HighMem'],
                          },
    },

    {
      -logic_name      => 'BlastX_HighMem',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::Blast',
      -can_be_empty    => 1,
      -hive_capacity   => $self->o('max_hive_capacity'),
      -max_retry_count => 1,
      -parameters      => {
                            db_type          => $self->o('blastx_db_type'),
                            logic_name       => '#logic_name_prefix#_blastx',
                            query_type       => 'dna',
                            database_type    => 'pep',
                            output_regex     => $self->o('output_regex'),
                            pvalue_threshold => $self->o('pvalue_threshold'),
                            filter_prune     => $self->o('filter_prune'),
                            filter_min_score => $self->o('filter_min_score'),
                            escape_branch    => -1,
                          },
      -rc_name         => '16GB_threads',
      -flow_into       => {
                            '-1' => ['BlastX_HigherMem'],
                          },
    },

    {
      -logic_name      => 'BlastX_HigherMem',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::Blast',
      -can_be_empty    => 1,
      -hive_capacity   => $self->o('max_hive_capacity'),
      -max_retry_count => 1,
      -parameters      => {
                            db_type          => $self->o('blastx_db_type'),
                            logic_name       => '#logic_name_prefix#_blastx',
                            query_type       => 'dna',
                            database_type    => 'pep',
                            output_regex     => $self->o('output_regex'),
                            pvalue_threshold => $self->o('pvalue_threshold'),
                            filter_prune     => $self->o('filter_prune'),
                            filter_min_score => $self->o('filter_min_score'),
                          },
      -rc_name         => '32GB_threads',
    },

    {
      -logic_name      => 'FilterBlastPHits',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::FilterHits',
      -can_be_empty    => 1,
      -max_retry_count => 1,
      -parameters      => {
                            db_type      => 'core',
                            filter_top_x => $self->o('blastp_top_x'),
                            logic_name   => '#logic_name_prefix#_blastp',
                          },
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'FilterBlastXHits',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::FilterHits',
      -can_be_empty    => 1,
      -max_retry_count => 1,
      -parameters      => {
                            db_type      => $self->o('blastx_db_type'),
                            filter_top_x => $self->o('blastx_top_x'),
                            logic_name   => '#logic_name_prefix#_blastx',
                            create_gff   => $self->o('create_gff'),
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2->A' => ['GFF3Dump'],
                            'A->2' => ['JSONDescription'],
                          },
    },

    {
      -logic_name      => 'GFF3Dump',
      -module          => 'Bio::EnsEMBL::EGPipeline::FileDump::GFF3Dumper',
      -can_be_empty    => 1,
      -max_retry_count => 1,
      -parameters      => {
                            db_type            => $self->o('blastx_db_type'),
                            feature_type       => ['ProteinAlignFeature'],
                            include_scaffold   => 0,
                            remove_separators  => 1,
                            join_align_feature => 1,
                            results_dir        => catdir($self->o('pipeline_dir'), '#species#'),
                            out_file_stem      => '#logic_name_prefix#_blastx.gff3',
                          },
      -rc_name         => 'normal',
      -flow_into       => ['GFF3Tidy'],
    },

    {
      -logic_name      => 'GFF3Tidy',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -can_be_empty    => 1,
      -batch_size      => 10,
      -max_retry_count => 0,
      -parameters      => {
                            cmd => $self->o('gff3_tidy').' #out_file# > #out_file#.sorted',
                          },
      -rc_name         => 'normal',
      -flow_into       => ['GFF3Validate'],
    },

    {
      -logic_name      => 'GFF3Validate',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -can_be_empty    => 1,
      -batch_size      => 10,
      -max_retry_count => 0,
      -parameters      => {
                            cmd => 'mv #out_file#.sorted #out_file#; '.
                                   $self->o('gff3_validate').' #out_file#',
                          },
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'JSONDescription',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::JSONDescription',
      -can_be_empty    => 1,
      -batch_size      => 10,
      -max_retry_count => 0,
      -parameters      => {
                            db_type     => $self->o('blastx_db_type'),
                            logic_name  => '#logic_name_prefix#_blastx',
                            results_dir => catdir($self->o('pipeline_dir'), '#species#'),
                          },
      -rc_name         => 'normal',
    },

  ];
}

sub resource_classes {
  my ($self) = @_;
  
  my $blast_threads = $self->o('blast_threads');

  return {
    %{$self->SUPER::resource_classes},
    '8GB_threads' => {'LSF' => '-q production-rh7 -n ' . ($blast_threads + 1) . ' -M 8000 -R "rusage[mem=8000,tmp=8000]"'},
    '16GB_threads' => {'LSF' => '-q production-rh7 -n ' . ($blast_threads + 1) . ' -M 16000 -R "rusage[mem=16000,tmp=16000]"'},
    '32GB_threads' => {'LSF' => '-q production-rh7 -n ' . ($blast_threads + 1) . ' -M 32000 -R "rusage[mem=32000,tmp=32000]"'},
  }
}

1;
