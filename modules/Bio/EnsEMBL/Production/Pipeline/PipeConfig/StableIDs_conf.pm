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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::StableIDs_conf;

=head1 DESCRIPTION

Pipeline to generate ensembl_stable_ids database for both vertebrates
and non-vertebrates.
This is mainly used for the REST server but can also be used in API
calls, to figure out what database to use when fetching a stable ID.
It is useful for web for non-species specific pages, like
www.ensembl.org/id/ENSG00000139618

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::StableIDs_conf;

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
    division     => [],
    run_all      => 0,
    antispecies  => [],
    meta_filters => {},

    incremental => 0,

    email_report => 1,

    db_name => 'ensembl_stable_ids',
    db_url  => $self->o('srv_url') . $self->o('db_name'),

    table_sql => $self->o('base_dir').'/ensembl-production/modules/Bio/EnsEMBL/Production/Pipeline/StableID/sql/table.sql',
    index_sql => $self->o('base_dir').'/ensembl-production/modules/Bio/EnsEMBL/Production/Pipeline/StableID/sql/index.sql',
  }
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
    %{ $self->SUPER::pipeline_wide_parameters() },
    incremental => $self->o('incremental'),
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name  => 'StableIDs',
      -module      => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -input_ids   => [ {} ],
      -parameters  => {},
      -flow_into   => WHEN(
                        '#incremental#' => ['PopulateMeta'],
                      ELSE
                        ['CreateDb']
                      )
    },
    {
      -logic_name  => 'CreateDb',
      -module      => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
      -parameters  => {
                        db_conn => $self->o('srv_url'),
                        db_name => $self->o('db_name'),
                        sql => [
                          'DROP DATABASE IF EXISTS #db_name#;',
                          'CREATE DATABASE #db_name#;'
                        ],
                      },
      -flow_into   => ['CreateTables']
    },
    {
      -logic_name  => 'CreateTables',
      -module      => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
      -parameters  => {
                        db_conn    => $self->o('db_url'),
                        input_file => $self->o('table_sql'),
                      },
      -flow_into   => ['PopulateMeta']
    },
    {
      -logic_name  => 'PopulateMeta',
      -module      => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
      -parameters  => {
                        db_conn => $self->o('db_url'),
                        release => $self->o('ensembl_release'),
                        sql => [
                          "DELETE FROM meta WHERE meta_key = 'schema_version';",
                          "INSERT INTO meta (species_id,meta_key,meta_value) VALUES (NULL, 'schema_version', '#release#');"
                        ],
                      },
      -flow_into   => ['DbFactory_core'],
    },
    {
      -logic_name      => 'DbFactory_core',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
      -max_retry_count => 1,
      -parameters      => {
                            species      => $self->o('species'),
                            antispecies  => $self->o('antispecies'),
                            division     => $self->o('division'),
                            run_all      => $self->o('run_all'),
                            meta_filters => $self->o('meta_filters'),
                            group        => 'core',
                          },
      -flow_into       => {
                            '2->A' => ['Populate'],
                            'A->1' => ['DbFactory_otherfeatures'],
                          }
    },
    {
      -logic_name      => 'DbFactory_otherfeatures',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
      -max_retry_count => 1,
      -parameters      => {
                            species      => $self->o('species'),
                            antispecies  => $self->o('antispecies'),
                            division     => $self->o('division'),
                            run_all      => $self->o('run_all'),
                            meta_filters => $self->o('meta_filters'),
                            group        => 'otherfeatures',
                          },
      -flow_into       => {
                            '2->A' => ['Populate'],
                            'A->1' => WHEN(
                                        '#incremental#' => ['Optimize'],
                                      ELSE
                                        ['CreateIndexes']
                                      )
                          }
    },
    {
      -logic_name        => "Populate",
      -module            => 'Bio::EnsEMBL::Production::Pipeline::StableID::Populate',
      -analysis_capacity => 5,
      -batch_size        => 5,
      -max_retry_count   => 1,
      -parameters        => {
                              db_url      => $self->o('db_url'),
                              incremental => $self->o('incremental')
                            }
    },
    {
      -logic_name  => 'CreateIndexes',
      -module      => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
      -parameters  => {
                        db_conn    => $self->o('db_url'),
                        input_file => $self->o('index_sql'),
                      },
      -flow_into   => ['Optimize']
    },
    {
      -logic_name      => "Optimize",
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
      -max_retry_count => 1,
      -parameters      => {
                            db_conn => $self->o('db_url'),
                            sql => [
                              'OPTIMIZE TABLE archive_id_lookup;',
                              'OPTIMIZE TABLE species;',
                              'OPTIMIZE TABLE stable_id_lookup;'
                            ],
                            email_report => $self->o('email_report'),
                          },
      -flow_into       => WHEN('#email_report#' => ['EmailReport'])
    },
    {
      -logic_name  => 'EmailReport',
      -module      => 'Bio::EnsEMBL::Production::Pipeline::StableID::EmailReport',
      -parameters  => {
                        db_conn       => $self->o('db_url'),
                        email         => $self->o('email'),
                        pipeline_name => $self->o('pipeline_name'),
                        output_dir    => $self->o('pipeline_dir'),
                      }
    }
  ];
}

1;
