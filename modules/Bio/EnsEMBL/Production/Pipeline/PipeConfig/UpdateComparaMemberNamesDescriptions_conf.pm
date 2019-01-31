=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

The PipeConfig file for the pipeline that imports Gene names and Gene descriptions from Core databases
into the Compara database gene and seq members tables.

=cut


package Bio::EnsEMBL::Production::Pipeline::PipeConfig::UpdateComparaMemberNamesDescriptions_conf;

use strict;
use warnings;
use Bio::EnsEMBL::Registry;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::UpdateMemberNamesDescriptions;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'pipeline_name'   => 'Compara_member_description_update_'.$self->o('rel_with_suffix'),   # also used to differentiate submitted processes

        #Pipeline capacities:
        'update_capacity'                           => '5',

    };
}

# override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
    my $self = shift;
    return "-reg_conf ".$self->o("reg_conf");
}


sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}



sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

        '500Mb_job'    => { 'LSF' => [' -q production-rh7 -C0 -M500 -R"select[mem>500] rusage[mem=500]"'] },
    };
}


sub pipeline_analyses {
    my ($self) = @_;

    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::UpdateMemberNamesDescriptions::pipeline_analyses_member_names_descriptions($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [ {
        'compara_db'    => $self->o('compara_db'),
        } ];
    return $pipeline_analyses;
}


1;


