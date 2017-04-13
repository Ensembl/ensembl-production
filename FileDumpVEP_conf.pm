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

Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpVEP_conf

=head1 DESCRIPTION

Dump and check VEP files.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpVEP_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::FileDump_conf');

use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'file_dump_vep_'.$self->o('ensembl_release'),

    # For species with variation can create an extra tabix-convert tar.gz file,
    # for the web interface & REST API use in preference to non-converted ones.
    # Don't need this complication (yet), so don't bother.
    # convert => 1,

    # Don't change this unless you know what you're doing...
    region_size => 1e6,
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('pipeline_dir'),
  ];
}

sub pipeline_wide_parameters {
 my ($self) = @_;
 
 return {
   %{$self->SUPER::pipeline_wide_parameters},
   'pipeline_dir'    => $self->o('pipeline_dir'),
   'ensembl_release' => $self->o('ensembl_release'),
   'eg_version'      => $self->o('eg_version'),
   'region_size'     => $self->o('region_size'),
 };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name        => 'FileDumpVEP',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 0,
      -input_ids         => [ {} ],
      -parameters        => {},
      -flow_into         => {
                              '1' => ['VEPSpeciesFactory'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'VEPSpeciesFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::VEPSpeciesFactory',
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
                              '2->A' => ['CreateDumpJobs'],
                              'A->2' => ['CopySynonyms'],
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'CreateDumpJobs',
      -module            => 'Bio::EnsEMBL::VEP::Pipeline::DumpVEP::CreateDumpJobs',
      -analysis_capacity => 20,
      -max_retry_count   => 0,
      -parameters        => {
                              eg => 1,
                            },
      -rc_name           => 'normal',
      -flow_into         => {
                              '3' => ['vep_core'],
                              '5' => ['vep_variation'],
                            },
    },

    {
      -logic_name        => 'vep_core',
      -module            => 'Bio::EnsEMBL::VEP::Pipeline::DumpVEP::Dumper::Core',
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -parameters        => {},
      -rc_name           => 'normal',
    },
    
    {
      -logic_name        => 'vep_variation',
      -module            => 'Bio::EnsEMBL::VEP::Pipeline::DumpVEP::Dumper::Variation',
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -can_be_empty      => 1,
      -parameters        => {
                              convert => 0,
                            },
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'CopySynonyms',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 0,
      -parameters        =>
        {
          cmd => 'cp #pipeline_dir#/synonyms/#species#_#assembly#_chr_synonyms.txt '.
                 '   #pipeline_dir#/#species#/#eg_version#_#assembly#/chr_synonyms.txt',
        },
      -rc_name           => 'normal',
      -flow_into         => ['MergeInfoFiles'],
    },

    {
      -logic_name        => 'MergeInfoFiles',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 0,
      -parameters        => 
        {
          cmd => 'cat #pipeline_dir#/#species#/#eg_version#_#assembly#/info.txt_* > '.
                 '    #pipeline_dir#/#species#/#eg_version#_#assembly#/info.txt; '.
                 'rm  #pipeline_dir#/#species#/#eg_version#_#assembly#/info.txt_*;'
        },
      -rc_name           => 'normal',
      -flow_into         => ['ValidateVEP'],
    },

    {
      -logic_name        => 'ValidateVEP',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::ValidateVEP',
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -parameters        => {
                              type    => 'core',
                              convert => 0,
                            },
      -rc_name           => 'normal',
    },

  ];
}

1;
