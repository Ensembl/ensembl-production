=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::PipeConfig::BulkSelectSQL_conf

=head1 DESCRIPTION

Pipeline to run SQL commands across a set of databases,
and aggregate the results if appropriate.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::BulkSQL_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'bulk_sql',
    
    species      => [],
    taxons       => [],
    division     => [],
    antispecies  => [],
    antitaxons   => [],
    run_all      => 0,
    meta_filters => {},
    
    db_type => 'core',
    
    sql_file    => undef,
    out_file    => undef,
    unique_rows => 1,
    
  };
}

sub pipeline_wide_parameters {
 my ($self) = @_;
 
 return {
   %{$self->SUPER::pipeline_wide_parameters},
   'out_file'    => $self->o('out_file'),
   'unique_rows' => $self->o('unique_rows'),
 };
}

sub pipeline_analyses {
  my $self = shift @_;
  
  return [
    {
      -logic_name      => 'DbFactory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
      -max_retry_count => 0,
      -input_ids       => [ {} ],
      -parameters      => {
                            species      => $self->o('species'),
                            taxons       => $self->o('taxons'),
                            division     => $self->o('division'),
                            antispecies  => $self->o('antispecies'),
                            antitaxons   => $self->o('antitaxons'),
                            run_all      => $self->o('run_all'),
                            meta_filters => $self->o('meta_filters'),
                            db_type      => $self->o('db_type'),
                          },
      -rc_name         => 'normal',
      -flow_into       => {
                            '2->A' => ['SqlExecute'],
                            'A->1' => ['ProcessResults'],
                          },
    },
    
    {
      -logic_name      => 'SqlExecute',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SqlExecute',
      -max_retry_count => 0,
      -parameters      => {
                            db_type  => $self->o('db_type'),
                            sql_file => $self->o('sql_file'),
                            out_file => $self->o('out_file').'_#species#',
                          },
      -batch_size      => 10,
      -hive_capacity   => 10,
      -rc_name         => 'normal',
    },
    
    {
      -logic_name      => 'ProcessResults',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count => 0,
      -parameters      => {},
      -rc_name         => 'normal',
      -flow_into       => WHEN('#out_file#' => ['AggregateResults']),
    },
    
    {
      -logic_name      => 'AggregateResults',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count => 0,
      -parameters      => {
                            cmd => 'cat #out_file#_* > #out_file#;'.
                                   'rm #out_file#_*;',
                          },
      -rc_name         => 'normal',
      -flow_into       => WHEN('#unique_rows#' => ['UniquifyResults']),
    },
    
    {
      -logic_name      => 'UniquifyResults',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count => 0,
      -parameters      => {
                            cmd => 'sort -u #out_file# > #out_file#.tmp;'.
                                   'mv #out_file#.tmp #out_file#;',
                          },
      -rc_name         => 'normal',
    },
    
  ];
}

1;
