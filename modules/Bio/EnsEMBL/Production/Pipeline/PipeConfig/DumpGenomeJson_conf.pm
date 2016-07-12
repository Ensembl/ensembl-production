
=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License"); you
may not use this file except in compliance with the License.  You may
obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied.  See the License for the specific language governing
permissions and limitations under the License.

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpGenomeJson_conf;

use strict;
use warnings;
use Data::Dumper;
use base qw/Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf/;

sub resource_classes {
  my ($self) = @_;
  return {
      'default' => { 'LSF' => '-q production-rh6' },
      'himem' =>
        { 'LSF' => '-q production-rh6 -M 32000 -R "rusage[mem=32000]"' }
  };
}

=head2 default_options

    Description : Implements default_options() interface method of
    Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that is used to
    initialize default options.

=cut

sub default_options {
  my ($self) = @_;
  return {
    %{ $self->SUPER::default_options()
      },    # inherit other stuff from the base class
    pipeline_name => 'dump_genomes',
    species       => [],
    division      => [],
    run_all       => 0,
    antispecies   => [],
    meta_filters  => {},
    force_update  => 0,
    contigs       => 1,
    variation     => 1,
    base_path     => '.',
    metadata_dba  => 'ensembl_metadata' };
}

sub pipeline_analyses {
  my ($self) = @_;
  return [ {
           -logic_name => 'SpeciesFactory',
           -module =>
             'Bio::EnsEMBL::Production::Pipeline::BaseSpeciesFactory',
           -max_retry_count => 1,
           -input_ids       => [ {} ],
           -parameters      => {
                            species         => $self->o('species'),
                            antispecies     => $self->o('antispecies'),
                            division        => $self->o('division'),
                            run_all         => $self->o('run_all'),
                            meta_filters    => $self->o('meta_filters'),
                            chromosome_flow => 0,
                            variation_flow  => 0 },
           -flow_into     => { '2' => ['DumpGenomeJson'], },
           -hive_capacity => 1,
           -meadow_type   => 'LOCAL', }, {
           -logic_name => 'DumpGenomeJson',
           -module =>
             'Bio::EnsEMBL::Production::Pipeline::JSON::DumpGenomeJson',
           -hive_capacity => 50,
           -wait_for      => ['SpeciesFactory'],
           -flow_into     => { -1 => 'DumpGenomeJsonHiMem', },
           -rc_name       => 'default', }, {
           -logic_name => 'DumpGenomeJsonHiMem',
           -module =>
             'Bio::EnsEMBL::Production::Pipeline::JSON::DumpGenomeJson',
           -hive_capacity => 50,
           -wait_for      => ['SpeciesFactory'],
           -rc_name       => 'himem' } ];
} ## end sub pipeline_analyses

sub beekeeper_extra_cmdline_options {
  my $self = shift;
  return "-reg_conf " . $self->o("registry");
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
    %{ $self->SUPER::pipeline_wide_parameters()
      },    # inherit other stuff from the base class
    base_path    => $self->o('base_path'),
    metadata_dba => $self->o('metadata_dba') };
}

1;

