=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::PipeConfig::SampleData_conf

=head1 DESCRIPTION

Create sample data in the core database of new/updated species,
using gene trees, xrefs and supporting evidences to find 'good'
gene/transcript/location examples. Also generate VEP examples.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::SampleData_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    species      => [],
    antispecies  => [],
    division     => [],
    run_all      => 0,
    meta_filters => {},

    # A script from the variation repo is needed, so need a path for it.
    base_dir => $ENV{'BASE_DIR'},

    # By default, only update species with new or updated genesets.
    new_genesets_only => 1,

    # Default is to add gene and VEP samples, but can do one at a time.
    gene_sample => 1,
    vep_sample  => 1,

    # This setting is only applied for vertebrates.
    maximum_gene_length => 100000,
    
    # Config/history files for storing record of datacheck run.
    config_file  => undef,
    history_file => undef,
  };
}

# Ensures that species output parameter gets propagated implicitly.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('scratch_small_dir'),
  ];
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name      => 'SpeciesFactory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -max_retry_count => 1,
      -input_ids       => [ {} ],
      -parameters      => {
                            species      => $self->o('species'),
                            division     => $self->o('division'),
                            run_all      => $self->o('run_all'),
                            antispecies  => $self->o('antispecies'),
                            meta_filters => $self->o('meta_filters'),
                           },
      -flow_into       => {
                            '2->A' => ['CheckSampleData'],
                            'A->1' => ['TidyScratch']
                          },
    },

    {
      -logic_name      => 'CheckSampleData',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::SampleData::CheckSampleData',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -parameters      => {
                            release => $self->o('ensembl_release'),
                            new_genesets_only => $self->o('new_genesets_only'),
                            gene_sample => $self->o('gene_sample'),
                            vep_sample => $self->o('vep_sample'),
                          },
      -flow_into       => {
                           '3' => WHEN('#gene_sample#' => 'GeneSampleDataChecks'),
                           '4' => WHEN('#gene_sample#' => 'GenerateGeneSample'),
                           '5' => WHEN('#vep_sample#'  => 'VEPSampleDataChecks'),
                           '6' => WHEN('#vep_sample#'  => 'GenerateVEPSample'),
                          },
    },

    {
      -logic_name      => 'GenerateGeneSample',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::SampleData::GenerateGeneSample',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -parameters      => {
                            maximum_gene_length => $self->o('maximum_gene_length'),
                          },
      -flow_into       => {
                             '1' => ['GeneSampleDataChecks'],
                            '-1' => ['GenerateGeneSample_mem'],
                          },
      -rc_name         => '2GB',
    },

    {
      -logic_name      => 'GenerateGeneSample_mem',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::SampleData::GenerateGeneSample',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -parameters      => {
                            maximum_gene_length => $self->o('maximum_gene_length'),
                          },
      -flow_into       => {
                            '1' => ['GeneSampleDataChecks'],
                          },
      -rc_name         => '8GB',
    },

    {
      -logic_name      => "GenerateVEPSample",
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -parameters      => {
                            'db_srv' => $self->o('db_srv'),
                            'release' => $self->o('ensembl_release'),
                            'base_dir' => $self->o('base_dir'),
                            'dir' => $self->o('scratch_small_dir'),
                            'cmd' => 'perl #base_dir#/ensembl-variation/scripts/misc/generate_vep_examples.pl $(#db_srv# details script) -species #species# -version #release# -dir #dir# -write_to_db'
                          },
      -flow_into       => {
                            '1' => ['VEPSampleDataChecks']
                          },
      -rc_name         => '2GB',
    },

    {
      -logic_name      => 'GeneSampleDataChecks',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
      -parameters      => {
                            datacheck_groups => ['meta_sample'],
                            config_file      => $self->o('config_file'),
                            history_file     => $self->o('history_file'),
                            registry_file    => $self->o('registry'),
                            failures_fatal   => 1,
                          },
    },

    {
      -logic_name      => 'VEPSampleDataChecks',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
      -parameters      => {
                            datacheck_groups => ['meta_sample'],
                            config_file      => $self->o('config_file'),
                            history_file     => $self->o('history_file'),
                            registry_file    => $self->o('registry'),
                            failures_fatal   => 1,
                          },
    },

    {
      -logic_name        => 'TidyScratch',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              cmd => 'rm -rf '.$self->o('scratch_small_dir'),
                            },
    },

  ];
}

1;
