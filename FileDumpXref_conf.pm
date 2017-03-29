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

Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpXref_conf

=head1 DESCRIPTION

Dump xrefs in TSV format.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpXref_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::FileDump_conf');

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'file_dump_xref_'.$self->o('ensembl_release'),
    
    eg_dir_structure   => 0,
    eg_filename_format => $self->o('eg_dir_structure'),
    out_file_stem      => undef,
    
    db_type   => 'core',
    data_type => 'xrefs',
    file_type => 'tsv',
    
    logic_name  => [],
    external_db => [],

    delete_existing => 1,
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name        => 'FileDumpXref',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -input_ids         => [ {} ],
      -max_retry_count   => 0,
      -rc_name           => 'normal',
      -flow_into         => [
                              WHEN('#delete_existing#' => ['DeleteExistingFiles'],
                              ELSE ['SpeciesFactory']
                              ),
                            ],
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'DeleteExistingFiles',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => 'mkdir -p #results_dir#_tmp;
                                      mv #results_dir#/* #results_dir#_tmp/.',
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '1->A' => ['SpeciesFactory'],
                              'A->1' => ['SetFilePermissions'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
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
      -max_retry_count   => 1,
      -flow_into         => {
                              '2' => ['xref'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'xref',
	    -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::XrefDumper',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              db_type            => $self->o('db_type'),
                              data_type          => $self->o('data_type'),
                              file_type          => $self->o('file_type'),
                              out_file_stem      => $self->o('out_file_stem'),
                              eg_dir_structure   => $self->o('eg_dir_structure'),
                              eg_filename_format => $self->o('eg_filename_format'),
                              logic_name         => $self->o('logic_name'),
                              external_db        => $self->o('external_db'),
                            },
      -rc_name           => 'normal',
      -flow_into         => ['CompressFile'],
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
    },

    {
      -logic_name        => 'SetFilePermissions',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 0,
      -parameters        => {
                              cmd => 'chmod g+rw #results_dir#/*',
                            },
      -rc_name           => 'normal',
    },

  ];
}

1;
