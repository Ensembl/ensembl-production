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


package Bio::EnsEMBL::Production::Pipeline::PipeConfig::OntologyMySqlLoad_conf;

use strict;
use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');
use warnings FATAL => 'all';

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},
        ## General parameters
        'output_dir'    => '/nfs/nobackup/ensembl/' . $self->o('ENV', 'USER') . '/ols_loader/' . $self->o('pipeline_name'),
        'base_dir'      => $self->o('ENV', 'BASE_DIR'),
        'srv_cmd'       => undef,
        'pipeline_name' => 'ols_ontology_loading',
        'run_mart'      => 1,
        'wipe_all'      => 1,
        'skip_go'       => 0,
        'verbose'       => 0,
        'ens_version'   => $self->o('ENV', 'ENS_VERSION'),
        'db_name'       => "ensembl_ontology_" . $self->o('ens_version'),
        'mart_db_name'  => 'ontology_mart_' . $self->o('ens_version'),
        'db_url'        => $self->o('db_host') . $self->o('db_name'),
        'ontologies'    => [ 'so', 'pato', 'hp', 'vt', 'efo', 'po', 'eo', 'to', 'chebi', 'pr', 'fypo', 'peco', 'bfo',
            'bto', 'cl', 'cmo', 'eco', 'mp', 'ogms', 'uo' ]
    }
}


=head2 pipeline_wide_parameters
=cut

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'run_mart'     => $self->o('run_mart'),
        'base_dir'     => $self->o('base_dir'),
        'db_name'      => $self->o('db_name'),
        'db_host'      => $self->o('db_host'),
        'db_url'       => $self->o('db_url'),
        'ens_version'  => $self->o('ens_version'),
        'wipe_all'     => $self->o('wipe_all'),
        'srv'          => $self->o('srv'),
        'mart_db_name' => $self->o('mart_db_name'),
    };
}


=head2 pipeline_analyses
=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {
            -logic_name      => 'step_init',
            -input_ids       => [ {} ],
            -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -meadow_type     => 'LOCAL',
            -max_retry_count => 1,
            -flow_into       => {
                1 => WHEN(
                    '#wipe_all# == 1'                   => [ 'reset_db' ],
                    '#wipe_all# == 0 && #skip_go# == 1' => [ 'ontologies_factory' ],
                    '#wipe_all# == 0 && #skip_go# == 0' => [ 'load_go_ontology' ]
                )
            },
        },
        {
            -logic_name      => 'reset_db',
            -module          => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -meadow_type     => 'LOCAL',
            -parameters      => {
                db_conn => $self->o('db_host'),
                sql     => [ 'DROP DATABASE IF EXISTS ' . $self->o('db_name'), 'CREATE DATABASE ' . $self->o('db_name') ]
            },
            -max_retry_count => 1,
            -flow_into       => {
                1 => WHEN(
                    '#skip_go#' => [ 'ontologies_factory' ],
                    ELSE [ 'load_go_ontology' ]
                )
            },
            -max_retry_count => 1,
        },
        # load GO ontology first, init_db once and load main ontology
        {
            -logic_name => 'load_go_ontology',
            -module     => 'bio.ensembl.ontology.OLSHiveLoader',
            -language   => 'python3',
            -parameters => {
                db_url        => $self->o('db_url'),
                ontology_name => 'go',
                'wipe'        => 1
            },
            -flow_into  => [ 'ontologies_factory' ],
        },
        {
            -logic_name  => 'ontologies_factory',
            -module      => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -meadow_type => 'LOCAL ',
            -parameters  => {
                inputlist    => $self->o('ontologies'),
                column_names => [ 'ontology_name' ]
            },
            -flow_into   => {
                '2->A' => [ 'ontology_load' ],
                'A->1' => [ 'compute_closure' ]
            },
        },
        {
            -logic_name        => 'ontology_load',
            -module            => 'bio.ensembl.ontology.OLSHiveLoader',
            -language          => 'python3',
            -analysis_capacity => 4,
            -parameters        => {
                db_url => $self->o('db_url'),
                wipe        => 1
            },
        },
        {
            -logic_name      => 'compute_closure',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::OntologiesMySqlLoad::ComputeClosure',
            -max_retry_count => 1, # use per-analysis limiter
            -flow_into       => {
                1 => [ 'add_subset_map' ],
            },
        },
        {
            -logic_name => 'add_subset_map',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::OntologiesMySqlLoad::AddSubsetMap',
            -flow_into  => {
                1 => WHEN(
                    '#run_mart#' => [ 'mart_load' ],
                ),
            },
        },
        {
            -logic_name => 'mart_load',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::OntologiesMySqlLoad::MartLoad',
            -parameters => {
                mart => $self->o('mart_db_name'),
                srv  => $self->o('srv')
            }
        }
    ];
}

1;