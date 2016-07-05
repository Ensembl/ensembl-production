=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::Pre_FASTA_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::FASTA_conf');

use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
  my ($self) = @_;
  return {
    # inherit other stuff from the base class
    %{ $self->SUPER::default_options() }, 

    ### OVERRIDE

    #'registry' => 'Reg.pm', # default option to refer to Reg.pm, should be full path
    #'base_path' => '', #where do you want your files

    # The types to emit
#    dump_types => ['dna','cdna'],

    # The databases to emit (defaults to core)
    db_types => [],

    # Specify species you really need to get running
    force_species => [],

    # As above but switched around. Do not process these names
    skip_logic_names => [],

    ### Indexers
    skip_wublast => 1,
    skip_wublast_masking => 1,

  };
}

sub pipeline_create_commands {
  my ($self) = @_;
  return [
    # inheriting database and hive tables' creation
    @{$self->SUPER::pipeline_create_commands},
  ];
}

## See diagram for pipeline structure
sub pipeline_analyses {
  my ($self) = @_;
  my $analyses = $self->SUPER::pipeline_analyses;
  return $analyses;
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  return $self->SUPER::pipeline_wide_parameters();
}

# override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
  my $self = shift;
  return $self->SUPER::beekeeper_extra_cmdline_options();
  return "-reg_conf ".$self->o("registry");
}

sub resource_classes {
  my $self = shift;
  return $self->SUPER::resource_classes;
}

1;
