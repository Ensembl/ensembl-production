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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpSpeciesForGOA_conf;

=head1 DESCRIPTION

=head1 AUTHOR

 mchakiachvili@ebi.ac.uk

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpSpeciesForGOA_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::Version 2.5;
use File::Spec::Functions qw(catdir);

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        output_base    => '/ebi/ftp/pub/databases/ensembl/projections',
        output_dirname => 'ensemblrapid',
        output_dir     => catdir($self->o('output_base'), lc($self->o('output_dirname'))),
        release_file   => catdir($self->o('output_dir'), 'release.txt'),

        species     => [],
        antispecies => [],
        division    => [],
        run_all     => 0,

        # Following parameters are not currently used
        method_link_type => 'ENSEMBL_ORTHOLOGUES',
        cleanup_dir      => 1,
    }
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},
        'mkdir -p ' . $self->o('output_dir'),
    ]
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
        {
            -logic_name      => 'SpeciesFactory',
            -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
            -max_retry_count => 1,
            -input_ids       => [ {} ],
            -parameters      => {
                species     => $self->o('species'),
                antispecies => $self->o('antispecies'),
                division    => $self->o('division'),
                run_all     => $self->o('run_all'),
            },
            -rc_name         => 'default',
            -flow_into       => [ 'SpeciesNoOrthologs' ],
        },
        #TODO Filter species to dump according to some configuration file somewhere or some metadata info to only dump
        # species with actually no orthologues.
        {
            -logic_name => 'SpeciesNoOrthologs',
            -module     => 'Bio::EnsEMBL::Production::Pipeline::Ortholog::SpeciesNoOrthologs',
            -parameters => {
                output_dir => $self->o('output_dir'),
                release    => $self->o('release')
            },
            -rc_name    => 'default',
            -flow_into  => [ 'CreateReleaseFile' ],
        },
        {
            -logic_name => 'CreateReleaseFile',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                cmd => 'echo -e "#output_dirname#\t#release#\t"$(date "+%Y/%m/%d %H:%m:%S") > #release_file#',
                output_dirname => $self->o('output_dirname'),
                release        => $self->o('release'),
                release_file   => $self->o('release_file'),
            },
            -rc_name    => 'default'
        }
        #TODO include wait and load GPAD from HERE
    ];
}

1;
