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

Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpEG_conf

=head1 DESCRIPTION

Dump GFF3 files.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpEG_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'ftp_dump_'.$self->o('eg_release'),

    species      => [],
    division     => [],
    run_all      => 0,
    antispecies  => [],
    meta_filters => {},

    dump_types         => ['gff3'],
    pipeline_dir       => $self->o('ENV', 'PWD'),
    eg_toplevel_dir    => catdir($self->o('pipeline_dir'), 'release-'.$self->o('eg_release')),
    eg_dir_structure   => 1,
    eg_filename_format => $self->o('eg_dir_structure'),
    compress_files     => 1,

    gff3_feature_types    => ['Gene', 'Transcript', 'RepeatFeature'],
    gff3_per_chromosome   => 1,
    gff3_include_scaffold => 0,
    gt_exe                => '/nfs/panda/ensemblgenomes/external/genometools/bin/gt',
    gff3_tidy             => $self->o('gt_exe').' gff3 -tidy -sort -retainids',
    gff3_validate         => $self->o('gt_exe').' gff3validator',

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

  my $flow_into_compress = $self->o('compress_files') ? ['CompressFile'] : [];

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
                              '2' => $self->o('dump_types'),
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'gff3',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GFF3Dumper',
      -parameters        => {
                              feature_types      => $self->o('gff3_feature_types'),
                              pipeline_dir       => $self->o('eg_toplevel_dir'),
                              eg_dir_structure   => $self->o('eg_dir_structure'),
                              eg_filename_format => $self->o('eg_filename_format'),
                              per_chromosome     => $self->o('gff3_per_chromosome'),
                              include_scaffold   => $self->o('gff3_include_scaffold'),
                            },
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -rc_name           => 'normal',
      -flow_into         => ['gff3Tidy'],
    },

    {
      -logic_name        => 'gff3Tidy',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
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
      -parameters        => {
                              cmd => 'mv #out_file#.sorted #out_file#',
                            },
      -rc_name           => 'normal',
      -flow_into         => ['gff3Validate'],
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'gff3Validate',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
      -parameters        => {
                              cmd => $self->o('gff3_validate').' #out_file#',
                            },
      -rc_name           => 'normal',
      -flow_into         => $flow_into_compress,
    },

    {
      -logic_name        => 'CompressFile',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
      -parameters        => {
                              cmd => 'gzip -f #out_file#',
                            },
      -rc_name           => 'normal',
    },

  ];
}

1;
