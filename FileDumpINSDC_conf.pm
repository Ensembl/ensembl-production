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

Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpINSDC_conf

=head1 DESCRIPTION

Dump EMBL file.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpINSDC_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::FileDump_conf');

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'file_dump_insdc_'.$self->o('ensembl_release'),
    
    eg_dir_structure   => 0,
    eg_filename_format => $self->o('eg_dir_structure'),
    out_file_stem      => undef,
    
    insdc_format   => 'embl',
    db_type        => 'core',
    feature_type   => [],
    data_type      => 'features',
    file_type      => $self->o('insdc_format').'.dat',
    gene_centric   => 0,
    per_chromosome => 0,
    source         => 'VectorBase',
    source_url     => 'https://www.vectorbase.org',
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
                              regulation_flow => 0,
                              variation_flow  => 0,
                            },
      -max_retry_count   => 1,
      -flow_into         => {
                              '2' => ['insdc'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'insdc',
	    -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::INSDCDumper',
      -analysis_capacity => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              insdc_format       => $self->o('insdc_format'),
                              db_type            => $self->o('db_type'),
                              feature_type       => $self->o('feature_type'),
                              data_type          => $self->o('data_type'),
                              file_type          => $self->o('file_type'),
                              gene_centric       => $self->o('gene_centric'),
                              per_chromosome     => $self->o('per_chromosome'),
                              source             => $self->o('source'),
                              source_url         => $self->o('source_url'),
                              out_file_stem      => $self->o('out_file_stem'),
                              eg_dir_structure   => $self->o('eg_dir_structure'),
                              eg_filename_format => $self->o('eg_filename_format'),
                              taxonomy_db        => $self->o('taxonomy_db'),
                            },
      -rc_name           => 'normal',
	  },

  ];
}

1;
