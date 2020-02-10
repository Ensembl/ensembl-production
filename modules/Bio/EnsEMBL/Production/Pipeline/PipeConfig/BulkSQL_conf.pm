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
    
    run_datachecks     => 0,
    history_file       => undef,
    output_dir         => undef,
    config_file        => undef,
    datacheck_names    => [],
    datacheck_patterns => [],
    datacheck_groups   => [],
    datacheck_types    => [],
    old_server_uri     => undef,
  };
}

sub pipeline_wide_parameters {
 my ($self) = @_;
 
 return {
   %{$self->SUPER::pipeline_wide_parameters},
   'out_file'       => $self->o('out_file'),
   'unique_rows'    => $self->o('unique_rows'),
   'run_datachecks' => $self->o('run_datachecks'),
 };
}

sub pipeline_analyses {
  my $self = shift @_;
  
  my $output_file = '#out_file#_#species#' if $self->o('out_file');
  
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
                            '2->A' => ['DbCmd'],
                            'A->1' => ['ProcessResults'],
                          },
    },
    
    {
      -logic_name        => 'DbCmd',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbCmd',
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -parameters        => {
                              append      => [qw(-N)],
                              db_type     => $self->o('db_type'),
                              input_file  => $self->o('sql_file'),
                              output_file => $output_file,
                            },
      -batch_size        => 10,
      -rc_name           => 'normal',
      -flow_into         => WHEN('#run_datachecks#' => ['RunDataChecks']),
    },
    
    {
      -logic_name        => 'RunDataChecks',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -parameters        => {
                              history_file       => $self->o('history_file'),
                              output_dir         => $self->o('output_dir'),
                              config_file        => $self->o('config_file'),
                              datacheck_names    => $self->o('datacheck_names'),
                              datacheck_patterns => $self->o('datacheck_patterns'),
                              datacheck_groups   => $self->o('datacheck_groups'),
                              datacheck_types    => $self->o('datacheck_types'),
                              old_server_uri     => $self->o('old_server_uri'),
                              failures_fatal     => 1,
                            },
      -rc_name           => 'normal',
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
