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

Bio::EnsEMBL::EGPipeline::PipeConfig::LoadGFF3_conf

=head1 DESCRIPTION

Load a valid GFF3 file into a core database.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::LoadGFF3_conf;

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
    
    pipeline_name => 'load_gff3_'.$self->o('species'),
    
    gff3_tidy_file => $self->o('gff3_file').'.tidied',
    fasta_file     => catdir($self->o('pipeline_dir'), $self->o('species').'.fa'),
    
    # Attempt to correct transcripts with invalid translations.
    fix_models => 1,
    
    # Where fixes fail, apply seq-edits where possible.
    apply_seq_edits => 1,
    
    # If loading data from NCBI, their homology- and transcriptome-based
    # gene model modifications can be loaded as sequence edits in the db.
    genbank_file => undef,
    
    # Sometimes selenocysteines and readthrough stop codons are only
    # indicated in the provider's protein sequences.
    protein_fasta_file => undef,
    
    # Can also load genes into an otherfeatures db.
    db_type => 'core',
    
    # This logic_name will almost certainly need to be changed, so
    # that a customised description can be associated with the analysis.
    logic_name      => 'gff3_genes',
    analysis_module => 'Bio::EnsEMBL::EGPipeline::LoadGFF3::LoadGFF3',
    
    # When adding seq_region synonyms, an external_db is required.
    # This should ideally be something less generic, e.g. RefSeq_genomic.
    synonym_external_db => 'ensembl_internal_synonym',
    
    # Remove existing genes; if => 0 then existing analyses
    # and their features will remain, with the logic_name suffixed by '_bkp'.
    delete_existing => 1,
    
    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,
    
    # Validate GFF3 before trying to parse it.
    gt_exe        => '/nfs/panda/ensemblgenomes/external/genometools/bin/gt',
    gff3_tidy     => $self->o('gt_exe').' gff3 -tidy -sort -retainids',
    gff3_validate => $self->o('gt_exe').' gff3validator',
    
    # Remove any extra gubbins from the Fasta ID.
    fasta_subst => 's/^(>[^\|]+).*/$1/',
    fasta_tidy  => "perl -i -pe '".$self->o('fasta_subst')."'",
    
    # Lists of the types that we expect to see in the GFF3 file.
    gene_types   => ['gene', 'pseudogene', 'miRNA_gene',
                     'rRNA_gene', 'snoRNA_gene', 'snRNA_gene', 'tRNA_gene' ],
    mrna_types   => ['mRNA', 'transcript', 'pseudogenic_transcript',
                     'pseudogenic_rRNA', 'pseudogenic_tRNA',
                     'ncRNA', 'lincRNA', 'lncRNA', 'miRNA', 'pre_miRNA',
                     'RNAse_P_RNA', 'rRNA', 'snoRNA', 'snRNA', 'sRNA',
                     'SRP_RNA', 'tRNA'],
    exon_types   => ['exon', 'pseudogenic_exon'],
    cds_types    => ['CDS'],
    utr_types    => ['five_prime_UTR', 'three_prime_UTR'],
    ignore_types => ['misc_RNA', 'RNA',
                     'match', 'match_part',
                     'cDNA_match', 'nucleotide_match', 'protein_match',
                     'polypeptide', 'protein',
                     'chromosome', 'supercontig', 'contig',
                     'region', 'biological_region',
                     'regulatory_region', 'repeat_region'],
    
    # By default, it is assumed that the above type lists are exhaustive.
    # If there is a type in the GFF3 that is not listed, an error will be
    # thrown, unless 'types_complete' = 0.
    types_complete => 1,
    
    # By default, load the GFF3 "ID" fields as stable_ids, and ignore "Name"
    # fields. If they exist, can load them as stable IDs instead, with the
    # value 'stable_id'; or load them as xrefs by setting to 'xref'.
    use_name_field => undef,
    
    # When adding "Name" fields as xrefs, external_dbs are required.
    xref_gene_external_db        => undef, # e.g. RefSeq_gene_name
    xref_transcript_external_db  => undef, # e.g. RefSeq_mRNA
    xref_translation_external_db => undef, # e.g. RefSeq_peptide
    
    # If there are polypeptide rows in the GFF3, defined by 'Derives_from'
    # relationships, those will be used to determine the translation
    # (rather than inferring from CDS), unless 'polypeptides' = 0. 
    polypeptides => 1,
    
    # Set the biotype for transcripts that produce invalid translations. We
    # can treat them as pseudogenes by setting 'nontranslating' => "pseudogene".
    # The default is "nontranslating_CDS", and in this case the translation
    # is still added to the core db, on the assumption that remedial action
    # will fix it (i.e. via the ApplySeqEdits module).
    nontranslating => 'nontranslating_CDS',
    
    # By default, genes are loaded as full-on genes; load instead as a
    # predicted transcript by setting 'prediction' = 1.
    prediction => 0,
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

sub pipeline_wide_parameters {
 my ($self) = @_;
 
 return {
   %{$self->SUPER::pipeline_wide_parameters},
   'species'         => $self->o('species'),
   'db_type'         => $self->o('db_type'),
   'logic_name'      => $self->o('logic_name'),
   'fasta_file'      => $self->o('fasta_file'),
   'delete_existing' => $self->o('delete_existing'),
   'fix_models'      => $self->o('fix_models'),
   'apply_seq_edits' => $self->o('apply_seq_edits'),
 };
}

sub pipeline_analyses {
  my ($self) = @_;
  
  return [
    {
      -logic_name        => 'GFF3Tidy',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => $self->o('gff3_tidy').' '.
                                     $self->o('gff3_file').' > '.
                                     $self->o('gff3_tidy_file'),
                            },
      -input_ids         => [ {} ],
      -rc_name           => 'normal-rh7',
      -flow_into         => ['GFF3Validate'],
    },

    {
      -logic_name        => 'GFF3Validate',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => $self->o('gff3_validate').' '.
                                     $self->o('gff3_tidy_file'),
                            },
      -rc_name           => 'normal-rh7',
      -flow_into         => {
                              '1' => WHEN('-e #fasta_file#' =>
                                      ['FastaTidy'],
                                     ELSE
                                      ['DumpGenome']),
                            },
    },

    {
      -logic_name        => 'FastaTidy',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              cmd => $self->o('fasta_tidy').' '.
                                     $self->o('fasta_file'),
                            },
      -rc_name           => 'normal-rh7',
      -flow_into         => ['BackupDatabase'],
    },

    {
      -logic_name        => 'DumpGenome',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DumpGenome',
      -max_retry_count   => 1,
      -parameters        => {
                              genome_file  => $self->o('fasta_file'),
                              header_style => 'name',
                            },
      -rc_name           => 'normal-rh7',
      -flow_into         => ['BackupDatabase'],
    },

    {
      -logic_name        => 'BackupDatabase',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DatabaseDumper',
      -max_retry_count   => 1,
      -parameters        => {
                              output_file => catdir($self->o('pipeline_dir'), $self->o('species'), 'pre_gff3_bkp.sql.gz'),
                            },
      -rc_name           => 'normal-rh7',
      -flow_into         => {
                              '1' => WHEN('#delete_existing#' =>
                                      ['DeleteGenes'],
                                     ELSE
                                      ['AnalysisSetup']),
                            },
    },

    {
      -logic_name        => 'DeleteGenes',
      -module            => 'Bio::EnsEMBL::EGPipeline::LoadGFF3::DeleteGenes',
      -max_retry_count   => 1,
      -parameters        => {},
      -rc_name           => 'normal-rh7',
      -flow_into         => ['AnalysisSetup'],
    },

    {
      -logic_name        => 'AnalysisSetup',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count   => 0,
      -parameters        => {
                              db_backup_required => 1,
                              db_backup_file     => catdir($self->o('pipeline_dir'), $self->o('species'), 'pre_gff3_bkp.sql.gz'),
                              module             => $self->o('analysis_module'),
                              delete_existing    => $self->o('delete_existing'),
                              production_lookup  => $self->o('production_lookup'),
                              production_db      => $self->o('production_db'),
                            },
      -meadow_type       => 'LOCAL',
      -flow_into         => ['AddSynonyms'],
    },

    {
      -logic_name        => 'AddSynonyms',
      -module            => 'Bio::EnsEMBL::EGPipeline::LoadGFF3::AddSynonyms',
      -max_retry_count   => 0,
      -parameters        => {
                              synonym_external_db => $self->o('synonym_external_db'),
                            },
      -rc_name           => 'normal-rh7',
      -flow_into         => ['LoadGFF3'],
    },

    {
      -logic_name        => 'LoadGFF3',
      -module            => 'Bio::EnsEMBL::EGPipeline::LoadGFF3::LoadGFF3',
      -max_retry_count   => 0,
      -parameters        => {
                              gene_source    => $self->o('gene_source'),
                              gff3_file      => $self->o('gff3_tidy_file'),
                              fasta_file     => $self->o('fasta_file'),
                              gene_types     => $self->o('gene_types'),
                              mrna_types     => $self->o('mrna_types'),
                              exon_types     => $self->o('exon_types'),
                              cds_types      => $self->o('cds_types'),
                              utr_types      => $self->o('utr_types'),
                              ignore_types   => $self->o('ignore_types'),
                              types_complete => $self->o('types_complete'),
                              use_name_field => $self->o('use_name_field'),
                              polypeptides   => $self->o('polypeptides'),
                              nontranslating => $self->o('nontranslating'),
                              prediction     => $self->o('prediction'),
                              xref_gene_external_db        => $self->o('xref_gene_external_db'),
                              xref_transcript_external_db  => $self->o('xref_transcript_external_db'),
                              xref_translation_external_db => $self->o('xref_translation_external_db'),
                              
                            },
      -rc_name           => 'normal-rh7',
      -flow_into         => {
                              '1' => WHEN('#fix_models#' =>
                                      ['FixModels'],
                                     ELSE
                                      ['EmailReport']),
                            },
    },

    {
      -logic_name        => 'FixModels',
      -module            => 'Bio::EnsEMBL::EGPipeline::LoadGFF3::FixModels',
      -max_retry_count   => 0,
      -parameters        => {
                              protein_fasta_file => $self->o('protein_fasta_file'),
                            },
      -rc_name           => 'normal-rh7',
      -flow_into         => {
                              '1' => WHEN('#apply_seq_edits#' =>
                                      ['ApplySeqEdits'],
                                     ELSE
                                      ['EmailReport']),
                            },
    },

    {
      -logic_name        => 'ApplySeqEdits',
      -module            => 'Bio::EnsEMBL::EGPipeline::LoadGFF3::ApplySeqEdits',
      -max_retry_count   => 0,
      -parameters        => {
                              genbank_file       => $self->o('genbank_file'),
                              protein_fasta_file => $self->o('protein_fasta_file'),
                            },
      -rc_name           => 'normal-rh7',
      -flow_into         => ['EmailReport'],
    },

    {
      -logic_name        => 'EmailReport',
      -module            => 'Bio::EnsEMBL::EGPipeline::LoadGFF3::EmailReport',
      -max_retry_count   => 1,
      -parameters        => {
                              email              => $self->o('email'),
                              subject            => 'GFF3 Loading pipeline has completed for #species#',
                              protein_fasta_file => $self->o('protein_fasta_file'),
                            },
      -rc_name           => 'normal-rh7',
    },

  ];
}

1;
