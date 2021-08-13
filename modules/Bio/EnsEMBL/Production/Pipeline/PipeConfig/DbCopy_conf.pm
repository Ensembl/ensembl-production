=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DbCopy_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    # Primary function of pipeline is to copy, but can be used to just delete dbs
    copy_db => 1,

    # Database type factory
    group => [],

    # Named database factory
    dbname => [],

    # Multi database factory
    marts       => 0,
    compara     => 0,
    pan_ensembl => 0,

    # Copy service
    copy_service_uri => "http://production-services.ensembl.org/api/dbcopy/requestjob",
    username         => $self->o('ENV', 'USER'),

    # Drop databases from target, by default the same set that will be copied
    delete_db          => 0,
    delete_release     => undef,
    delete_group       => $self->o('group'),
    delete_dbname      => $self->o('dbname'),
    delete_marts       => $self->o('marts'),
    delete_compara     => $self->o('compara'),
    delete_pan_ensembl => $self->o('pan_ensembl'),

    # Update release number(s) in db name and apply patches after copying
    rename_db     => 0,
    base_dir      => $self->o('ENV', 'BASE_DIR'),
    rename_script => catdir($self->o('base_dir'), 'ensembl-production/scripts/get_new_db_name.pl'),
    patch_script  => catdir($self->o('base_dir'), 'ensembl-production/scripts/apply_patches.pl'),
  };
}

# Implicit parameter propagation throughout the pipeline.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    username => $self->o('username'),
  };
}

sub pipeline_analyses {
  my $self = shift @_;

  return [
    {
      -logic_name        => 'DeleteAndCopy',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 1,
      -input_ids         => [ {} ],
      -parameters        => {
                              copy_db   => $self->o('copy_db'),
                              delete_db => $self->o('delete_db'),
                            },
      -flow_into         => {
                              '1->A' => WHEN('#delete_db#', [ 'Delete' ]),
                              'A->1' => [ 'CopyAndRename' ],
                            },
    },
    {
      -logic_name        => 'Delete',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              tgt => $self->o('tgt'),
                              cmd => 'echo -n $(#tgt# details url)',
                            },
      -flow_into         => {
                              '1' =>
                                {
                                  'GroupDeleteFactory'   => {'tgt_uri' => '#stdout#'},
                                  'MultiDbDeleteFactory' => {'tgt_uri' => '#stdout#'},
                                  'NamedDbDeleteFactory' => {'tgt_uri' => '#stdout#'},                              
                                }
                            },
    },
    {
      -logic_name        => 'CopyAndRename',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -max_retry_count   => 1,
      -parameters        => {
                              rename_db => $self->o('rename_db'),
                            },
      -flow_into         => {
                              '1->A' => WHEN('#copy_db#', [ 'Copy_1' ]),
                              'A->1' => WHEN('#rename_db#', [ 'Rename' ]),
                            },
    },
    {
      -logic_name        => 'Copy_1',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              src => $self->o('src'),
                              cmd => 'echo -n $(#src# details host-port)',
                            },
      -flow_into         => {
                              '1' => { 'Copy_2' => {'src_host' => '#stdout#'} }
                            },
    },
    {
      -logic_name        => 'Copy_2',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              tgt => $self->o('tgt'),
                              cmd => 'echo -n $(#tgt# details host-port)',
                            },
      -flow_into         => {
                              '1' => 
                                {
                                  'GroupCopyFactory'   => {'tgt_host' => '#stdout#'},
                                  'MultiDbCopyFactory' => {'tgt_host' => '#stdout#'},
                                  'NamedDbCopyFactory' => {'tgt_host' => '#stdout#'},                              
                                }
                            },
    },
    {
      -logic_name        => 'Rename',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              tgt => $self->o('tgt'),
                              cmd => 'echo -n $(#tgt# details url)',
                            },
      -flow_into         => {
                              '1' =>
                                {
                                  'GroupRenameFactory'   => {'tgt_uri' => '#stdout#'},
                                  'MultiDbRenameFactory' => {'tgt_uri' => '#stdout#'},
                                  'NamedDbRenameFactory' => {'tgt_uri' => '#stdout#'},                              
                                }
                            },
    },
    {
      -logic_name      => 'GroupDeleteFactory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::MetadataDbFactory',
      -max_retry_count => 1,
      -parameters      => {
                            ensembl_release => $self->o('delete_release'),
                            group           => $self->o('delete_group'),
                          },
      -flow_into       => {
                            '2' => [ 'DeleteDatabase' ],
                          }
    },
    {
      -logic_name        => 'MultiDbDeleteFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::MultiDbFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              ensembl_release => $self->o('delete_release'),
                              marts           => $self->o('delete_marts'),
                              compara         => $self->o('delete_compara'),
                              pan_ensembl     => $self->o('delete_pan_ensembl'),
                            },
      -flow_into         => {
                              '2' => [ 'DeleteDatabase' ],
                            },
    },
    {
      -logic_name        => 'NamedDbDeleteFactory',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              inputlist    => $self->o('delete_dbname'),
                              column_names => ['dbname'],
                            },
      -flow_into         => {
                              '2' => [ 'DeleteDatabase' ],
                            },
    },
    {
      -logic_name        => 'GroupCopyFactory',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              inputlist       => $self->o('group'),
                              column_names    => ['group'],
                              ensembl_release => $self->o('ensembl_release'),
                            },
      -flow_into         => {
                              '2' => { 'CopyDatabase' => {'src_incl_db' => '%_#group#%_#ensembl_release#_%'} },
                            },
    },
    {
      -logic_name        => 'MultiDbCopyFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::MultiDbFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              ensembl_release => $self->o('ensembl_release'),
                              marts           => $self->o('marts'),
                              compara         => $self->o('compara'),
                              pan_ensembl     => $self->o('pan_ensembl'),
                            },
      -flow_into         => {
                              '2' => { 'CopyDatabase' => {'src_incl_db' => '#dbname#'} },
                            },
    },
    {
      -logic_name        => 'NamedDbCopyFactory',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              inputlist    => $self->o('dbname'),
                              column_names => ['dbname'],
                            },
      -flow_into         => {
                              '2' => { 'CopyDatabase' => {'src_incl_db' => '#dbname#'} },
                            },
    },
    {
      -logic_name      => 'GroupRenameFactory',
      -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::MetadataDbFactory',
      -max_retry_count => 1,
      -parameters      => {
                            ensembl_release => $self->o('ensembl_release'),
                            group           => $self->o('group'),
                          },
      -flow_into       => {
                            '2' => [ 'RenameDatabase_1' ],
                          }
    },
    {
      -logic_name        => 'MultiDbRenameFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::MultiDbFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              ensembl_release => $self->o('ensembl_release'),
                              marts           => $self->o('marts'),
                              compara         => $self->o('compara'),
                              pan_ensembl     => $self->o('pan_ensembl'),
                            },
      -flow_into         => {
                              '2' => [ 'RenameDatabase_1' ],
                            },
    },
    {
      -logic_name        => 'NamedDbRenameFactory',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -max_retry_count   => 1,
      -parameters        => {
                              inputlist    => $self->o('dbname'),
                              column_names => ['dbname'],
                            },
      -flow_into         => {
                              '2' => [ 'RenameDatabase_1' ],
                            },
    },
    {
      -logic_name        => 'DeleteDatabase',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
      -max_retry_count   => 1,
      -parameters        => {
                              db_conn => '#tgt_uri#',
                              sql     => 'DROP DATABASE IF EXISTS #dbname#',
                            },
    },
    {
        -logic_name    => 'CopyDatabase',
        -module        => 'ensembl.production.hive.ProductionDBCopy',
        -language      => 'python3',
        -parameters    => {
                            endpoint => $self->o('copy_service_uri'),
                            method   => 'post',
                            payload  => q/{
                              "user": "#username#",
                              "src_host": "#src_host#",
                              "tgt_host": "#tgt_host#",
                              "src_incl_db": "#src_incl_db#"
                            }/,
                          },
    },
    {
      -logic_name        => 'RenameDatabase_1',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              rename_script => $self->o('rename_script'),
                              cmd => 'echo -n $(perl #rename_script# #dbname#)',
                            },
      -flow_into         => {
                              '1' => { 'RenameDatabase_2' => {'new_dbname' => '#stdout#'} },
                            },
    },
    {
      -logic_name        => 'RenameDatabase_2',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              tgt => $self->o('tgt'),
                              cmd => 'rename_db #tgt# #dbname# #new_dbname#',
                            },
      -flow_into         => {
                              '1' => [ 'ApplyPatches' ],
                            },
    },
    {
      -logic_name        => 'ApplyPatches',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -max_retry_count   => 1,
      -parameters        => {
                              tgt => $self->o('tgt'),
                              base_dir => $self->o('base_dir'),
                              patch_script => $self->o('patch_script'),
                              cmd => 'perl #patch_script# $(#tgt# details script) -dbname #new_dbname# -basedir #base_dir#',
                            },
    },
  ];
}

1;
