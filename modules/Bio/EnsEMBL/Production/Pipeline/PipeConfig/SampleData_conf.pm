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
        pipeline_name => 'sample_data_'.$self->o('release'),
        ## 'job_factory' parameters
        species       => [],
        antispecies   => [],
        division      => [],
        run_all       => 0,
        meta_filters  => {},
        history_file => undef,
        skip_metadata_check => 0,
        release => software_version(),
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
      -logic_name       => 'SpeciesFactory',
      -module           => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
      -input_ids        => [ {} ],
      -parameters       => {
                             species      => $self->o('species'),
                             division     => $self->o('division'),
                             run_all      => $self->o('run_all'),
                             antispecies  => $self->o('antispecies'),
                             meta_filters => $self->o('meta_filters'),
                           },
      -max_retry_count  => 0,
      -flow_into        => {
                             '2' => ['CheckMetadata']
                           },
      -rc_name          => 'normal',
    },
    { -logic_name  => 'CheckMetadata',
      -module      => 'Bio::EnsEMBL::Production::Pipeline::Common::CheckAssemblyGeneset',
      -parameters  => {
          skip_metadata_check => $self->o('skip_metadata_check'),
          release => $self->o('release')
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
                             '1' => ['RunDataChecks']
                           },
      -rc_name          => 'mem_high',
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
    'mem_high'    => {'LSF' => '-q production-rh74 -M 15000 -R "rusage[mem=15000]"'},
  }
}

1;
