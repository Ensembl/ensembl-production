=pod
=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

Hive pipeline to load all required ontologies into a dedicated mysql database
The pipeline will create a database named from current expected release number, load expected ontologies from OLS,
Check and compute terms closure.

=head1 LICENSE
    Copyright [2016-2018] EMBL-European Bioinformatics Institute
    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
         http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.
=head1 CONTACT
    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates
=cut


package Bio::EnsEMBL::Production::Pipeline::PipeConfig::OLSLoad_conf;

use strict;
use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');
use warnings FATAL => 'all';

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
  my ($self) = @_;

  return {
      %{$self->SUPER::default_options},
      ## General parameters
      'output_dir'    => '/nfs/nobackup/ensembl/' . $self->o('ENV', 'USER') . '/ols_loader/' . $self->o('pipeline_name'),
      'base_dir'      => $self->o('ENV', 'BASE_DIR'),
      'srv_cmd'       => undef,
      'wipe_all'      => 0,
      'wipe_one'      => 1,
      'verbosity'     => 2,
      'ols_load'      => 50,
      'ens_version'   => $self->o('ENV', 'ENS_VERSION'),
      'db_name'       => "ensembl_ontology_" . $self->o('ens_version'),
      'mart_db_name'  => 'ontology_mart_' . $self->o('ens_version'),
      'pipeline_name' => 'ols_ontology_' . $self->o('ens_version'),
      'db_url'        => $self->o('db_host') . $self->o('db_name'),
      'ontologies'    => []
  }
}


=head2 pipeline_wide_parameters
=cut

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
      %{$self->SUPER::pipeline_wide_parameters},
      'base_dir'     => $self->o('base_dir'),
      'db_name'      => $self->o('db_name'),
      'db_host'      => $self->o('db_host'),
      'db_url'       => $self->o('db_url'),
      'ens_version'  => $self->o('ens_version'),
      'wipe_all'     => $self->o('wipe_all'),
      'wipe_one'     => $self->o('wipe_one'),
      'srv'          => $self->o('srv'),
      'mart_db_name' => $self->o('mart_db_name'),
      'output_dir'   => $self->o('output_dir'),
      'verbosity'    => $self->o('verbosity'),
      'ontologies'   => $self->o('ontologies')
  };
}

=head2 pipeline_analyses
=cut

sub pipeline_analyses {
  my ($self) = @_;
  return [
      {
          -logic_name      => 'step_init',
          -input_ids       => [ {
              'input_id_list' => '#expr([map { {ontology_name => $_} } @{#ontologies#}])expr#',
          } ],
          -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
          -max_retry_count => 1,
          -flow_into       => {
              1 => WHEN(
                  '#wipe_all#' => [ 'reset_db' ],
                  ELSE [ 'create_db' ]
              )
          }
      },
      {
          -logic_name      => 'reset_db',
          -module          => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
          -parameters      => {
              db_conn => $self->o('db_host'),
              sql     => [ 'DROP DATABASE IF EXISTS ' . $self->o('db_name') ]
          },
          -max_retry_count => 1,
          -flow_into       => [ 'create_db' ],
          -max_retry_count => 1,
      },
      {
          -logic_name      => 'create_db',
          -module          => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
          -parameters      => {
              db_conn => $self->o('db_host'),
              sql     => [ 'CREATE DATABASE IF NOT EXISTS ' . $self->o('db_name') ]
          },
          -max_retry_count => 1,
          -flow_into       => [ 'ontologies_factory' ],
          -max_retry_count => 1,
      },
      {
          -logic_name => 'ontologies_factory',
          -module     => 'Bio::EnsEMBL::Hive::Examples::Factories::RunnableDB::GrabN',
          -flow_into  => {
              # To "fold", the fan requires access to its parent's parameters, via either INPUT_PLUS or the parameter stack
              '2->A' => { 'ontology_load' => INPUT_PLUS },
              'A->1' => WHEN('#_list_exhausted#' => [ 'compute_closure' ], ELSE [ 'ontologies_factory' ])
          }
      },
      {
          -logic_name        => 'ontology_load',
          -module            => 'bio.ensembl.ontology.hive.OLSOntologyLoader',
          -language          => 'python3',
          -analysis_capacity => 20,
          -rc_name           => 'default',
          -parameters        => {
              -db_url     => $self->o('db_url'),
              -output_dir => $self->o('output_dir'),
              -log_level  => $self->o('verbosity'),
          },
          -flow_into         => [ 'ontology_term_load_factory' ]
      },
      {
          -logic_name => 'ontology_term_load_factory',
          -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
          -parameters => {
              'inputlist'    => '#expr([0..#nb_terms#])expr#',
              'step'         => 1000,
              'column_names' => [ 'term_index' ]
          },
          -flow_into  => {
              '2->A' => { 'ontology_term_load' => INPUT_PLUS },
              'A->1' => [ 'ontology_report' ]
          },
      },
      {
          -logic_name      => 'dummy',
          -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
          -max_retry_count => 1,
      },
      {
          -logic_name        => 'ontology_term_load',
          -module            => 'bio.ensembl.ontology.hive.OLSTermsLoader',
          -language          => 'python3',
          -analysis_capacity => $self->o('ols_load'),
          -rc_name           => 'default',
          -parameters        => {
              -db_url     => $self->o('db_url'),
              -output_dir => $self->o('output_dir'),
              -log_level  => $self->o('verbosity'),
          }
      },
      {
          -logic_name      => 'ontology_report',
          -module          => 'bio.ensembl.ontology.hive.OLSImportReport',
          -language        => 'python3',
          -max_retry_count => 1,
          -rc_name         => 'default',
          -parameters      => {
              -output_dir => $self->o('output_dir')
          }
      },
      {
          -logic_name      => 'compute_closure',
          -module          => 'Bio::EnsEMBL::Production::Pipeline::OntologiesLoad::ComputeClosure',
          -max_retry_count => 1,
          -rc_name         => '32GB',
          -flow_into       => {
              1 => [ 'add_subset_map' ]
          },
      },
      {
          -logic_name  => 'add_subset_map',
          -module      => 'Bio::EnsEMBL::Production::Pipeline::OntologiesLoad::AddSubsetMap',
          -meadow_type => 'LSF',
          -rc_name     => '32GB',
          -flow_into   => [ 'mart_load' ]
      },
      {
          -logic_name  => 'mart_load',
          -module      => 'Bio::EnsEMBL::Production::Pipeline::OntologiesLoad::MartLoad',
          -meadow_type => 'LSF',
          -rc_name     => '32GB',
          -parameters  => {
              mart => $self->o('mart_db_name'),
              srv  => $self->o('srv')
          }
      }
  ];
}

sub resource_classes {
  my $self = shift;
  return {
      'default' => { 'LSF' => '-q production-rh7 -n 4 -M 4000   -R "rusage[mem=4000]"' },
      '32GB'    => { 'LSF' => '-q production-rh7 -n 4 -M 32000  -R "rusage[mem=32000]"' },
      '64GB'    => { 'LSF' => '-q production-rh7 -n 4 -M 64000  -R "rusage[mem=64000]"' },
      '128GB'   => { 'LSF' => '-q production-rh7 -n 4 -M 128000 -R "rusage[mem=128000]"' },
      '256GB'   => { 'LSF' => '-q production-rh7 -n 4 -M 256000 -R "rusage[mem=256000]"' },
  }
}
1;