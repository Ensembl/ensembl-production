=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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

Bio::EnsEMBL::EGPipeline::PipeConfig::BulkSQL_conf

=head1 DESCRIPTION

Pipeline to run the same SQL across a set of databases.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::BulkSQL_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},
    
    pipeline_name => 'bulk_sql_'.$self->o('ensembl_release'),
    
    species         => [],
    division        => [],
    run_all         => 0,
    antispecies     => [],
    core_flow       => 2,
    meta_filters    => {},
    
    sql => [],
  };
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
  my $self = shift;
  return "-reg_conf ".$self->o("registry");
}

sub pipeline_analyses {
  my ($self) = @_;
  
  return [
    {
      -logic_name  => 'ScheduleSpecies',
      -module      => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -input_ids   => [ {} ],
      -parameters  => {
                       species         => $self->o('species'),
                       antispecies     => $self->o('antispecies'),
                       division        => $self->o('division'),
                       run_all         => $self->o('run_all'),
                       core_flow       => $self->o('core_flow'),
                       chromosome_flow => 0,
                       regulation_flow => 0,
                       variation_flow  => 0,
                       meta_filters    => $self->o('meta_filters'),
                      },
      -flow_into   => {
                       '2' => 'RunSQL',
                      },
      -rc_name     => 'normal-rh7',
    },

    {
      -logic_name      => 'RunSQL',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::SqlCmd',
      -parameters      => {
                            sql => $self->o('sql'),
                          },
      -max_retry_count => 1,
      -hive_capacity   => 10,
      -rc_name         => 'normal-rh7',
    },

  ];
}

1;
