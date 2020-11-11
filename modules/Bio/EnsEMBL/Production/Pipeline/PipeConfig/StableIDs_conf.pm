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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::StableIDs_conf;

=head1 DESCRIPTION

Pipeline to generate ensembl_stable_ids database for both vertebrates
and non-vertebrates.
This is mainly used for the REST server but can also be used in API
calls, to figure out what database to use when fetching a stable ID.
It is useful for web for non-species specific pages, like
www.ensembl.org/id/ENSG00000139618
The pipeline runs a script:
  ensembl/misc-scripts/stable_id_lookup/populate_stable_id_lookup.pl

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::StableIDs_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},
        run_from => [], # 'st1', 'st3', 'st4'
        db_name  => 'ensembl_stable_ids',
        db_url   => $self->o('srv_url') . $self->o('db_name'),
        release  => $self->o('ensembl_release'),
        email    => $ENV{'USER'} . '@ebi.ac.uk'
    }
}

sub pipeline_create_commands {
    my ($self) = @_;

    return [
        @{$self->SUPER::pipeline_create_commands},
        'mkdir -p ' . $self->o('output_dir')
    ];
}

sub resource_classes {
    my ($self) = @_;

    return {
        %{$self->SUPER::resource_classes},
        '8GB'  => { 'LSF' => '-q production-rh74 -M 8000 -R "rusage[mem=8000,scratch=1000]"' },
        '32GB' => { 'LSF' => '-q production-rh74 -M 32000 -R "rusage[mem=32000,scratch=1000]"' },
    }
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
        {
            -logic_name => 'cleanup_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -input_ids  => [ {} ],
            -parameters => {
                db_conn => $self->o('srv_url'),
                sql     => [ 'DROP DATABASE IF EXISTS ' . $self->o('db_name') . ';' ],
            },
            -flow_into  => [ 'create_db' ]
        },
        {
            -logic_name => 'create_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                db_conn => $self->o('srv_url'),
                sql     => [ 'CREATE DATABASE ' . $self->o('db_name') . ';' ],
            },
            -flow_into  => [ 'setup_db' ]
        },
        {
            -logic_name => 'setup_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters => {
                db_conn    => $self->o('db_url'),
                input_file => $self->o('base_dir') . '/ensembl/misc-scripts/stable_id_lookup/sql/tables.sql',
            },
            -flow_into  => [ 'populate_meta' ]
        },
        {
            -logic_name => 'populate_meta',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                db_conn => $self->o('db_url'),
                sql     => [ "INSERT INTO meta(species_id,meta_key,meta_value) VALUES (NULL,'schema_version','" . $self->o('release') . "')" ],
            },
            -flow_into  => [ 'stable_id_script_factory' ],
        },
        {
            -logic_name  => "stable_id_script_factory",
            -module      => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -meadow_type => 'LSF',
            -parameters  => {
                inputlist    => $self->o('run_from'),
                column_names => [ 'species_server' ]
            },
            -flow_into   => {
                '2->A' => [ 'stable_id_script' ],
                'A->1' => [ 'index' ],
            },
        },
        {
            -logic_name        => "stable_id_script",
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -meadow_type       => 'LSF',
            -parameters        => {
                cmd      => 'perl #base_dir#/ensembl/misc-scripts/stable_id_lookup/populate_stable_id_lookup.pl $(#db_srv# details script_l) $(#species_server# details script) -dbname #dbname# -version #release#',
                db_srv   => $self->o('db_srv'),
                dbname   => $self->o('db_name'),
                release  => $self->o('release'),
                base_dir => $self->o('base_dir')
            },
            -analysis_capacity => 1,
            -rc_name           => '32GB',
        },
        {
            -logic_name => 'index',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters => {
                db_conn    => $self->o('db_url'),
                input_file => $self->o('base_dir') . '/ensembl/misc-scripts/stable_id_lookup/sql/indices.sql',
            },
            -flow_into  => [ 'duplicates_report' ],
        },
        {
            -logic_name => 'duplicates_report',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::StableID::EmailReport',
            -parameters => {
                db_conn       => $self->o('db_url'),
                email         => $self->o('email'),
                pipeline_name => $self->o('pipeline_name'),
                output_dir    => $self->o('output_dir'),
            },
            -rc_name    => '8GB',
        }
    ];
}

1;
