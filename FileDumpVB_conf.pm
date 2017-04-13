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

Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpVB_conf

=head1 DESCRIPTION

Dump all files needed for a VectorBase release.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpVB_conf;

use strict;
use warnings;

use Bio::EnsEMBL::EGPipeline::PipeConfig::FileDump_conf;
use Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpCompara_conf;
use Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpVEP_conf;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;
use File::Spec::Functions qw(catdir);

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    
    %{Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpVEP_conf::default_options($self)},
    %{Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpCompara_conf::default_options($self)},
    %{Bio::EnsEMBL::EGPipeline::PipeConfig::FileDump_conf::default_options($self)},
    
    pipeline_name => 'file_dump_vb_'.$self->o('ensembl_release'),
    
    # Gap type 'scaffold' is assumed unless otherwise specified.
    agp_gap_type => {
      'anopheles_albimanus' => 'contig',
      'anopheles_gambiae'   => 'contig',
    },

    # Linkage is assumed unless otherwise specified.
    agp_linkage => {
      'anopheles_albimanus' => 'no',
      'anopheles_gambiae'   => 'no',
    },
    
    # Linkage evidence 'paired-ends' is assumed unless otherwise specified.
    agp_evidence => {
      'aedes_aegypti'          => 'unspecified',
      'anopheles_albimanus'    => 'na',
      'anopheles_darlingi'     => 'unspecified',
      'anopheles_gambiae'      => 'na',
      'anopheles_gambiaeS'     => 'unspecified',
      'culex_quinquefasciatus' => 'unspecified',
      'glossina_morsitans'     => 'unspecified',
      'ixodes_scapularis'      => 'unspecified',
      'lutzomyia_longipalpis'  => 'unspecified',
      'pediculus_humanus'      => 'unspecified',
      'rhodnius_prolixus'      => 'unspecified',
    },

    # Need to refer to last release's checksums, to see what has changed.
    checksum_dir => '/nfs/panda/ensemblgenomes/vectorbase/ftp_checksums',
    
    # Skip checksumming for files which don't require it.
    skip_file_match => ['WG-ALIGN'],

    # To get the download files to ND we need to generate a CSV file for
    # bulk creation of the Drupal nodes, and two sets of shell commands for
    # transferring data, one to be run at EBI, one at ND.
    drupal_file      => $self->o('results_dir').'.csv',
    manual_file      => $self->o('results_dir').'.txt',
    sh_ebi_file      => $self->o('results_dir').'.ebi.sh',
    sh_nd_file       => $self->o('results_dir').'.nd.sh',
    staging_dir      => 'sites/default/files/ftp/staging',
    nd_login         => $self->o('ENV', 'USER').'@www.vectorbase.org',
    nd_downloads_dir => '/data/sites/drupal-pre/downloads',
    nd_staging_dir   => '/data/sites/drupal-pre/staging',
    release_date     => undef,

    # For the Drupal nodes, each file type has a standard description.
    # The module that creates the file substitutes values for the text in caps.
    drupal_desc => {
      'fasta_toplevel'       => '<STRAIN> strain genomic <SEQTYPE> sequences, <ASSEMBLY> assembly, softmasked using RepeatMasker, Dust, and TRF.',
      'fasta_seqlevel'       => '<STRAIN> strain genomic <SEQTYPE> sequences, <ASSEMBLY> assembly.',
      'agp_assembly'         => 'AGP (v2.0) file relating <MAPPING> for the <SPECIES> <STRAIN> strain, <ASSEMBLY> assembly.',
      'fasta_transcripts'    => '<STRAIN> strain transcript sequences, <GENESET> geneset.',
      'fasta_peptides'       => '<STRAIN> strain peptide sequences, <GENESET> geneset.',
      'gtf_genes'            => '<STRAIN> strain <GENESET> geneset in GTF (v2.2) format.',
      'gff3_genes'           => '<STRAIN> strain <GENESET> geneset in GFF3 format.',
      'gff3_repeats'         => '<STRAIN> strain <ASSEMBLY> repeat features (RepeatMasker, Dust, TRF) in GFF3 format.',
      'gene_trees_newick'    => 'Gene trees in Newick (a.k.a. New Hampshire) format.',
      'gene_alignments_cdna' => 'Alignments of transcript sequences, used to infer gene trees.',
      'gene_alignments_aa'   => 'Alignments of peptide sequences, used to infer gene trees.',
      'gene_trees_cdna_xml'  => 'Gene trees in PhyloXML format, containing transcript alignments.',
      'gene_trees_aa_xml'    => 'Gene trees in PhyloXML format, containing peptide alignments.',
      'homologs_xml'         => 'Homologs in OrthoXML format.',
      'wg_alignments_maf'    => 'Pairwise whole genome alignment between <SPECIES1> and <SPECIES2>, in MAF format.',
    },

    drupal_desc_exception => {
      'fasta_toplevel' => {
        'Musca domestica' => '<STRAIN> strain genomic <TOPLEVEL> sequences, <ASSEMBLY> assembly, softmasked using WindowMasker, Dust, and TRF.',
      },
      'gff3_repeats' => {
        'Musca domestica' => '<STRAIN> strain <GENESET> repeat features (WindowMasker, Dust, TRF) in GFF3 format.',
      },
    },

    drupal_species => {
      'Anopheles culicifacies' => 'Anopheles culicifacies A',
    },
    
    # Dump files are produced for other groups within the EBI.
    embl_dump_dir    => '/nfs/panda/ensemblgenomes/vectorbase/for_uniparc_pending',
    uniprot_dump_dir => '/nfs/panda/ensemblgenomes/vectorbase/for_uniprot_pending',
    vep_dir          => '/nfs/panda/ensemblgenomes/vectorbase/vep',
    vep_dump_dir     => catdir($self->o('vep_dir'), $self->o('eg_version')),
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
    'mkdir -p '.$self->o('results_dir'),
    'mkdir -p '.$self->o('vep_dir'),
    'mkdir -p '.$self->o('embl_dump_dir'),
    'mkdir -p '.$self->o('uniprot_dump_dir'),
    'mkdir -p '.$self->o('vep_dump_dir'),
  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    results_dir     => $self->o('results_dir'),
    pipeline_dir    => $self->o('vep_dir'),
    ensembl_release => $self->o('ensembl_release'),
    eg_version      => $self->o('eg_version'),
    region_size     => $self->o('region_size'),
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  my $file_dump_analyses = Bio::EnsEMBL::EGPipeline::PipeConfig::FileDump_conf::pipeline_analyses($self);
  my $file_dump_compara_analyses = Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpCompara_conf::pipeline_analyses($self);
  my $file_dump_vep_analyses = Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpVEP_conf::pipeline_analyses($self);
  
  foreach my $analysis (@$file_dump_analyses) {
    delete $$analysis{'-input_ids'} if exists $$analysis{'-input_ids'};
  }
  foreach my $analysis (@$file_dump_compara_analyses) {
    delete $$analysis{'-input_ids'} if exists $$analysis{'-input_ids'};
  }
  foreach my $analysis (@$file_dump_vep_analyses) {
    delete $$analysis{'-input_ids'} if exists $$analysis{'-input_ids'};
  }
  
  return [
    {
      -logic_name        => 'FileDumpVB',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 0,
      -input_ids         => [ {} ],
      -parameters        => {},
      -flow_into         => ['FileDumpFTP', 'FileDumpLocal'],
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'FileDumpFTP',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 0,
      -parameters        => {},
      -flow_into         => {
                              '1->A' => ['FileDump', 'FileDumpCompara'],
                              'A->1' => ['CheckSumChecking'],
                            },
      -meadow_type       => 'LOCAL',
    },

    @$file_dump_analyses,
    @$file_dump_compara_analyses,

    {
      -logic_name        => 'CheckSumChecking',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::CheckSumChecking',
      -max_retry_count   => 1,
      -parameters        => {
                              checksum_dir    => $self->o('checksum_dir'),
                              release_date    => $self->o('release_date'),
                              skip_file_match => $self->o('skip_file_match'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['WriteDrupalFile'],
    },

    {
      -logic_name        => 'WriteDrupalFile',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::WriteDrupalFile',
      -max_retry_count   => 1,
      -parameters        => {
                              drupal_file           => $self->o('drupal_file'),
                              manual_file           => $self->o('manual_file'),
                              sh_ebi_file           => $self->o('sh_ebi_file'),
                              sh_nd_file            => $self->o('sh_nd_file'),
                              staging_dir           => $self->o('staging_dir'),
                              nd_login              => $self->o('nd_login'),
                              nd_downloads_dir      => $self->o('nd_downloads_dir'),
                              nd_staging_dir        => $self->o('nd_staging_dir'),
                              release_date          => $self->o('release_date'),
                              drupal_desc           => $self->o('drupal_desc'),
                              drupal_desc_exception => $self->o('drupal_desc_exception'),
                              drupal_species        => $self->o('drupal_species'),
                              gene_dumps            => $self->o('gene_dumps'),
                              compara_dumps         => $self->o('compara_dumps'),
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'FileDumpLocal',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 0,
      -parameters        => {},
      -flow_into         => {
                              '1->A' => ['FileDumpVEP', 'LocalSpeciesFactory'],
                              'A->1' => ['SetFilePermissions'],
                            },
      -meadow_type       => 'LOCAL',
    },

    @$file_dump_vep_analyses,

    {
      -logic_name        => 'SetFilePermissions',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => 'chmod -R g+rw #embl_dump_dir#;
                                      chmod -R g+rw #uniprot_dump_dir#;
                                      chmod -R g+rw #vep_dump_dir#;
                                      rm -rf #vep_dump_dir#/qc;',
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'LocalSpeciesFactory',
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
      -flow_into         => {
                              '2' => ['LocalDumpFactory'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'LocalDumpFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::DumpFactory',
      -max_retry_count   => 0,
      -parameters        => {
                              dump_types => {
                                              '3' => ['embl_genes'],
                                              '4' => ['tsv_uniprot'],
                                            },
                              gene_dumps => ['embl_genes', 'tsv_uniprot'],
                              skip_dumps => $self->o('skip_dumps'),
                            },
      -flow_into         => {
                              '3' => ['embl_genes'],
                              '4' => ['tsv_uniprot'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'embl_genes',
	    -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::INSDCDumper',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              results_dir        => $self->o('embl_dump_dir'),
                              insdc_format       => 'embl',
                              data_type          => 'features',
                              file_type          => 'embl.dat',
                              gene_centric       => 0,
                              source             => 'VectorBase',
                              source_url         => 'https://www.vectorbase.org',
                              taxonomy_db        => $self->o('taxonomy_db'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['CompressFileNoChecksum'],
	  },

    {
      -logic_name        => 'tsv_uniprot',
	    -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::XrefDumper',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              results_dir        => $self->o('uniprot_dump_dir'),
                              eg_filename_format => 1,
                              file_type          => 'uniprot.tsv',
                              external_db        => ['Uniprot/%'],
                            },
      -rc_name           => 'normal',
      -flow_into         => ['CompressFileNoChecksum'],
	  },

    {
      -logic_name        => 'CompressFileNoChecksum',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => 'gzip -n -f #out_file#',
                            },
      -rc_name           => 'normal',
    },

  ];
}

1;
