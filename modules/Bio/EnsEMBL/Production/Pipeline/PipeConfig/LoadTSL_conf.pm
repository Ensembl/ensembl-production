=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::LoadTSL_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub default_options {
  my ($self) = @_;

  return {
    %{ $self->SUPER::default_options() },

    species => [],

    tsl_url => 'http://hgwdev.gi.ucsc.edu/~markd/gencode/tsl-handoff/',
  };
}

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
    'mkdir -p '.$self->o('pipeline_dir'),
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
                            species => $self->o('species'),
                          },
      -flow_into       => {
                            '2' => ['FetchTSLFile'],
                          }
    },

    {
      -logic_name      => 'FetchTSLFile',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::AttributeAnnotation::FetchTSLFile',
      -max_retry_count => 1,
      -parameters      => {
                            tsl_url      => $self->o('tsl_url'),
                            pipeline_dir => $self->o('pipeline_dir')
                          },
      -flow_into       => {
                            '3' => ['LoadTSL'],
                          }
    },

    {
      -logic_name      => 'LoadTSL',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::AttributeAnnotation::LoadTSL',
      -max_retry_count => 1,
      -flow_into       => ['Critical_Datachecks']
    },

    {
      -logic_name      => 'Critical_Datachecks',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -max_retry_count => 1,
      -parameters      => {
                            datacheck_names => ['AttribValuesExist'],
                            config_file     => $self->o('config_file'),
                            failures_fatal  => 1,
                          },
      -flow_into       => ['Advisory_Datachecks']
    },

    {
      -logic_name      => 'Advisory_Datachecks',
      -module          => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -max_retry_count => 1,
      -parameters      => {
                            datacheck_names => ['TSLCoverage'],
                            config_file     => $self->o('config_file'),
                            failures_fatal  => 0,
                          },
      -flow_into       => {
                            '4' => 'DatacheckFailureNotification'
                          },
    },

    {
      -logic_name        => 'DatacheckFailureNotification',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::EmailNotify',
      -max_retry_count   => 1,
      -parameters        => {
                              'email' => $self->o('email')
                            },
   },

  ];
}

1;
