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

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::LoadRefget_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;
use File::Spec;

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options()},

        ## General parameters
        'release'        => $self->o('ensembl_release'),
        'pipeline_name'  => 'pipeline_refgetloader_' . $self->o('ensembl_release'),
        'web_email'      => '',
        'run_all'        => 0,
        'email'          => 'ensembl-production@ebi.ac.uk',
        ## 'job_factory' parameters
        'species'     => [],
        'antispecies' => [],
        'division'    => [],
        'dbname'      => undef,
        ## Checksum parameters
        'check_refget' => 0,
        'verify_checksums' => 1,
        'sequence_type'  => [],
    };
}

sub pipeline_create_commands {
    my ($self) = @_;

    return [
        @{$self->SUPER::pipeline_create_commands}
    ];
}

# Ensures output parameters gets propagated implicitly
sub hive_meta_table {
    my ($self) = @_;

    return {
        %{$self->SUPER::hive_meta_table},
        'hive_use_param_stack' => 1,
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'pipeline_name'  => $self->o('pipeline_name'),
        'release'        => $self->o('release'),
        'check_refget' => $self->o('check_refget'),
        'verify_checksums' => $self->o('verify_checksums'),
        'sequence_type' => $self->o('sequence_type'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
        {
            -logic_name    => 'init_checksum',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -input_ids     => [{}],
            -flow_into     => {'1->A' => 'species_factory', 'A->1' => 'email_report'}
        },
        {
            -logic_name => 'species_factory',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
            -parameters => {
                species     => $self->o('species'),
                antispecies => $self->o('antispecies'),
                division    => $self->o('division'),
                dbname      => $self->o('dbname'),
                run_all     => $self->o('run_all'),
            },
            -max_retry_count => 1,
            -flow_into       => {'2->A' => 'load_refget', 'A->2' => 'run_datacheck'},
        },
        {
            -logic_name         => 'load_refget',
            -module             => 'Bio::EnsEMBL::Production::Pipeline::Refget::RefgetLoader',
            -analysis_capacity  => 20,
        },
        {
            -logic_name        => 'run_datacheck',
            -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
            -max_retry_count   => 1,
            -analysis_capacity => 10,
            -batch_size        => 10,
            -parameters        => {
                datacheck_names => ['SequenceChecksum'],
                datacheck_types => ['critical'],
                registry_file   => $self->o('registry'),
                failures_fatal  => 1,
            },
        },
        {
            -logic_name => 'email_report',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
            -parameters => {
                'email'   => $self->o('email'),
                'subject' => 'Pipeline ' . $self->o('pipeline_name') . ' completed!',
                'text'    => 'Checksum value added to attrib tables'
            },
        },
    ];
}

1;

