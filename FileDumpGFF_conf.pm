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

Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpGFF_conf

=head1 DESCRIPTION

Dump GFF3 file.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpGFF_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::FileDump_conf');

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'file_dump_gff_'.$self->o('ensembl_release'),
    
    eg_dir_structure   => 0,
    eg_filename_format => $self->o('eg_dir_structure'),
    out_file_stem      => undef,

    gff3_db_type            => 'core',
    gff3_feature_type       => [],
    gff3_data_type          => 'features',
    gff3_logic_name         => [],
    gff3_remove_id_prefix   => 0,
    gff3_relabel_transcript => 1,
    gff3_remove_separators  => 0,

  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -input_ids         => [ {} ],
      -parameters        => {
                              species         => $self->o('species'),
                              antispecies     => $self->o('antispecies'),
                              division        => $self->o('division'),
                              run_all         => $self->o('run_all'),
                              meta_filters    => $self->o('meta_filters'),
                              chromosome_flow => 0,
                              variation_flow  => 0,
                            },
      -max_retry_count   => 1,
      -flow_into         => {
                              '2' => ['gff3'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'gff3',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GFF3Dumper',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              db_type            => $self->o('gff3_db_type'),
                              data_type          => $self->o('gff3_data_type'),
                              feature_type       => $self->o('gff3_feature_type'),
                              per_chromosome     => $self->o('gff3_per_chromosome'),
                              include_scaffold   => $self->o('gff3_include_scaffold'),
                              logic_name         => $self->o('gff3_logic_name'),
                              remove_id_prefix   => $self->o('gff3_remove_id_prefix'),
                              relabel_transcript => $self->o('gff3_relabel_transcript'),
                              remove_separators  => $self->o('gff3_remove_separators'),
                              eg_dir_structure   => $self->o('eg_dir_structure'),
                              eg_filename_format => $self->o('eg_filename_format'),
                              out_file_stem      => $self->o('out_file_stem'),
                              escape_branch      => -1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '-1' => ['gff3_himem'],
                               '1' => ['gff3Tidy'],
                            },
    },

    {
      -logic_name        => 'gff3_himem',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GFF3Dumper',
      -analysis_capacity => 10,
      -can_be_empty      => 1,
      -max_retry_count   => 0,
      -parameters        => {
                              db_type            => $self->o('gff3_db_type'),
                              data_type          => $self->o('gff3_data_type'),
                              feature_type       => $self->o('gff3_feature_type'),
                              per_chromosome     => $self->o('gff3_per_chromosome'),
                              include_scaffold   => $self->o('gff3_include_scaffold'),
                              logic_name         => $self->o('gff3_logic_name'),
                              remove_id_prefix   => $self->o('gff3_remove_id_prefix'),
                              relabel_transcript => $self->o('gff3_relabel_transcript'),
                              remove_separators  => $self->o('gff3_remove_separators'),
                              out_file_stem      => $self->o('gff3_out_file_stem'),
                              eg_dir_structure   => $self->o('eg_dir_structure'),
                              eg_filename_format => $self->o('eg_filename_format'),
                            },
      -rc_name           => '16Gb_mem',
      -flow_into         => ['gff3Tidy'],
    },

    {
      -logic_name        => 'gff3Tidy',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
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
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => $self->o('gff3_validate').' #out_file#',
                            },
      -rc_name           => 'normal',
    },

  ];
}

1;
