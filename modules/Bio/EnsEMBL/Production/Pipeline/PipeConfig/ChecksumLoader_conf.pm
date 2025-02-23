=pod
=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 LICENSE
    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016-2024] EMBL-European Bioinformatics Institute
    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
         http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.
=head1 CONTACT
    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates
=cut


package Bio::EnsEMBL::Production::Pipeline::PipeConfig::ChecksumLoader_conf;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');
use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
        pipeline_name => 'checksum_loader',
        metadata_uri  => undef,
        species              => [],
        antispecies          => [],
        division             => [],
        run_all              => 0,
        dbname               => [],
        meta_filters         => {},
        hash_types           => [],
    };
}
sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},
    ];
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},
        hive_use_param_stack => 1,
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},
    };
}



sub pipeline_analyses {
    my ($self) = @_;
    return [
        #db_factory
        {
            -logic_name        => 'Dummy',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -max_retry_count   => 1,
            -parameters        => {},
            -flow_into         => 'DbFactory_core',
            -rc_name           => 'default',
            -input_ids       => [ {} ],
        },

        {
      -logic_name      => 'DbFactory_core',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
      -max_retry_count => 1,
      -parameters      => {
                shout_db_not_found_in_registry =>1,
                species      => $self->o('species'),
                antispecies  => $self->o('antispecies'),
                division     => $self->o('division'),
                run_all      => 1,  #$self->o('run_all'),
                dbname       => $self->o('dbname'),
                meta_filters => $self->o('meta_filters'),
                          },
      -hive_capacity   => -1,
      -max_retry_count => 1,
      -flow_into        => {2 => 'uri_generator'},
      -rc_name           => 'default',
        },
        {
            -logic_name        => 'uri_generator',
            -module            => 'Bio::EnsEMBL::Production::Pipeline::Checksum::CreateURI',
            -max_retry_count   => 1,
            -rc_name           => 'default',
            -flow_into        => {2 => 'checksum_transfer'},

        },
        {
            -logic_name        => 'checksum_transfer',
            -module            => 'ensembl.production.hive.ensembl_genome_metadata.ChecksumTransfer',
            -language        => 'python3',
            -max_retry_count   => 1,
            -analysis_capacity => 1,
            -parameters        => {
                metadata_uri   => $self->o('metadata_uri'),
            },
            -rc_name           => 'default',
        }

    ];
}
1;
