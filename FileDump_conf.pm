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

Bio::EnsEMBL::EGPipeline::PipeConfig::FileDump_conf

=head1 DESCRIPTION

Dump Fasta, GFF3, and GTF files.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::FileDump_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'file_dump_'.$self->o('ensembl_release'),

    species      => [],
    division     => [],
    run_all      => 0,
    antispecies  => [],
    meta_filters => {},

    base_dir    => $self->o('ENV', 'PWD'),
    results_dir => catdir($self->o('base_dir'), $self->o('pipeline_name')),

    dump_types => {
       '3' => ['fasta_toplevel'],
       '4' => ['fasta_seqlevel'],
       '5' => ['agp_assembly'],
       '6' => ['fasta_transcripts'],
       '7' => ['fasta_peptides'],
       '8' => ['gtf_genes'],
       '9' => ['gff3_genes'],
      '10' => ['gff3_repeats'],
    },

    # These dumps will only be run if the species has genes.
    gene_dumps => [
      'fasta_transcripts',
      'fasta_peptides',
      'gtf_genes',
      'gff3_genes',
    ],

    # All dumps are run by default, but can be switched off.
    skip_dumps => [],
    
    # Gap type 'scaffold' is assumed unless otherwise specified.
    agp_gap_type => {},

    # Linkage is assumed unless otherwise specified.
    agp_linkage => {},
    
    # Linkage evidence 'paired-ends' is assumed unless otherwise specified.
    agp_evidence => {},

    gff3_per_chromosome   => 0,
    gff3_include_scaffold => 1,
    
    gt_exe        => 'gt',
    gff3_tidy     => $self->o('gt_exe').' gff3 -tidy -sort -retainids',
    gff3_validate => $self->o('gt_exe').' gff3validator',
    
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
    'mkdir -p '.$self->o('results_dir'),
  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    results_dir => $self->o('results_dir'),
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name        => 'FileDump',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 0,
      -input_ids         => [ {} ],
      -parameters        => {},
      -flow_into         => {
                              '1' => ['FileDumpSpeciesFactory'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'FileDumpSpeciesFactory',
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
                              '2' => ['DumpFactory'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'DumpFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::DumpFactory',
      -max_retry_count   => 0,
      -parameters        => {
                              dump_types => $self->o('dump_types'),
                              gene_dumps => $self->o('gene_dumps'),
                              skip_dumps => $self->o('skip_dumps'),
                            },
      -flow_into         => $self->o('dump_types'),
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'fasta_toplevel',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GenomeDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              repeat_masking => 'soft',
                              overwrite      => 1,
                              header_style   => 'name_and_type_and_location',
                              escape_branch  => -1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '-1' => ['fasta_toplevel_himem'],
                               '1' => ['CompressFile'],
                            },
    },

    {
      -logic_name        => 'fasta_toplevel_himem',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GenomeDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              repeat_masking => 'soft',
                              overwrite      => 1,
                              header_style   => 'name_and_type_and_location',
                            },
      -rc_name           => '16Gb_mem',
      -flow_into         => ['CompressFile'],
    },

    {
      -logic_name        => 'fasta_seqlevel',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GenomeDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              repeat_masking => 'soft',
                              overwrite      => 1,
                              header_style   => 'name_and_type_and_location',
                              escape_branch  => -1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '-1' => ['fasta_seqlevel_himem'],
                               '1' => ['CompressFile'],
                            },
    },

    {
      -logic_name        => 'fasta_seqlevel_himem',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GenomeDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              repeat_masking => 'soft',
                              overwrite      => 1,
                              header_style   => 'name_and_type_and_location',
                            },
      -rc_name           => '16Gb_mem',
      -flow_into         => ['CompressFile'],
    },

    {
      -logic_name        => 'agp_assembly',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::AGPDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              agp_gap_type  => $self->o('agp_gap_type'),
                              agp_linkage   => $self->o('agp_linkage'),
                              agp_evidence  => $self->o('agp_evidence'),
                              escape_branch => -1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '-1' => ['agp_assembly_himem'],
                               '1' => ['CompressFile'],
                            },
    },

    {
      -logic_name        => 'agp_assembly_himem',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::AGPDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              agp_gap_type => $self->o('agp_gap_type'),
                              agp_linkage  => $self->o('agp_linkage'),
                              agp_evidence => $self->o('agp_evidence'),
                            },
      -rc_name           => '16Gb_mem',
      -flow_into         => ['CompressFile'],
    },

    {
      -logic_name        => 'fasta_transcripts',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::TranscriptomeDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              header_style  => 'extended',
                              escape_branch => -1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '-1' => ['fasta_transcripts_himem'],
                               '1' => ['CompressFile'],
                            },
    },

    {
      -logic_name        => 'fasta_transcripts_himem',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::TranscriptomeDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              header_style => 'extended',
                            },
      -rc_name           => '16Gb_mem',
      -flow_into         => ['CompressFile'],
    },

    {
      -logic_name        => 'fasta_peptides',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::ProteomeDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              header_style  => 'extended',
                              escape_branch => -1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '-1' => ['fasta_peptides_himem'],
                               '1' => ['CompressFile'],
                            },
    },

    {
      -logic_name        => 'fasta_peptides_himem',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::ProteomeDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              header_style => 'extended',
                            },
      -rc_name           => '16Gb_mem',
      -flow_into         => ['CompressFile'],
    },

    {
      -logic_name        => 'gtf_genes',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GTFDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              data_type     => 'basefeatures',
                              escape_branch => -1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '-1' => ['gtf_genes_himem'],
                               '1' => ['CompressFile'],
                            },
    },

    {
      -logic_name        => 'gtf_genes_himem',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GTFDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              data_type => 'basefeatures',
                            },
      -rc_name           => '16Gb_mem',
      -flow_into         => ['CompressFile'],
    },

    {
      -logic_name        => 'gff3_genes',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GFF3Dumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              data_type          => 'basefeatures',
                              feature_type       => ['Gene', 'Transcript'],
                              per_chromosome     => $self->o('gff3_per_chromosome'),
                              include_scaffold   => $self->o('gff3_include_scaffold'),
                              remove_id_prefix   => 1,
                              relabel_transcript => 1,
                              escape_branch      => -1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '-1'   => ['gff3_genes_himem'],
                              '1->A' => ['gff3Tidy'],
                              'A->1' => ['CompressFile'],
                            },
    },

    {
      -logic_name        => 'gff3_genes_himem',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GFF3Dumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              data_type          => 'basefeatures',
                              feature_type       => ['Gene', 'Transcript'],
                              per_chromosome     => $self->o('gff3_per_chromosome'),
                              include_scaffold   => $self->o('gff3_include_scaffold'),
                              remove_id_prefix   => 1,
                              relabel_transcript => 1,
                            },
      -rc_name           => '16Gb_mem',
      -flow_into         => {
                              '1->A' => ['gff3Tidy'],
                              'A->1' => ['CompressFile'],
                            },
    },

    {
      -logic_name        => 'gff3_repeats',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GFF3Dumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              data_type         => 'repeatfeatures',
                              feature_type      => ['RepeatFeature'],
                              per_chromosome    => $self->o('gff3_per_chromosome'),
                              include_scaffold  => $self->o('gff3_include_scaffold'),
                              remove_id_prefix  => 1,
                              remove_separators => 1,
                              escape_branch     => -1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '-1'   => ['gff3_repeats_himem'],
                              '1->A' => ['gff3Tidy'],
                              'A->1' => ['CompressFile'],
                            },
    },

    {
      -logic_name        => 'gff3_repeats_himem',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GFF3Dumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              data_type         => 'repeatfeatures',
                              feature_type      => ['RepeatFeature'],
                              per_chromosome    => $self->o('gff3_per_chromosome'),
                              include_scaffold  => $self->o('gff3_include_scaffold'),
                              remove_id_prefix  => 1,
                              remove_separators => 1,
                            },
      -rc_name           => '16Gb_mem',
      -flow_into         => {
                              '1->A' => ['gff3Tidy'],
                              'A->1' => ['CompressFile'],
                            },
    },

    {
      -logic_name        => 'gff3Tidy',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => $self->o('gff3_tidy').' #out_file# > #out_file#.sorted',
                            },
      -rc_name           => 'normal',
      -flow_into         => ['gff3Move'],
    },

    {
      -logic_name        => 'gff3Move',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => 'mv #out_file#.sorted #out_file#',
                            },
      -flow_into         => ['gff3Validate'],
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'gff3Validate',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => $self->o('gff3_validate').' #out_file#',
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'CompressFile',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => 'gzip -n -f #out_file#',
                            },
      -rc_name           => 'normal',
      -flow_into         => ['MD5Checksum'],
    },

    {
      -logic_name        => 'MD5Checksum',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => 'cd $(dirname #out_file#); OUT_FILE=$(basename #out_file#.gz); md5sum $OUT_FILE > $OUT_FILE.md5; ',
                            },
      -meadow_type       => 'LOCAL',
    },

  ];
}

1;
