
=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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
use Data::Dumper;
use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf')
  ; # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

=head2 default_options

    Description : Implements default_options() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that is used to initialize default options.

=cut

sub default_options {
  my ($self) = @_;

  return {
          %{ $self->SUPER::default_options() },    # inherit other stuff from the base class
          
          # name used by the beekeeper to prefix job names on the farm
          'pipeline_name' => 'load_family',
          
          ## 'job_factory' parameters
          'species'       => [],
          'antispecies'   => [],
          'division'      => [],
          'run_all'       => 0,
          'meta_filters'  => {},
          
          # logic names of family analyses
          'logic_names' => [ 'hamap', 'panther', 'hmmpanther' ]

  };
} ## end sub default_options

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
  my $self = shift;
  return "-reg_conf ".$self->o("registry");
}

sub resource_classes {
  my ($self) = @_;
  return {
         'default'      => {'LSF' => '-q production-rh7' }
  }
}

sub pipeline_analyses {
  my ($self) = @_;
  return [
	{ -logic_name => 'create_families',
	  -module =>
'Bio::EnsEMBL::Production::Pipeline::LoadFamily::CreateFamilies',
	  -analysis_capacity => 1,
          -parameters => {
                          species      => $self->o('species'),
                          antispecies  => $self->o('antispecies'),
                          division     => $self->o('division'),
                          run_all      => $self->o('run_all'),
                          meta_filters => $self->o('meta_filters'),
                          logic_names => $self->o('logic_names')                          
                         },
	  -input_ids         => [
                                 {}
                                 
                                ],
	  -flow_into => {
                         2 => ['add_members'],    # will create a fan of jobs
                        }, },
          
          { -logic_name => 'add_members',
            -module =>
            'Bio::EnsEMBL::Production::Pipeline::LoadFamily::AddFamilyMembers',
            -hive_capacity     => -1,      # turn off the reciprocal limiter
            -analysis_capacity => 20,      # use per-analysis limiter
            -parameters => { 
                            division     => $self->o('division'),
                            logic_names => $self->o('logic_names') },
            -input_ids => [
                           # (jobs for this analysis will be flown_into via branch-2 from 'start' jobs above)
                          ], }, ];
} ## end sub pipeline_analyses

1;

