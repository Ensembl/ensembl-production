=head1 LICENSE

Copyright [2016] EMBL-European Bioinformatics Institute

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
Bio::EnsEMBL::EGPipeline::PipeConfig::AlignmentXref_conf

=head1 DESCRIPTION

Align sequence data in order to generate cross-references (aka identity xrefs).

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::AlignmentXref_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;

  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'alignment_xref_'.$self->o('ensembl_release'),

    species => [],
    antispecies => [],
    division => [],
    run_all => 0,
    meta_filters => {},

    # Parameters for dumping and splitting Fasta query files.
    max_seq_length          => 10000000,
    max_seq_length_per_file => $self->o('max_seq_length'),
    max_seqs_per_file       => 500,
    max_files_per_directory => 100,
    max_dirs_per_directory  => $self->o('max_files_per_directory'),

    max_hive_capacity => 100,

    # By default, create xrefs from both reviewed and unreviewed UniProt sets.
    uniprot_reviewed   => 1,
    uniprot_unreviewed => 1,

    # Can also create xrefs from RefSeq peptides.
    refseq_peptide => 0,

    # Default logic_names for the analyses.
    uniprot_reviewed_logic_name   => 'xref_sprot_blastp',
    uniprot_unreviewed_logic_name => 'xref_trembl_blastp',
    refseq_peptide_logic_name     => 'xref_refseq_blastp',

    # External DB parameters are effectively constant and should not be altered.
    uniprot_reviewed_external_db   => 'Uniprot/SWISSPROT',
    uniprot_unreviewed_external_db => 'Uniprot/SPTREMBL',
    refseq_peptide_external_db     => 'RefSeq_peptide',

    # Align a particular species, rather than one matching the core db species.
    source_species => undef,

    # Parameters for fetching and saving UniProt data.
    uniprot_ebi_path => '/ebi/ftp/pub/databases/uniprot/current_release/knowledgebase',
    uniprot_ftp_uri  => 'ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase',
    uniprot_dir      => catdir($self->o('pipeline_dir'), 'uniprot'),

    # Parameters for fetching and saving RefSeq data.
    refseq_ebi_path  => '/nfs/panda/ensemblgenomes/external/refseq',
    refseq_ftp_uri   => 'ftp://ftp.ncbi.nlm.nih.gov/refseq/release',
    refseq_dir       => catdir($self->o('pipeline_dir'), 'refseq'),
    refseq_tax_level => undef,

    # Blast parameters
    blast_type       => 'ncbi',
    blast_dir        => '/nfs/software/ensembl/RHEL7/linuxbrew/bin',
    makeblastdb_exe  => catdir($self->o('blast_dir'), 'makeblastdb'),
    blastp_exe       => catdir($self->o('blast_dir'), 'blastp'),
    blast_matrix     => undef,
    blast_threads    => 3,
    blast_parameters => '-word_size 3 -num_alignments 100000 -num_descriptions 100000 -lcase_masking -seg yes -num_threads '.$self->o('blast_threads'),

    # For parsing the output.
    output_regex     => '^\s*(\w+)',
    pvalue_threshold => 0.01,
    filter_prune     => 1,
    filter_min_score => 200,

    # Specify blast_db if you don't want it in the directory alongside db_file.
    blast_db => undef,

    # Analyses to associate with the object_xref.
    analyses =>
    [
      {
        'logic_name'    => $self->o('uniprot_reviewed_logic_name'),
        'display_label' => 'UniProt reviewed proteins',
        'description'   => 'Cross references to UniProt Swiss-Prot (reviewed) proteins, determined by alignment against the proteome with <em>blastp</em>.',
        'displayable'   => 1,
        'db'            => 'sprot',
        'program'       => 'blastp',
        'program_file'  => $self->o('blastp_exe'),
        'parameters'    => $self->o('blast_parameters'),
        'module'        => 'Bio::EnsEMBL::Analysis::Runnable::BlastEG',
        'db_type'       => 'core',
      },

      {
        'logic_name'    => $self->o('uniprot_unreviewed_logic_name'),
        'display_label' => 'UniProt unreviewed proteins',
        'description'   => 'Cross references to UniProt TrEMBL (unreviewed) proteins, determined by alignment against the proteome with <em>blastp</em>.',
        'displayable'   => 1,
        'db'            => 'trembl',
        'program'       => 'blastp',
        'program_file'  => $self->o('blastp_exe'),
        'parameters'    => $self->o('blast_parameters'),
        'module'        => 'Bio::EnsEMBL::Analysis::Runnable::BlastEG',
        'db_type'       => 'core',
      },

      {
        'logic_name'    => $self->o('refseq_peptide_logic_name'),
        'display_label' => 'RefSeq peptides',
        'description'   => 'Cross references to RefSeq peptide sequences, determined by alignment against the proteome with <em>blastp</em>.',
        'displayable'   => 1,
        'db'            => 'refseq_peptide',
        'program'       => 'blastp',
        'program_file'  => $self->o('blastp_exe'),
        'parameters'    => $self->o('blast_parameters'),
        'module'        => 'Bio::EnsEMBL::Analysis::Runnable::BlastEG',
        'db_type'       => 'core',
      },
    ],

    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,
  }

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
    $self->db_cmd("CREATE TABLE split_proteome (species varchar(100) NOT NULL, split_file varchar(255) NOT NULL)"),
  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    'uniprot_reviewed'   => $self->o('uniprot_reviewed'),
    'uniprot_unreviewed' => $self->o('uniprot_unreviewed'),
    'refseq_peptide'     => $self->o('refseq_peptide'),
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name      => 'InitialisePipeline',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -input_ids       => [{}],
      -flow_into       => {
                            '1->A' => ['SpeciesFactoryForDumping'],
                            'A->1' => ['InitialiseAlignment'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'SpeciesFactoryForDumping',
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
      -rc_name         => 'normal-rh7',
      -flow_into       => {
                            '2->A' => ['BackupCoreDatabase'],
                            'A->2' => ['DumpProteome'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'BackupCoreDatabase',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -max_retry_count => 1,
      -parameters      => {
                            output_file => catdir($self->o('pipeline_dir'), '#species#', 'core_bkp.sql.gz'),
                            table_list  => ['analysis', 'analysis_description', 'identity_xref', 'object_xref', 'xref'],
                          },
      -rc_name         => 'normal-rh7',
    },

    {
      -logic_name        => 'DumpProteome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DumpProteome',
      -analysis_capacity => 5,
      -parameters        => {
                              proteome_dir => catdir($self->o('pipeline_dir'), '#species#', 'proteome'),
                              use_dbID     => 1,
                            },
      -rc_name           => 'normal-rh7',
      -flow_into         => ['SplitProteome'],
    },

    {
      -logic_name        => 'SplitProteome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FastaSplit',
      -analysis_capacity => 5,
      -parameters        => {
                              fasta_file              => '#proteome_file#',
                              max_seq_length_per_file => $self->o('max_seq_length_per_file'),
                              max_seqs_per_file       => $self->o('max_seqs_per_file'),
                              max_files_per_directory => $self->o('max_files_per_directory'),
                              max_dirs_per_directory  => $self->o('max_dirs_per_directory'),
                            },
      -rc_name           => 'normal-rh7',
      -flow_into         => {
                              '2' => [ '?table_name=split_proteome' ],
                            }
    },

    {
      -logic_name      => 'InitialiseAlignment',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -flow_into       => [
                            WHEN('#uniprot_reviewed#'   => ['FetchUniprotReviewed']),
                            WHEN('#uniprot_unreviewed#' => ['FetchUniprotUnreviewed']),
                            WHEN('#refseq_peptide#'     => ['FetchRefSeqPeptide']),
                          ],
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'FetchUniprotReviewed',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::FetchUniprot',
      -max_retry_count => 2,
      -parameters      => {
                            ebi_path     => $self->o('uniprot_ebi_path'),
                            ftp_uri      => $self->o('uniprot_ftp_uri'),
                            data_source  => 'sprot',
                            out_dir      => $self->o('uniprot_dir'),
                            file_varname => 'fasta_file',
                          },
      -rc_name         => 'normal-rh7',
      -flow_into       => ['ConfigureUniprotReviewed'],
    },

    {
      -logic_name      => 'ConfigureUniprotReviewed',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::ConfigureSource',
      -max_retry_count => 1,
      -parameters      => {
                            logic_name  => $self->o('uniprot_reviewed_logic_name'),
                            external_db => $self->o('uniprot_reviewed_external_db'),
                          },
      -rc_name         => 'normal-rh7',
      -flow_into       => ['SpeciesFactoryForLoading'],
    },

    {
      -logic_name      => 'FetchUniprotUnreviewed',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::FetchUniprot',
      -max_retry_count => 2,
      -parameters      => {
                            ebi_path     => $self->o('uniprot_ebi_path'),
                            ftp_uri      => $self->o('uniprot_ftp_uri'),
                            data_source  => 'trembl',
                            out_dir      => $self->o('uniprot_dir'),
                            file_varname => 'fasta_file',
                          },
      -rc_name         => '32Gb_mem_4Gb_tmp-rh7',
      -flow_into       => ['ConfigureUniprotUnreviewed'],
    },

    {
      -logic_name      => 'ConfigureUniprotUnreviewed',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::ConfigureSource',
      -max_retry_count => 1,
      -parameters      => {
                            logic_name  => $self->o('uniprot_unreviewed_logic_name'),
                            external_db => $self->o('uniprot_unreviewed_external_db'),
                          },
      -rc_name         => 'normal-rh7',
      -flow_into       => ['SpeciesFactoryForLoading'],
    },

    {
      -logic_name      => 'FetchRefSeqPeptide',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::FetchRefSeq',
      -max_retry_count => 2,
      -parameters      => {
                            ebi_path        => $self->o('refseq_ebi_path'),
                            ftp_uri         => $self->o('refseq_ftp_uri'),
                            taxonomic_level => $self->o('refseq_tax_level'),
                            data_type       => 'protein',
                            out_dir         => $self->o('refseq_dir'),
                            file_varname    => 'fasta_file',
                          },
      -rc_name         => '32Gb_mem_4Gb_tmp-rh7',
      -flow_into       => ['ConfigureRefSeqPeptide'],
    },

    {
      -logic_name      => 'ConfigureRefSeqPeptide',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::ConfigureSource',
      -max_retry_count => 1,
      -parameters      => {
                            logic_name  => $self->o('refseq_peptide_logic_name'),
                            external_db => $self->o('refseq_peptide_external_db'),
                          },
      -rc_name         => 'normal-rh7',
      -flow_into       => ['SpeciesFactoryForLoading'],
    },

    {
      -logic_name      => 'SpeciesFactoryForLoading',
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
      -flow_into       => {
                            '2->A' => ['AnalysisSetupFactory'],
                            'A->2' => ['ExtractSpeciesFactory'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'AnalysisSetupFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::AnalysisSetupFactory',
      -max_retry_count => 1,
      -parameters      => {
                            analyses => $self->o('analyses'),
                          },
      -meadow_type     => 'LOCAL',
      -flow_into       => {
                            '2' => ['AnalysisSetup'],
                          },
    },

    {
      -logic_name      => 'AnalysisSetup',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count => 0,
      -batch_size      => 10,
      -parameters      => {
                            db_backup_required => 1,
                            db_backup_file     => catdir($self->o('pipeline_dir'), '#species#', 'core_bkp.sql.gz'),
                            delete_existing    => 1,
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                          },
      -meadow_type     => 'LOCAL',
      -flow_into       => ['DeleteIdentityXrefs'],
    },

    {
      -logic_name      => 'DeleteIdentityXrefs',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::SqlCmd',
      -max_retry_count => 0,
      -parameters      => {
                            sql => [
                              'DELETE ox.*, ix.* FROM '.
                                'object_xref ox INNER JOIN '.
                                'identity_xref ix USING (object_xref_id) INNER JOIN '.
                                'xref x USING (xref_id) INNER JOIN '.
                                'external_db edb USING (external_db_id) '.
                              'WHERE edb.db_name = "#external_db#"',]
                          },
      -rc_name         => 'normal-rh7',
    },

    {
      -logic_name      => 'ExtractSpeciesFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::ExtractSpeciesFactory',
      -max_retry_count => 0,
      -flow_into       => {
                            '2' => ['ExtractSpeciesUniprot'],
                            '3' => ['ExtractSpeciesRefSeq'],
                          },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'ExtractSpeciesUniprot',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::ExtractSpeciesUniprot',
      -max_retry_count => 1,
      -parameters      => {
                            source_species => $self->o('source_species'),
                            file_varname   => 'db_fasta_file',
                          },
      -rc_name         => 'normal-rh7',
      -flow_into       => ['CreateBlastDB'],
    },

    {
      -logic_name      => 'ExtractSpeciesRefSeq',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::ExtractSpeciesRefSeq',
      -max_retry_count => 1,
      -parameters      => {
                            source_species => $self->o('source_species'),
                            file_varname   => 'db_fasta_file',
                          },
      -rc_name         => 'normal-rh7',
      -flow_into       => ['CreateBlastDB'],
    },

    {
      -logic_name      => 'CreateBlastDB',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::CreateBlastDB',
      -max_retry_count => 2,
      -parameters      => {
                            makeblastdb_exe   => $self->o('makeblastdb_exe'),
                            blast_db          => $self->o('blast_db'),
                            blast_db_type     => 'prot',
                            proteome_source   => 'various',
                            logic_name_prefix => 'various',
                          },
      -rc_name         => 'normal-rh7',
      -flow_into       => ['FetchProteomeFiles'],
    },

    {
      -logic_name      => 'FetchProteomeFiles',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::FetchSplitFiles',
      -max_retry_count => 1,
      -parameters      => {
                            seq_type => 'proteome',
                          },
      -rc_name         => 'normal-rh7',
      -flow_into       => {
                            '2->A' => ['BlastPFactory'],
                            'A->1' => ['FilterBlastPHits'],
                          },
    },

    {
      -logic_name      => 'BlastPFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::BlastFactory',
      -max_retry_count => 1,
      -parameters      => {
                            max_seq_length => $self->o('max_seq_length'),
                            queryfile      => '#split_file#',
                          },
      -rc_name         => 'normal-rh7',
      -flow_into       => {
                            '2' => ['BlastP'],
                          },
    },

    {
      -logic_name      => 'BlastP',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::Blast',
      -hive_capacity   => $self->o('max_hive_capacity'),
      -max_retry_count => 1,
      -parameters      => {
                            db_type          => 'core',
                            blast_type       => $self->o('blast_type'),
                            blast_matrix     => $self->o('blast_matrix'),
                            output_regex     => $self->o('output_regex'),
                            query_type       => 'pep',
                            database_type    => 'pep',
                            pvalue_threshold => $self->o('pvalue_threshold'),
                            filter_prune     => $self->o('filter_prune'),
                            filter_min_score => $self->o('filter_min_score'),
                            escape_branch    => -1,
                          },
      -rc_name         => '8GB_threads-rh7',
      -flow_into       => {
                            '-1' => ['BlastP_HighMem'],
                          },
    },

    {
      -logic_name      => 'BlastP_HighMem',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::Blast',
      -hive_capacity   => $self->o('max_hive_capacity'),
      -max_retry_count => 1,
      -parameters      => {
                            db_type          => 'core',
                            blast_type       => $self->o('blast_type'),
                            blast_matrix     => $self->o('blast_matrix'),
                            output_regex     => $self->o('output_regex'),
                            query_type       => 'pep',
                            database_type    => 'pep',
                            pvalue_threshold => $self->o('pvalue_threshold'),
                            filter_prune     => $self->o('filter_prune'),
                            filter_min_score => $self->o('filter_min_score'),
                            escape_branch    => -1,
                          },
      -rc_name         => '16GB_threads-rh7',
      -flow_into       => {
                            '-1' => ['BlastP_HigherMem'],
                          },
    },

    {
      -logic_name      => 'BlastP_HigherMem',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::Blast',
      -hive_capacity   => $self->o('max_hive_capacity'),
      -max_retry_count => 1,
      -parameters      => {
                            db_type          => 'core',
                            blast_type       => $self->o('blast_type'),
                            blast_matrix     => $self->o('blast_matrix'),
                            output_regex     => $self->o('output_regex'),
                            query_type       => 'pep',
                            database_type    => 'pep',
                            pvalue_threshold => $self->o('pvalue_threshold'),
                            filter_prune     => $self->o('filter_prune'),
                            filter_min_score => $self->o('filter_min_score'),
                          },
      -rc_name         => '32GB_threads-rh7',
    },

    {
      -logic_name      => 'FilterBlastPHits',
      -module          => 'Bio::EnsEMBL::EGPipeline::BlastAlignment::FilterHits',
      -max_retry_count => 1,
      -parameters      => {
                            db_type     => 'core',
                            filter_top_x => 1,
                            blastp_top_x => 1,
                          },
      -rc_name         => 'normal-rh7',
      -flow_into       => ['LoadAlignmentXref'],
    },

    {
      -logic_name        => 'LoadAlignmentXref',
      -module            => 'Bio::EnsEMBL::EGPipeline::Xref::LoadAlignmentXref',
      -max_retry_count   => 1,
      -parameters        => {
                              fasta_file => '#db_fasta_file#',
                            },
      -rc_name           => 'normal-rh7',
      -flow_into         => ['EmailReport'],

    },

    {
      -logic_name        => 'EmailReport',
      -module            => 'Bio::EnsEMBL::EGPipeline::Xref::EmailAlignmentXrefReport',
      -max_retry_count   => 1,
      -parameters        => {
                              email   => $self->o('email'),
                              subject => 'Alignment Xref pipeline has completed for #species# with #external_db#',
                            },
      -rc_name           => 'normal-rh7',
    },
  ];
}

sub resource_classes {
  my ($self) = @_;

  my $blast_threads = $self->o('blast_threads');

  return {
    %{$self->SUPER::resource_classes},
    '8GB_threads-rh7' => {'LSF' => '-q production-rh7 -n ' . ($blast_threads + 1) . ' -M 8000 -R "rusage[mem=8000,tmp=8000]"'},
    '16GB_threads-rh7' => {'LSF' => '-q production-rh7 -n ' . ($blast_threads + 1) . ' -M 16000 -R "rusage[mem=16000,tmp=16000]"'},
    '32GB_threads-rh7' => {'LSF' => '-q production-rh7 -n ' . ($blast_threads + 1) . ' -M 32000 -R "rusage[mem=32000,tmp=32000]"'},
  }
}

1;
