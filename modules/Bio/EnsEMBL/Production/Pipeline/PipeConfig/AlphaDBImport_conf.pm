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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

 Bio::EnsEMBL:Production::Pipeline::PipeConfig::AlphaDBImport_conf

=head1 SYNOPSIS

 Creates links from a protein to the AlphaFold structure prediction in a Core database

=head1 DESCRIPTION

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::AlphaDBImport_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.6;


=head2 default_options

 Arg [1]    : None
 Description: Create default hash for this configuration file
 Returntype : Hashref
 Exceptions : None

=cut

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options()},
        rest_server  => 'https://www.ebi.ac.uk/gifts/api/',
        user_r       => 'ensro',
        species      => [],
        division     => [],
        run_all      => 0,
        antispecies  => [],
        password     => $ENV{EHIVE_PASS},
        user         => 'ensadmin',
        alphafold_data_file => '/nfs/ftp/public/databases/alphafold/accession_ids.csv',
        uniparc_data_file => '/nfs/ftp/public/databases/uniprot/current_release/knowledgebase/idmapping/idmapping_selected.tab.gz',
        gifts_dir    => '',
        pipeline_db  => {
            -driver => $self->o('hive_driver'),
            -host   => $self->o('pipe_db_host'),
            -port   => $self->o('pipe_db_port'),
            -user   => $self->o('user'),
            -pass   => $self->o('password'),
            -dbname => $self->o('dbowner').'_alphafold_'.$self->o('pipeline_name').'_pipe',
        },
    };
}

sub pipeline_create_commands {
    my ($self) = @_;

    return [
        @{$self->SUPER::pipeline_create_commands},
        'mkdir -p '.$self->o('scratch_large_dir'),
    ];
}

sub pipeline_analyses {
    my ($self) = @_;

    my @analyses = (
        {
            # branch out to the two copy jobs and the species factory
            -logic_name => 'start',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -input_ids       => [{}],
            -meadow_type     => 'LOCAL',
            -flow_into  => {
                '1' => [
                    'copy_alphafold',
                    'copy_uniparc',
                    'species_factory'
                ],
            },
        },
        {
            -logic_name => 'copy_alphafold',
            #-module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -parameters => {
                cmd => 'cp -f "' . $self->o('alphafold_data_file') . '" "' . $self->o('scratch_large_dir') . '"',
            },
            -flow_into  => {
                '1' => ['create_alphafold_db']
            },
            -rc_name    => 'dm',
        },
        {
            -logic_name => 'copy_uniparc',
            #-module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -parameters => {
                cmd => 'cp -f "' . $self->o('uniparc_data_file') . '" "' . $self->o('scratch_large_dir') . '"',
            },
            -flow_into  => {
                '1' => ['create_uniparc_db'],
            },
            -rc_name    => 'dm',
        },
        {
            -logic_name => 'create_alphafold_db',
            #-module     => 'Bio::EnsEMBL::Production::Pipeline::AlphaFold::CreateAlphaDB',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -parameters => {
                alphafold_db_dir => $self->o('scratch_large_dir'),
            },
            -rc_name    => '8GB',
        },
        {
            -logic_name => 'create_uniparc_db',
            #-module     => 'Bio::EnsEMBL::Production::Pipeline::AlphaFold::CreateUniparcDB',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -parameters => {
                uniparc_db_dir => $self->o('scratch_large_dir'),
            },
            -rc_name    => '8GB',
        },
        {
            -logic_name => 'species_factory',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::AlphaFold::NoMultiSpeciesFactory',
            -parameters => {
                species     => $self->o('species'),
                division    => $self->o('division'),
                antispecies => $self->o('antispecies'),
            },
            -flow_into  => {
                '2->A' => [ 'insert_features' ],
                'A->1' => [ 'cleanup' ]
            },
            -rc_name    => '500M',
        },
        {
            -logic_name => 'insert_features',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::AlphaFold::InsertProteinFeatures',
            -parameters => {
                rest_server => $self->o('rest_server'),
                db_dir => $self->o('scratch_large_dir'),
                gifts_dir => $self->o('gifts_dir'),
            },
            -wait_for => [
                'create_alphafold_db',
                'create_uniparc_db'
            ],
            -flow_into  => {
                '1' => [ 'datacheck' ]
            },
            -analysis_capacity => 20,
            -rc_name    => '4GB',
        },
        {
            -logic_name => 'datacheck',
            -module     => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
            -parameters => {
                datacheck_names => [ 'CheckAlphafoldEntries' ],
            },
            -flow_into  => 'report',
            -rc_name    => '200M',
        },
        {
            -logic_name        => 'report',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::EmailReport',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -parameters        => {
                dbname        => $self->o('pipeline_db')->{'-dbname'},
                email         => $self->o('email'),
            },
        },
        {
            -logic_name        => 'cleanup',
            #-module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -max_retry_count   => 1,
            -parameters        => {
                cmd => 'rm -rf ' . $self->o('scratch_large_dir'),
            },
        },
    );

    return \@analyses;
}

1;
