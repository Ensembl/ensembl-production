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

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::GrantMySQL_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    # Database type factory
    group => [],

    # Named database factory
    dbname => [],

    # Multi database factory
    marts       => 1,
    compara     => 1,
    pan_ensembl => 1,

    username => 'anonymous', # Or 'ensro', with hostname = '%.ebi.ac.uk'
    hostname => '%',
  };
}

# Implicit parameter propagation throughout the pipeline.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    username => $self->o('username'),
    hostname => $self->o('hostname'),
  };
}

sub pipeline_analyses {
  my $self = shift @_;

  return [
    {
      -logic_name        => 'SetTgtUri',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -input_ids         => [ {} ],
      -parameters        => {
                              tgt => $self->o('tgt'),
                              cmd => 'echo -n $(#tgt# details url)',
                            },
      -flow_into         => {
                              '1' =>
                                {
                                  'GroupGrantFactory'   => {'tgt_uri' => '#stdout#'},
                                  'MultiDbGrantFactory' => {'tgt_uri' => '#stdout#'},
                                  'NamedDbGrantFactory' => {'tgt_uri' => '#stdout#'},                              
                                }
                            },
    },
    {
      -logic_name      => 'GroupGrantFactory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::MetadataDbFactory',
      -max_retry_count => 1,
      -parameters      => {
                            ensembl_release => $self->o('ensembl_release'),
                            group           => $self->o('group'),
                          },
      -flow_into       => {
                            '2' => [ 'GrantDatabase' ],
                          }
    },
    {
      -logic_name        => 'MultiDbGrantFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::MultiDbFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              ensembl_release => $self->o('ensembl_release'),
                              marts           => $self->o('marts'),
                              compara         => $self->o('compara'),
                              pan_ensembl     => $self->o('pan_ensembl'),
                            },
      -flow_into         => {
                              '2' => [ 'GrantDatabase' ],
                            },
    },
    {
      -logic_name        => 'NamedDbGrantFactory',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              inputlist    => $self->o('dbname'),
                              column_names => ['dbname'],
                            },
      -flow_into         => {
                              '2' => [ 'GrantDatabase' ],
                            },
    },
    {
      -logic_name        => 'GrantDatabase',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              db_conn => '#tgt_uri#',
                              sql     => 'GRANT select, show view ON `#dbname#`.* TO `#username#`@`#hostname#`',
                            },
    },
  ];
}

1;
