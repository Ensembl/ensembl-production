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

Pipeline to generate ensembl_stable_ids database for both vertebrates and non-vertebrates.
This is mainly used for the REST server but can also be used in the main API call, to figure out what database to refer to when fetching a stable ID. It is useful for web for non-species specific pages, like www.ensembl.org/id/ENSG00000139618 
The pipeline run the following script. ensembl/misc-scripts/stable_id_lookup/populate_stable_id_lookup.pl 
The hive pipeline is doing what used to be done in the script with the "create" and "create_index" subroutines

=head1 AUTHOR

 maurel@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::StableIDs_conf;

use strict;
use warnings;

#use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
# All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},
        vert_server     => 'st1',
        non_vert_server => 'st3',
        bacteria_server => 'st4',
        db_name         => 'ensembl_stable_ids',
        db_url          => $self->o('srv_url') . $self->o('db_name'),
    }
}

sub resource_classes {
    my $self = shift;
    return {
        'default' => { 'LSF' => '-q production-rh74 -n 4 -M 4000   -R "rusage[mem=4000]"' },
        '32GB'    => { 'LSF' => '-q production-rh74 -n 4 -M 32000  -R "rusage[mem=32000]"' },
        '64GB'    => { 'LSF' => '-q production-rh74 -n 4 -M 64000  -R "rusage[mem=64000]"' },
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
                sql     => [
                    'DROP DATABASE IF EXISTS ' . $self->o('db_name') . ';' ],
            },
            -rc_name    => 'default',
            -flow_into  => [ 'create_db' ]
        },
        {
            -logic_name => 'create_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                db_conn => $self->o('srv_url'),
                sql     => [
                    'CREATE DATABASE ' . $self->o('db_name') . ';' ],
            },
            -rc_name    => 'default',
            -flow_into  => [ 'setup_db' ]
        },
        {
            -logic_name => 'setup_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters => {
                db_conn    => $self->o('db_url'),
                input_file => $self->o('base_dir') . '/ensembl/misc-scripts/stable_id_lookup/sql/tables.sql',
            },
            -rc_name    => 'default',
            -flow_into  => [ 'populate_meta' ]
        },
        {
            -logic_name => 'populate_meta',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                db_conn => $self->o('db_url'),
                sql     => [
                    "INSERT INTO meta(species_id,meta_key,meta_value) VALUES (NULL,'schema_version','" . $self->o('release') . "')" ],
            },
            -rc_name    => 'default',
            -flow_into  => [ 'stable_id_non_vert' ],
        },
        { -logic_name    => "stable_id_non_vert",
            -module      => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -meadow_type => 'LSF',
            -parameters  => {
                'cmd'            =>
                    'perl #base_dir#/ensembl/misc-scripts/stable_id_lookup/populate_stable_id_lookup.pl $(#db_srv# details script_l) $(#species_server# details script) -dbname #dbname# -version #release#',
                'db_srv'         => $self->o('db_srv'),
                'dbname'         => $self->o('db_name'),
                'species_server' => $self->o('non_vert_server'),
                'release'        => $self->o('release'),
                'base_dir'       => $self->o('base_dir') },
            -flow_into   => [ 'stable_id_vert' ],
            -rc_name     => '32GB',
        },
        { -logic_name    => "stable_id_vert",
            -module      => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -meadow_type => 'LSF',
            -parameters  => {
                'cmd'            =>
                    'perl #base_dir#/ensembl/misc-scripts/stable_id_lookup/populate_stable_id_lookup.pl $(#db_srv# details script_l) $(#species_server# details script) -dbname #dbname# -version #release#',
                'db_srv'         => $self->o('db_srv'),
                'dbname'         => $self->o('db_name'),
                'species_server' => $self->o('vert_server'),
                'release'        => $self->o('release'),
                'base_dir'       => $self->o('base_dir') },
            -flow_into   => [ 'stable_id_bacteria' ],
            -rc_name     => '32GB',
        },
        { -logic_name    => "stable_id_bacteria",
            -module      => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -meadow_type => 'LSF',
            -parameters  => {
                'cmd'            =>
                    'perl #base_dir#/ensembl/misc-scripts/stable_id_lookup/populate_stable_id_lookup.pl $(#db_srv# details script_l) $(#species_server# details script)  -dbname #dbname# -version #release#',
                'db_srv'         => $self->o('db_srv'),
                'dbname'         => $self->o('db_name'),
                'species_server' => $self->o('bacteria_server'),
                'release'        => $self->o('release'),
                'base_dir'       => $self->o('base_dir') },
            -flow_into   => [ 'index' ],
            -rc_name     => '32GB',
        },
        {
            -logic_name => 'index',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters => {
                db_conn    => $self->o('db_url'),
                input_file => $self->o('base_dir') . '/ensembl/misc-scripts/stable_id_lookup/sql/indices.sql',
            },
            -rc_name    => 'default',
        },
    ];
}



1;
