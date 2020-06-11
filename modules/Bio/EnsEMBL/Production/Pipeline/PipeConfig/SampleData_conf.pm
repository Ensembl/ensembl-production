=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

=head1 SYNOPSIS


=head1 DESCRIPTION

Pipeline will update sample data in the core database of new/updated species with gene/transcript
found using compara gene trees, xrefs and supporting evidences.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::SampleData_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;


=head2 default_options

 Description: It returns a hashref containing the default options for HiveGeneric_conf
 Returntype : Hashref
 Exceptions : None


=cut

sub default_options {
    my ($self) = @_;

    return {
        # inherit other stuff from the base class
        %{ $self->SUPER::default_options() },
        pipeline_name => 'sample_data_'.$self->o('ensembl_release'),
        ## 'job_factory' parameters
        species       => [],
        antispecies   => [],
        division      => [],
        run_all       => 0,
        meta_filters  => {},
        history_file => undef,
        skip_metadata_check => 0,
        vep_species => $self->o('species'),
        gene_species => $self->o('species'),
        vep_division => $self->o('division'),
        gene_division => $self->o('division'),
        base_dir => $ENV{'BASE_DIR'},
        # Only used for vertebrates at the moment
        maximum_gene_length => 100000,
    };
}


=head2 pipeline_analyses

 Arg [1]    : None
 Description: Returns a hashref containing the analyses to run
 Returntype : Hashref
 Exceptions : None

=cut

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name        => 'RunSamples',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -input_ids        => [ {} ],
      -flow_into         => {
                              '1' => ['SpeciesFactoryGeneSample','SpeciesFactoryVEPSample'],
                            },
    },
    {
      -logic_name       => 'SpeciesFactoryVEPSample',
      -module           => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -parameters       => {
                             division     => $self->o('vep_division'),
                             species      => $self->o('vep_species'),
                             run_all      => $self->o('run_all'),
                             meta_filters => $self->o('meta_filters'),
                           },
      -max_retry_count  => 0,
      -flow_into        => {
                             '2' => ['GenerateVEPSample']
                           },
      -rc_name          => 'mem',
    },
    {
      -logic_name       => 'SpeciesFactoryGeneSample',
      -module           => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -parameters       => {
                             species      => $self->o('gene_species'),
                             division     => $self->o('gene_division'),
                             run_all      => $self->o('run_all'),
                             antispecies  => $self->o('antispecies'),
                             meta_filters => $self->o('meta_filters'),
                           },
      -max_retry_count  => 0,
      -flow_into        => {
                             '2' => ['CheckMetadata']
                           },
      -rc_name          => 'mem',
    },
    { -logic_name  => 'CheckMetadata',
      -module      => 'Bio::EnsEMBL::Production::Pipeline::Common::CheckAssemblyGeneset',
      -parameters  => {
          skip_metadata_check => $self->o('skip_metadata_check'),
          release => $self->o('ensembl_release')
       },
      -can_be_empty    => 1,
      -flow_into       => {
                      1 => WHEN(
                  '#new_assembly# >= 1 || #new_genebuild# >= 1' => 'GenerateSampleData'
              )},
      -max_retry_count => 1,
      -hive_capacity   => 20,
      -priority        => 5,
      -rc_name         => 'default',
    },
    {
      -logic_name       => 'GenerateSampleData',
      -module           => 'Bio::EnsEMBL::Production::Pipeline::SampleData::GenerateSampleData',
      -max_retry_count  => 1,
      -parameters      =>  {
                              maximum_gene_length => $self->o('maximum_gene_length'),
                           },
      -hive_capacity   => 50,
      -batch_size      => 10,
      -flow_into        => {
                             '1' => ['RunDataChecks'],
                             '-1' => ['GenerateSampleData_25GB'],
                           },
      -rc_name          => 'mem',
    },
    {
      -logic_name       => 'GenerateSampleData_25GB',
      -module           => 'Bio::EnsEMBL::Production::Pipeline::SampleData::GenerateSampleData',
      -max_retry_count  => 1,
      -parameters      =>  {
                              maximum_gene_length => $self->o('maximum_gene_length'),
                           },
      -hive_capacity   => 50,
      -batch_size      => 10,
      -flow_into        => {
                             '1' => ['RunDataChecks'],
                           },
      -rc_name          => 'mem_high',
    },
    {
      -logic_name  => "GenerateVEPSample",
      -module      => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -meadow_type => 'LSF',
      -parameters  => {
          'cmd'      =>
              'perl #base_dir#/ensembl-variation/scripts/misc/generate_vep_examples.pl $(#db_srv# details script) -species #species# -version #release#',
          'db_srv'   => $self->o('db_srv'),
          'release'  => $self->o('ensembl_release'),
          'base_dir' => $self->o('base_dir')
      },
      -rc_name     => 'mem',
      -analysis_capacity => 30,
      -flow_into        => {
                            '1' => ['RunDataChecks']
                           },
    },
    {
      -logic_name      => 'RunDataChecks',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters      => {
                            datacheck_names => ['ControlledMetaKeys', 'DisplayableSampleGene', 'MetaKeyCardinality', 'MetaKeyFormat'],
                            history_file    => $self->o('history_file'),
                            registry_file   => $self->o('registry'),
                            failures_fatal  => 1,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 50,
      -batch_size      => 10,
      -rc_name         => 'normal',
    },
  ];
}

sub resource_classes {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::resource_classes},
    'mem_high'    => {'LSF' => '-q production-rh74 -M 25000 -R "rusage[mem=25000]"'},
  }
}

1;
