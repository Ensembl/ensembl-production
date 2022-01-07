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

=cut

=pod 

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::PipeConfig::UpdateComparaMemberNamesDescriptions_conf

=head1 DESCRIPTION  

Import gene names and descriptions from Core databases
into the Compara database gene and seq members tables.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::UpdateComparaMemberNamesDescriptions_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Compara::PipeConfig::Parts::UpdateMemberNamesDescriptions;
use Bio::EnsEMBL::Registry;

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        pipeline_name   => 'compara_name_update_' . $self->o('rel_with_suffix'),

        update_capacity => '5',
    };
}

# Ensures that output parameters get propagated implicitly.
sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},
        'hive_use_param_stack' => 1,
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::UpdateMemberNamesDescriptions::pipeline_analyses_member_names_descriptions($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [ {
        'compara_db' => $self->o('compara_db'),
    } ];
    return $pipeline_analyses;
}

1;
