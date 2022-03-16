=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneAutoComplete_conf;

=head1 DESCRIPTION

This pipeline create and populate the gene_autocomplete table inside the ensembl_website database
This table is used on the ensembl website region in detail, when you type a gene name in the "gene" box

=head1 AUTHOR

 maurel@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::GeneAutoComplete_conf;

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

    db_name => 'ensembl_autocomplete_'.$self->o('ensembl_release'),
    db_url  => $self->o('srv_url').$self->o('db_name'),

    table_sql => $self->o('base_dir').'/ensembl-production/modules/Bio/EnsEMBL/Production/Pipeline/GeneAutocomplete/sql/table.sql',
  }
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name  => 'GeneAutoComplete',
      -module      => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -input_ids   => [ {} ] ,
      -parameters  => {
                        incremental => $self->o('incremental'),
                      },
      -flow_into   => WHEN(
                        '#incremental#' => ['DbFactory'],
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
                          'CREATE DATABASE IF NOT EXISTS #db_name#;'
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
      -flow_into   => ['DbFactory']
    },
    {
      -logic_name      => 'DbFactory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
      -max_retry_count => 1,
      -parameters      => {
                            species      => $self->o('species'),
                            antispecies  => $self->o('antispecies'),
                            division     => $self->o('division'),
                            run_all      => $self->o('run_all'),
                            meta_filters => $self->o('meta_filters'),
                          },
      -flow_into       => {
                            '2->A' => ['Populate'],
                            'A->1' => ['Optimize'],
                          }
    },
    {
      -logic_name        => "Populate",
      -module            => 'Bio::EnsEMBL::Production::Pipeline::GeneAutocomplete::Populate',
      -analysis_capacity => 5,
      -batch_size        => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              db_url => $self->o('db_url')
                            }
    },
    {
      -logic_name      => "Optimize",
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
      -max_retry_count => 1,
      -parameters      => {
                            db_conn => $self->o('db_url'),
                            sql => [
                              'OPTIMIZE TABLE gene_autocomplete;'
                            ],
                          }
    },
  ];
}

1;
