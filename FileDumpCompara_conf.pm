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

Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpCompara_conf

=head1 DESCRIPTION

Dump Compara files.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpCompara_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'file_dump_compara_'.$self->o('ensembl_release'),

    compara => 'multi',

    base_dir    => $self->o('ENV', 'PWD'),
    results_dir => catdir($self->o('base_dir'), $self->o('pipeline_name')),

    tree_dump_types => {
       '3' => ['gene_trees_newick'],
       '4' => ['gene_alignments_cdna'],
       '5' => ['gene_alignments_aa'],
       '6' => ['gene_trees_cdna_xml'],
       '7' => ['gene_trees_aa_xml'],
       '8' => ['homologs_xml'],
    },

    pairwise_dump_types => {
       '3' => ['wg_alignments_maf'],
    },

    compara_dumps => {
      'gene_trees_newick'    => 'GENE-TREES-NEWICK',
      'gene_alignments_cdna' => 'GENE-ALIGN-TRANSCRIPTS',
      'gene_alignments_aa'   => 'GENE-ALIGN-PEPTIDES',
      'gene_trees_cdna_xml'  => 'GENE-TREES-TRANSCRIPTS',
      'gene_trees_aa_xml'    => 'GENE-TREES-PEPTIDES',
      'homologs_xml'         => 'HOMOLOGS',
      'wg_alignments_maf'    => 'WG-ALIGN',
    },

    maf_file_per_chr => 1,
    maf_file_per_scaffold => 0,

    # All dumps are run by default, but can be switched off.
    skip_dumps => [],

    # Maximum number of files in each sub-directory.
    files_per_subdir => 500,

    # Use external programs to validate output files. Note that we use
    # a slightly customised orthoxml schema, that allows the file to
    # only contain paralogs.
    sofware_dir     => '/nfs/software/ensembl/RHEL7/linuxbrew/bin',
    newick_stats    => catdir($self->o('sofware_dir'), 'nw_stats'),
    mafValidator    => catdir($self->o('sofware_dir'), 'mafValidator.py'),
    #mafValidator    => '/nfs/panda/ensemblgenomes/external/mafTools/bin/mafValidator.py',
    
    xmllint         => 'xmllint',
    schema_dir      => '/nfs/panda/ensemblgenomes/external/xml_schema',
    orthoxml_schema => catdir($self->o('schema_dir'), 'orthoxml.paralogs.xsd'),
    phyloxml_schema => catdir($self->o('schema_dir'), 'phyloxml.xsd'),

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
      -logic_name        => 'FileDumpCompara',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 0,
      -input_ids         => [ {} ],
      -parameters        => {},
      -flow_into         => {
                              '1' => ['TreeFactory', 'PairwiseAlignmentFactory'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'TreeFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::TreeFactory',
      -max_retry_count   => 0,
      -parameters        => {
                              compara          => $self->o('compara'),
                              dump_types       => $self->o('tree_dump_types'),
                              compara_dumps    => $self->o('compara_dumps'),
                              skip_dumps       => $self->o('skip_dumps'),
                              files_per_subdir => $self->o('files_per_subdir'),
                              release_date     => $self->o('release_date'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '3->C' => ['gene_trees_newick'],
                              'C->1' => ['TarFiles'],
                              '4->D' => ['gene_alignments_cdna'],
                              'D->1' => ['TarFiles'],
                              '5->E' => ['gene_alignments_aa'],
                              'E->1' => ['TarFiles'],
                              '6->F' => ['gene_trees_cdna_xml'],
                              'F->1' => ['TarFiles'],
                              '7->G' => ['gene_trees_aa_xml'],
                              'G->1' => ['TarFiles'],
                              '8->H' => ['homologs_xml'],
                              'H->1' => ['TarFiles'],
                            },
    },

    {
      -logic_name        => 'PairwiseAlignmentFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::PairwiseAlignmentFactory',
      -max_retry_count   => 0,
      -parameters        => {
                              compara          => $self->o('compara'),
                              dump_types       => $self->o('pairwise_dump_types'),
                              compara_dumps    => $self->o('compara_dumps'),
                              skip_dumps       => $self->o('skip_dumps'),
                              files_per_subdir => $self->o('files_per_subdir'),
                              release_date     => $self->o('release_date'),
                              ensembl_release  => $self->o('ensembl_release'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '3' => ['wg_alignments_maf'],
                            },
    },

    {
      -logic_name        => 'gene_trees_newick',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::TreeDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              compara     => $self->o('compara'),
                              tree_format => 'newick',
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['ValidateNewick'],
                            },
    },

    {
      -logic_name        => 'ValidateNewick',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 500,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              cmd => $self->o('newick_stats').' #out_file#',
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'gene_alignments_cdna',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::AlignmentDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              compara  => $self->o('compara'),
                              seq_type => 'cdna',
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'gene_alignments_aa',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::AlignmentDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              compara  => $self->o('compara'),
                              seq_type => 'aa',
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'gene_trees_cdna_xml',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::TreeDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              compara     => $self->o('compara'),
                              tree_format => 'xml',
                              seq_type    => 'cdna',
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['ValidatePhyloxml'],
                            },
    },

    {
      -logic_name        => 'gene_trees_aa_xml',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::TreeDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              compara     => $self->o('compara'),
                              tree_format => 'xml',
                              seq_type    => 'aa',
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['ValidatePhyloxml'],
                            },
    },

    {
      -logic_name        => 'ValidatePhyloxml',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 500,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              cmd => $self->o('xmllint').' --noout --schema '.$self->o('phyloxml_schema').' #out_file#',
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'homologs_xml',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::HomologDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              compara        => $self->o('compara'),
                              homolog_format => 'xml',
                              release_date   => $self->o('release_date'),
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['ValidateOrthoxml'],
                            },
    },

    {
      -logic_name        => 'ValidateOrthoxml',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 500,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              cmd => $self->o('xmllint').' --noout --schema '.$self->o('orthoxml_schema').' #out_file#',
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'wg_alignments_maf',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::MAFDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              compara           => $self->o('compara'),
                              release_date      => $self->o('release_date'),
                              file_per_chr      => $self->o('maf_file_per_chr'),
                              file_per_scaffold => $self->o('maf_file_per_scaffold'),
                              escape_branch     => -1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '-1'    => ['wg_alignments_maf_himem'],
                               '2->A' => ['ValidateMAF'],
                               'A->1' => ['TarFiles'],
                            },
    },

    {
      -logic_name        => 'wg_alignments_maf_himem',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::MAFDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              compara           => $self->o('compara'),
                              release_date      => $self->o('release_date'),
                              file_per_chr      => $self->o('maf_file_per_chr'),
                              file_per_scaffold => $self->o('maf_file_per_scaffold'),
                            },
      -rc_name           => '16Gb_mem',
      -flow_into         => {
                               '2->A' => ['ValidateMAF'],
                               'A->1' => ['TarFiles'],
                            },
    },

    {
      -logic_name        => 'ValidateMAF',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              cmd => 'python '.$self->o('mafValidator').' --ignoreDuplicate --maf #out_file#',
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'TarFiles',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => 'cd #out_dir#; tar -cf #sub_dir#.tar #sub_dir# --remove-files',
                            },
      -rc_name           => 'normal',
      -flow_into         => ['CompressTarFile'],
    },

    {
      -logic_name        => 'CompressTarFile',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => 'cd #out_dir#; gzip -n -f #sub_dir#.tar',
                            },
      -rc_name           => 'normal',
      -flow_into         => ['MD5ChecksumTar'],
    },

    {
      -logic_name        => 'MD5ChecksumTar',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => 'cd #out_dir#; OUT_FILE=#sub_dir#.tar.gz; md5sum $OUT_FILE > $OUT_FILE.md5; ',
                            },
      -meadow_type       => 'LOCAL',
    },
      
  ];
}

1;
