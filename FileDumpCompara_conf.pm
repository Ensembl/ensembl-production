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

use Bio::EnsEMBL::Hive::Version 2.3;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'file_dump_compara_'.$self->o('ensembl_release'),

    results_dir => $self->o('ENV', 'PWD'),
    checksum    => 1,
    compress    => 1,
    
    dump_types => {
       '3' => ['gene_trees_newick'],
       '4' => ['gene_alignments_cdna'],
       '5' => ['gene_alignments_aa'],
       '6' => ['gene_trees_cdna_xml'],
       '7' => ['gene_trees_aa_xml'],
       '8' => ['homologs_xml'],
    },

    # All dumps are run by default, but can be switched off.
    skip_dumps => [],

    # Maximum number of files in each sub-directory.
    files_per_subdir => 500,

    # For the Drupal nodes, each file type has a standard description.
    # The module that creates the file substitutes values for the text in caps.
    drupal_file  => catdir($self->o('results_dir'), 'drupal_load_compara.csv'),
    staging_dir  => 'sites/default/files/ftp/staging',
    release_date => undef,

    drupal_desc => {
      'gene_trees_newick'    => '',
      'gene_alignments_cdna' => '',
      'gene_alignments_aa'   => '',
      'gene_trees_cdna_xml'  => '',
      'gene_trees_aa_xml'    => '',
      'homologs_xml'         => '',
    },
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
  
  my ($post_processing_flow, $post_processing_analyses) =
    $self->post_processing_analyses($self->o('checksum'), $self->o('compress'));
  
  return [
    {
      -logic_name        => 'FileDump',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 0,
      -input_ids         => [ {} ],
      -parameters        => {},
      -flow_into         => {
                              '1' => ['TreeFactory'],
                              #'1->A' => ['TreeFactory'],
                              #'A->1' => ['WriteDrupalFile'],
                            },
      -meadow_type       => 'LOCAL',
    },
    
    #{
    #  -logic_name        => 'WriteDrupalFile',
    #  -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::WriteDrupalFile',
    #  -max_retry_count   => 1,
    #  -parameters        => {
    #                          results_dir           => $self->o('results_dir'),
    #                          drupal_file           => $self->o('drupal_file'),
    #                          staging_dir           => $self->o('staging_dir'),
    #                          release_date          => $self->o('release_date'),
    #                          drupal_desc           => $self->o('drupal_desc'),
    #                        },
    #  -rc_name           => 'normal',
    #},

    {
      -logic_name        => 'TreeFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::TreeFactory',
      -max_retry_count   => 0,
      -parameters        => {
                              dump_types       => $self->o('dump_types'),
                              skip_dumps       => $self->o('skip_dumps'),
                              files_per_subdir => $self->o('files_per_subdir'),
                            },
      -flow_into         => {
                              '3->C' => ['gene_trees_newick'],
                              'C->1' => ['PostProcessing'],
                              '4->D' => ['gene_alignments_cdna'],
                              'D->1' => ['PostProcessing'],
                              '5->E' => ['gene_alignments_aa'],
                              'E->1' => ['PostProcessing'],
                              '6->F' => ['gene_trees_cdna_xml'],
                              'F->1' => ['PostProcessing'],
                              '7->G' => ['gene_trees_aa_xml'],
                              'G->1' => ['PostProcessing'],
                              '8->H' => ['homologs_xml'],
                              'H->1' => ['PostProcessing'],
                            },
    },

    {
      -logic_name        => 'gene_trees_newick',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::TreeDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              tree_format => 'newick',
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
                              tree_format => 'xml',
                              seq_type    => 'cdna',
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'gene_trees_aa_xml',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::TreeDumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 1,
      -parameters        => {
                              tree_format => 'xml',
                              seq_type    => 'aa',
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
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'PostProcessing',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => 'tar -cf #out_dir#.tar #out_dir#',
                            },
      -flow_into         => $post_processing_flow,
    },

    @$post_processing_analyses,

  ];
}

sub post_processing_analyses {
  my ($self, $checksum, $compress) = @_;
  
  my $flow = [];
  my $analyses = [];
  
  if ($compress) {
    $flow = ['CompressFile'];
    
    push @$analyses,
      {
        -logic_name        => 'CompressFile',
        -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -analysis_capacity => 10,
        -batch_size        => 10,
        -max_retry_count   => 0,
        -parameters        => {
                                cmd => 'gzip -n -f #out_dir#.tar',
                              },
        -rc_name           => 'normal',
        -flow_into         => $checksum ? ['MD5Checksum'] : [],
      }
    ;
  }
  
  if ($checksum) {
    my $cmd = 'cd $(dirname #out_dir#.tar); ';    
    if ($compress) {
      $cmd .= 'OUT_FILE=$(basename #out_dir#.tar.gz); ';
    } else {
      $flow = ['MD5Checksum'];
      $cmd .= 'OUT_FILE=$(basename #out_dir#.tar); ';
    }
    $cmd .= 'md5sum $OUT_FILE > $OUT_FILE.md5; ';
    
    push @$analyses,
      {
        -logic_name        => 'MD5Checksum',
        -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        -analysis_capacity => 10,
        -max_retry_count   => 0,
        -parameters        => {
                                cmd => $cmd,
                              },
        -meadow_type       => 'LOCAL',
      }
    ;
  }
  
  return ($flow, $analyses);
}

1;
