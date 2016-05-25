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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::InterProScan::InterProScan_ensembl_conf

=head1 DESCRIPTION

=head1 AUTHOR

 Thomas Maurel

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::InterProScan_ensembl_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::InterProScan_conf');
use File::Spec::Functions qw(catdir);
use Bio::EnsEMBL::Hive::Version 2.2;

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


    required_externalDb => [
      'KEGG_Enzyme',
      'MetaCyc',
      'Reactome',
      'UniPathWay',
    ],


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

sub resource_classes {
  my ($self) = @_;

  return {
#    'i5_local_computation' => {'LSF' => '-q production-rh6 -n 4 -R "select[gpfs]"' },
    'default' 			   => {'LSF' => '-q production-rh6' },
    'i5_local_computation' => {'LSF' => '-q production-rh6 -n 4' },
  };
}

1;

