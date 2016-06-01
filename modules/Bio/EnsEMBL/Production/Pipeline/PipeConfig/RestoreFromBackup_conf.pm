=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::EGPipeline::PostCompara::PipeConfig::RestoreFromBackup_conf

=head1 DESCRIPTION

automatically restore backup tables

=head1 AUTHOR

 Thomas Maurel

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::PipeConfig::RestoreFromBackup_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);
use Bio::EnsEMBL::Hive::Version 2.3;

sub default_options {
  my ($self) = @_;

  return {
    # inherit from the base class
    %{ $self->SUPER::default_options() },

    pipeline_name  => $self->o('hive_dbname'),

    species       => [],
    antispecies   => [],
    division      => [],
    run_all       => 0,

    #output directory
    output_dir        => '/nfs/nobackup/ensemblgenomes/'.$self->o('ENV', 'USER').'/workspace/'.$self->o('ENV','USER').'_PostCompara_'.$self->o('ensembl_release'),
    # List of table to be backed up
    dump_tables => ['xref', 'object_xref', 'ontology_xref', 'external_synonym','gene'],

    # Don't fall over if someone uses 'hive_pass' instead of 'hive_password'
    hive_password => $self->o('hive_pass'),

    'pipeline_db' => {
        -host   => $self->o('hive_host'),
        -port   => $self->o('hive_port'),
        -user   => $self->o('hive_user'),
        -pass   => $self->o('hive_password'),
        -dbname => $self->o('hive_dbname'),
        -driver => 'mysql',
      },
  };
}

# Ensures species output parameter gets propagated implicitly
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack'  => 1,
  };
}

sub beekeeper_extra_cmdline_options {
  my ($self) = @_;

  return
    ' -reg_conf ' . $self->o('registry')
  ;
}

sub pipeline_analyses {
  my $self = shift @_;


  return [

    { -logic_name      => 'SpeciesFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -parameters      => {
                            species     => $self->o('species'),
                            antispecies => $self->o('antispecies'),
                            division    => $self->o('division'),
                            run_all     => $self->o('run_all'),
                          },
      -input_ids       => [ {} ],
      -max_retry_count => 1,
      -rc_name         => 'default',
      -flow_into       => { '2'    => 'RestoreBackups' },
    },

    { -logic_name      => 'RestoreBackups',
      -module          => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::RestoreBackups',
      -hive_capacity   => 50,
      -parameters      => {
                            output_dir => $self->o('output_dir'),
                            dump_tables  => $self->o('dump_tables'),
                          },
      -rc_name         => 'default',
    },

  ];
}

sub resource_classes {
  my ($self) = @_;

  return {
#    'i5_local_computation' => {'LSF' => '-q production-rh6 -n 4 -R "select[gpfs]"' },
    'default'                      => {'LSF' => '-q production-rh6' },
    'i5_local_computation' => {'LSF' => '-q production-rh6 -n 4' },
  };
}

1;
