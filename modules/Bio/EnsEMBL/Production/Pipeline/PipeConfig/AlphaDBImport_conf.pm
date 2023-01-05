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

=head1 NAME

Bio::EnsEMBL:Production::Pipeline::PipeConfig::AlphaDBImport_conf:

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
            -logic_name => 'species_factory',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
            -input_ids  => [ {} ],
            -parameters => {
                species     => $self->o('species'),
                division    => $self->o('division'),
                antispecies => $self->o('antispecies'),
            },
            -flow_into  => {
                '2->A' => [ 'species_version' ],
                'A->1' => [ 'cleanup' ]
            },
            -rc_name    => '4GB',
        },
        {
            -logic_name => 'species_version',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::MetadataCSVersion',
            -flow_into  => {
                '2' => [ 'alpha_map' ],
            },
        },
        {
            -logic_name => 'alpha_map',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::AlphaFold::CreateAlphaFoldMapping',
            -parameters => {
                alphafold_data_dir => $self->o('alphafold_data_dir'),
                alphafold_mapfile_dir => $self->o('scratch_large_dir'),
            },
            -flow_into  => {
                '2->A' => [ 'load_alphadb' ],
                'A->2' => [ 'datacheck' ]
            },
            -rc_name    => 'dm',
        },
        {
            -logic_name => 'load_alphadb',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::AlphaFold::HiveLoadAlphaFoldDBProteinFeatures',
            -parameters => {
                rest_server => $self->o('rest_server'),
            },
            -rc_name    => '4GB',
        },
        {
            -logic_name => 'datacheck',
            -module     => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
            -parameters => {
                datacheck_names => [ 'CheckAlphafoldEntries' ],
            },
            -flow_into  => [ 'report' ],
            -rc_name    => '4GB',
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
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -max_retry_count   => 1,
            -parameters        => {
                cmd => 'rm -rf ' . $self->o('scratch_large_dir'),
            },
        },
    );

    return \@analyses;
}

1;
