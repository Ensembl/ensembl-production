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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::LoadFamily_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

sub default_options {
  my ($self) = @_;

  return {
    %{ $self->SUPER::default_options() },

    pipeline_name => 'load_family',

    species      => [],
    division     => [],
    antispecies  => [],
    run_all      => 0,
    meta_filters => {},

    logic_names => [ 'hamap', 'panther', 'hmmpanther' ]
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return [
    {
      -logic_name => 'create_families',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::LoadFamily::CreateFamilies',
      -input_ids  => [ {} ],
      -parameters => {
                      species      => $self->o('species'),
                      division     => $self->o('division'),
                      antispecies  => $self->o('antispecies'),
                      run_all      => $self->o('run_all'),
                      meta_filters => $self->o('meta_filters'),
                      logic_names  => $self->o('logic_names')                          
                     },
      -flow_into  => {
                      2 => ['add_members'],
                     },
    },
    {
      -logic_name => 'add_members',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::LoadFamily::AddFamilyMembers',
      -parameters => { 
                      division    => $self->o('division'),
                      logic_names => $self->o('logic_names')
                     },
      -analysis_capacity => 20,
    },
  ];
}

1;
