=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DBCopyPatch_conf;

use strict;
use warnings;
# All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');
use Bio::EnsEMBL::Hive::Version 2.2;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use Cwd qw/getcwd/;

sub default_options {
  my ($self) = @_;

  return {
    # inherit other stuff from the base class
    %{ $self->SUPER::default_options() },

    'registry'      => '',
    'pipeline_name' => $self->o( 'ENV', 'USER' ) . '_DBCopyPatch_' .
      $self->o('ensembl_release'),
    'output_dir' => '/nfs/production/ensembl/production/' .
      $self->o( 'ENV', 'USER' ) . '/workspace/' .
      $self->o('pipeline_name'),

    # Set to '0' to skip copy & patch(s)
    #  default => ON (1)
    'by_species'  => 1,    #i.e others
    'by_division' => 1,    #i.e compara, marts, info, ontology

    'division'     => [],    # EB, EG, EPl, EPr, EM, EF
    'from_staging' => '',       # server to copy from
    'to_staging'   => '',       # server to copy to
    'base_dir'     => getcwd,

    # Email Report subject
    'subject' => $self->o('pipeline_name') .
      ' copy & patch has completed',

    # Access to the prod db
    'prod_db' => { -host   => 'mysql-eg-pan-prod.ebi.ac.uk',
                   -port   => '4276',
                   -user   => 'ensro',
                   -group  => 'production',
                   -dbname => 'ensembl_production', },

    'pipeline_db' => { -host   => $self->o('hive_host'),
                       -port   => $self->o('hive_port'),
                       -user   => $self->o('hive_user'),
                       -pass   => $self->o('hive_password'),
                       -dbname => $self->o('hive_dbname'),
                       -driver => 'mysql', }, };
} ## end sub default_options

sub pipeline_create_commands {
  my ($self) = @_;
  return [
    # inheriting database and hive tables' creation
    @{ $self->SUPER::pipeline_create_commands },
    'mkdir -p ' . $self->o('output_dir'), ];
}

# Ensures output parameters gets propagated implicitly
sub hive_meta_table {
  my ($self) = @_;

  return { %{ $self->SUPER::hive_meta_table },
           'hive_use_param_stack' => 1, };
}

# Override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
  my ($self) = @_;
  return ' -reg_conf ' . $self->o('registry'),;
}

# these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
    %{ $self->SUPER::pipeline_wide_parameters }
    ,    # here we inherit anything from the base class
    'pipeline_name' => $self->o('pipeline_name')
    ,    #This must be defined for the beekeeper to work properly
  };
}

sub resource_classes {
  my $self = shift;
  return {
    %{ $self->SUPER::resource_classes }
    ,    # inherit 'default' from the parent class
    '8GB_64GBTmp' => {
      'LSF' =>
        '-q production-rh74 -n 4 -M 8000  -R "rusage[mem=8000]" -R "rusage[tmp=64000]"'
    },
    '32GB' => {
      'LSF' => '-q production-rh74 -n 4 -M 32000  -R "rusage[mem=32000]"'
    },
    '64GB' => {
      'LSF' => '-q production-rh74 -n 4 -M 64000  -R "rusage[mem=64000]"'
    },
    '92GBTmp' =>
      { 'LSF' => '-q production-rh74 -n 4 -R "rusage[tmp=92000]"' }, };
}

sub pipeline_analyses {
  my ($self) = @_;

  my $pipeline_flow;

  if ( $self->o('by_species') && $self->o('by_division') ) {
    $pipeline_flow = [ 'job_factory_species', 'job_factory_division' ];
  }
  elsif ( $self->o('by_species') ) {
    $pipeline_flow = ['job_factory_species'];
  }
  elsif ( $self->o('by_division') ) {
    $pipeline_flow = ['job_factory_division'];
  }

  return [ {
      -logic_name    => 'backbone_fire_DBCopyPatch',
      -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -input_ids     => [ {} ],
      -rc_name       => 'default',
      -hive_capacity => -1,
      -flow_into     => { '1' => ['division_factory'], }, },

######## division_factory
    { -logic_name => 'division_factory',
      -module =>
        'Bio::EnsEMBL::Production::Pipeline::Release::DivisionFactory',
      -parameters => { 'division' => $self->o('division') ||
                         [ 'EG', 'EPl', 'EPr', 'EM', 'EF' ],
                       'prod_db' => $self->o('prod_db'),
                       'user'    => $self->o('user'), },
      -rc_name   => 'default',
      -flow_into => { '2' => $pipeline_flow, }, },

######## job_factory
    { -logic_name => 'job_factory_species',
      -module =>
'Bio::EnsEMBL::Production::Pipeline::Release::JobFactorySpecies',
      -rc_name   => 'default',
      -flow_into => { '2' => ['db_copy_patch'], }, },

    { -logic_name => 'job_factory_division',
      -module =>
'Bio::EnsEMBL::Production::Pipeline::Release::JobFactoryDivision',
      -rc_name   => 'default',
      -flow_into => { '2' => ['db_copy_patch'], }, },

######## copy & patch
    { -logic_name => 'db_copy_patch',
      -module =>
        'Bio::EnsEMBL::Production::Pipeline::Release::DBCopyPatch',
      -parameters => { 'base_dir'     => $self->o('base_dir'),
                       'from_staging' => $self->o('from_staging'),
                       'to_staging'   => $self->o('to_staging'), },
      -hive_capacity => 10,
      -flow_into     => { -1 => 'db_copy_patch_92GBTmp', }, },

    { -logic_name => 'db_copy_patch_92GBTmp',
      -module =>
        'Bio::EnsEMBL::Production::Pipeline::Release::DBCopyPatch',
      -parameters => { 'base_dir'     => $self->o('base_dir'),
                       'from_staging' => $self->o('from_staging'),
                       'to_staging'   => $self->o('to_staging'), },
      -hive_capacity => 10,
      -rc_name       => '92GBTmp', }, ];
} ## end sub pipeline_analyses

1;
