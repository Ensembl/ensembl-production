=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::Empty;

=head1 DESCRIPTION

=head1 AUTHOR 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::Empty;

use strict;
use warnings;
use Bio::EnsEMBL::Hive::Version 2.3;
use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{ $self->SUPER::default_options() },               # inherit other stuff from the base class

        'pipeline_db' => {  
            -host   => $self->o('hive_host'),
            -port   => $self->o('hive_port'),
            -user   => $self->o('hive_user'),
            -pass   => $self->o('hive_password'),
            -dbname => $self->o('hive_dbname'),
        },
    };
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters()},
  };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},
    ];
}

sub beekeeper_extra_cmdline_options {
  my ($self) = @_;
  return 
      ' -reg_conf ' . $self->o('registry')
  ;
}

sub pipeline_analyses {
    my ($self) = @_;
    
    return [];
}

sub resource_classes {
  my ($self) = @_;
  return {
    #'default' => { 'LSF' => '-q production-rh6' },
    #'32GB'    => { 'LSF' => '-q production-rh6 -M  32000 -R "rusage[mem=32000]"' },
    #'64GB'    => { 'LSF' => '-q production-rh6 -M  64000 -R "rusage[mem=64000]"' },
    #'128GB'   => { 'LSF' => '-q production-rh6 -M 128000 -R "rusage[mem=128000]"' },
  };
}

1;

