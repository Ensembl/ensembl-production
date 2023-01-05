=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 DESCRIPTION

Hive pipeline to load all required ontologies into a dedicated mysql database
The pipeline will create a database named from current expected release number, load expected ontologies from OLS,
Check and compute terms closure.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::OLSLoad_conf;

use strict;
use warnings FATAL => 'all';

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},
        
        ens_version   => $self->o('ENV', 'ENS_VERSION'),
        pipeline_name => 'ols_ontology_'.$self->o('ens_version'),

        base_dir => $ENV{'BASE_DIR'},

        ontologies   => [],
        wipe_all     => 0,
        wipe_one     => 1,
        verbosity    => 2,
        ols_load     => 1,

        db_name      => 'ensembl_ontology',
        mart_db_name => 'ontology_mart',
        db_url       => $self->o('srv_url').$self->o('db_name'),

        history_file => undef,
        old_server_uri => [],

        copy_service_uri => "https://services.ensembl.ebi.ac.uk:2000/api/dbcopy/requestjob",
        src_host         => undef,
        tgt_host         => undef,
        tgt_db_name      => $self->o('db_name').'_'.$self->o('ens_version'),
        tgt_mart_host    => undef,
        tgt_mart_db_name => $self->o('mart_db_name').'_'.$self->o('ens_version'),

        copy_service_payload =>
          '{'.
            '"src_host": "'.$self->o('src_host').'", '.
            '"src_incl_db": "'.$self->o('db_name').'", '.
            '"tgt_host": "'.$self->o('tgt_host').'", '.
            '"tgt_db_name": "'.$self->o('tgt_db_name').'", '.
            '"user": "'.$self->o('user').'"'.
          '}',

        copy_service_mart_payload =>
          '{'.
            '"src_host": "'.$self->o('src_host').'", '.
            '"src_incl_db": "'.$self->o('db_name').'", '.
            '"tgt_host": "'.$self->o('tgt_mart_host').'", '.
            '"tgt_db_name": "'.$self->o('tgt_mart_db_name').'", '.
            '"user": "'.$self->o('user').'"'.
          '}',
    }
}

# Prevent default assumption (from Base_conf) that a registry is required.
sub beekeeper_extra_cmdline_options {
  my ($self) = @_;

  return '';
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
        'ens_version'  => $self->o('ens_version'),
        'base_dir'     => $self->o('base_dir'),
        'ontologies'   => $self->o('ontologies'),
        'wipe_all'     => $self->o('wipe_all'),
        'wipe_one'     => $self->o('wipe_one'),
        'verbosity'    => $self->o('verbosity'),
        'db_name'      => $self->o('db_name'),
        'mart_db_name' => $self->o('mart_db_name'),
        'srv'          => $self->o('srv'),
        'db_url'       => $self->o('db_url'),
        'output_dir'   => $self->o('pipeline_dir'),
        'scratch_dir'  => $self->o('scratch_small_dir'),
    };
}

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
                db_conn => $self->o('srv_url'),
                sql     => [ 'DROP DATABASE IF EXISTS ' . $self->o('db_name') ]
            },
            -max_retry_count => 1,
            -flow_into       => [ 'create_db' ]
        },
        {
            -logic_name      => 'create_db',
            -module          => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters      => {
                db_conn => $self->o('srv_url'),
                sql     => [ 'CREATE DATABASE IF NOT EXISTS ' . $self->o('db_name') ]
            },
            -max_retry_count => 1,
            -flow_into       => [ 'init_meta' ]
        },
        {
            -logic_name      => 'init_meta',
            -module          => 'bio.ensembl.ontology.hive.OLSHiveLoader',
            -language        => 'python3',
            -max_retry_count => 1,
            -flow_into       => [ 'ontologies_factory' ]
        },
        {
            -logic_name => 'ontologies_factory',
            -module     => 'Bio::EnsEMBL::Hive::Examples::Factories::RunnableDB::GrabN',
            -flow_into  => {
                # To "fold", the fan requires access to its parent's parameters, via either INPUT_PLUS or the parameter stack
                '2->A' => { 'ontology_load' => INPUT_PLUS },
                'A->1' => WHEN('#_list_exhausted#' => [ 'phibase_init' ], ELSE [ 'ontologies_factory' ])
            }
        },
        {
            -logic_name        => 'ontology_load',
            -module            => 'bio.ensembl.ontology.hive.OLSOntologyLoader',
            -language          => 'python3',
            -analysis_capacity => 1,
            -rc_name           => '4GB',
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
                '2->A' => WHEN(
                    '#ontology_name# eq "PR"' => { 'ontology_term_load_light' => INPUT_PLUS },
                    ELSE { 'ontology_term_load' => INPUT_PLUS },
                ),
                'A->1' => [ 'ontology_report' ]
            },
        },
        {
            -logic_name        => 'ontology_term_load',
            -module            => 'bio.ensembl.ontology.hive.OLSTermsLoader',
            -language          => 'python3',
            -analysis_capacity => $self->o('ols_load'),
            -rc_name           => '4GB',
        },
        {
            -logic_name        => 'ontology_term_load_light',
            -module            => 'bio.ensembl.ontology.hive.OLSTermsLoader',
            -language          => 'python3',
            -analysis_capacity => 1,
            -rc_name           => '4GB',
        },
        {
            -logic_name      => 'ontology_report',
            -module          => 'bio.ensembl.ontology.hive.OLSImportReport',
            -language        => 'python3',
            -max_retry_count => 1,
            -rc_name         => '4GB',
        },
        {
            -logic_name      => 'phibase_init',
            -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -max_retry_count => 1,
            -flow_into       => {
                1 => WHEN(
                    '("PHI" ~~ #ontologies# and (#wipe_one# == 1 or #wipe_all# == 1))' => [ 'phibase_load_factory' ],
                    ELSE [ 'compute_closure' ]
                )
            }
        },
        {
            -logic_name => 'phibase_load_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'     => [ 0 .. 9999 ],
                'step'          => 2000,
                'ontology_name' => "PHI",
                'column_names'  => [ 'term_index' ]
            },
            -flow_into  => {
                '2->A' => [ 'phibase_load' ],
                'A->1' => [ 'compute_closure' ]
            }
        },
        {
            -logic_name      => 'phibase_load',
            -module          => 'bio.ensembl.ontology.hive.OLSLoadPhiBaseIdentifier',
            -language        => 'python3',
            -max_retry_count => 1,
            -rc_name         => '4GB',
            -parameters      => {
                'ontology_name' => "PHI",
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
            },
            -flow_into   => [ 'ontology_dc_critical', 'ontology_dc_advisory' ]
        },
        {
            -logic_name => 'ontology_dc_critical',
            -module     => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
            -parameters => {
                dbname           => $self->o('db_name'),
                datacheck_groups => ['ontologies'],
                datacheck_types  => ['critical'],
                history_file     => $self->o('history_file'),
                old_server_uri   => $self->o('old_server_uri'),
                registry_file    => $self->o('registry_file'),
                failures_fatal   => 1,
                tgt_host         => $self->o('tgt_host'),
                tgt_mart_host    => $self->o('tgt_mart_host'),
            },
            -flow_into => WHEN('defined #tgt_host#' => [ 'copy_database' ],
                          'defined #tgt_mart_host#' => [ 'copy_mart_database' ]
                          ),
        },
        {
            -logic_name => 'ontology_dc_advisory',
            -module     => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
            -parameters => {
                dbname           => $self->o('db_name'),
                datacheck_groups => ['ontologies'],
                datacheck_types  => ['advisory'],
                history_file     => $self->o('history_file'),
                old_server_uri   => $self->o('old_server_uri'),
                registry_file    => $self->o('registry_file'),
                failures_fatal   => 0
            },
            -flow_into  => {
                              '4' => 'email_dc_advisory'
                            },
        },
        {
            -logic_name => 'email_dc_advisory',
            -module     => 'Bio::EnsEMBL::DataCheck::Pipeline::EmailNotify',
            -parameters => {
                email         => $self->o('email'),
                pipeline_name => $self->o('pipeline_name'),
            },
        },
        {
            -logic_name    => 'copy_database',
            -module        => 'ensembl.production.hive.ProductionDBCopy',
            -language      => 'python3',
            -parameters    => {
                'endpoint' => $self->o('copy_service_uri'),
                'payload'  => $self->o('copy_service_payload'),
                'method'   => 'post',
            },
        },
        {
            -logic_name    => 'copy_mart_database',
            -module        => 'ensembl.production.hive.ProductionDBCopy',
            -language      => 'python3',
            -parameters    => {
                'endpoint' => $self->o('copy_service_uri'),
                'payload'  => $self->o('copy_service_mart_payload'),
                'method'   => 'post',
            },
            -rc_name     => "500M"
        },
    ];
}

1;
