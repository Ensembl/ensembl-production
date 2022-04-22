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
 
=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL:Production::Pipeline::PipeConfig::AlphaDBImport_conf:

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::AlphaDBImport_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;



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
        pipe_db_host => undef,
        pipe_db_port => undef
    };
}


sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},
        rest_server => $self->o('rest_server'),
        base_path   => $self->o('base_path')
    }
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},
        'mkdir -p '.$self->o('pipeline_dir'),
        'mkdir -p '.$self->o('scratch_large_dir')
    ];
}

sub pipeline_analyses {
    my ($self) = @_;

    my @analyses = (
        {
            -logic_name => 'load_params',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
            -input_ids  => [ {} ],
            -flow_into  => {

                '2' => [ 'metadata' ],
            },
            -parameters => {
                species     => $self->o('species'),
                division    => $self->o('division'),
                antispecies => [],

            },
            -rc_name    => '4GB',
        },
        {
            -logic_name => 'metadata',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::MetadataCSVersion',
            -flow_into  => {
                '2->A' => [ 'load_alphadb' ],
                'A->1' => [ 'Datacheck' ]
            },
        },
        {
            -logic_name => 'load_alphadb',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::AlphaFold::HiveLoadAlphaFoldDBProteinFeatures',
            -parameters => {
                rest_server => $self->o('rest_server'),
                output_path => $self->o('scratch_large_dir')
            },
            -rc_name    => '4GB',
        },
        {
            -logic_name => 'Datacheck',
            -module     => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
            -parameters => {
                datacheck_names => [ 'CheckAlphafoldEntries' ],
            },
            -flow_into  => {
                '1' => [ 'Notify' ],
            },
            -rc_name    => '4GB',
        },
        {
            -logic_name        => 'Notify',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::EmailNotify',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -parameters        => {
                email         => $self->o('email'),
                pipeline_name => $self->o('pipeline_name'),
            },
        },
    );

    return \@analyses;
}

1;
