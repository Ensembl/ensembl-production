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

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::MySQLDumping_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

sub default_options {
  my ($self) = @_;
  return {
      %{$self->SUPER::default_options},
      ## General parameters
      'user'            => $self->o('user'),
      'pass'            => "",
      'host'            => $self->o('host'),
      'port'            => $self->o('port'),
      'meta_user'       => $self->o('meta_user'),
      'meta_host'       => $self->o('meta_host'),
      'meta_port'       => $self->o('meta_port'),
      'meta_database'   => $self->o('meta_database'),
      'base_dir'        => $self->o('ensembl_cvs_root_dir'),
      'pipeline_name'   => 'mysql_dumping',
      'division'        => [],
      'base_output_dir' => '/hps/nobackup2/production/ensembl/ensprod/release_dumps/',
      'release'         => $self->o('release'),
      ## 'DbDumpingFactory' parameters
      'database'        => [],
      'isGrch37'        => 0,
      'with_release' => 1
  }
}

sub pipeline_analyses {
  my ($self) = @_;
  return [
      {
          -logic_name      => 'DbDumpingFactory',
          -module          => 'Bio::EnsEMBL::Production::Pipeline::DatabaseDumping::DbDumpingFactory',
          -max_retry_count => 1,
          -input_ids       => [ {} ],
          -parameters      => {
              division        => $self->o('division'),
              database        => $self->o('database'),
              meta_user       => $self->o('meta_user'),
              meta_host       => $self->o('meta_host'),
              meta_port       => $self->o('meta_port'),
              meta_database   => $self->o('meta_database'),
              base_output_dir => $self->o('base_output_dir'),
              release         => $self->o('release'),
              user            => $self->o('user'),
              password        => $self->o('pass'),
              host            => $self->o('host'),
              port            => $self->o('port'),
              isGrch37        => $self->o('isGrch37'),
              with_release    => $self->o('with_release')
          },
          -flow_into       => {
              1 => 'DatabaseDump',
          }
      },
      {
          -logic_name        => 'DatabaseDump',
          -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
          -meadow_type       => 'LSF',
          -parameters        => {
              'cmd'      =>
                  '#base_dir#/ensembl-production/modules/Bio/EnsEMBL/Production/Utils/MySQLDumping.sh  #database# #output_dir# #host# #user# #port# #password#',
              'user'     => $self->o('user'),
              'password' => $self->o('pass'),
              'host'     => $self->o('host'),
              'port'     => $self->o('port'),
              'base_dir' => $self->o('base_dir')
          },
          -rc_name           => '4GB',
          -analysis_capacity => 10,
          -flow_into       => {
              1 => 'DbCheckSum',
          }
      },
      {
          -logic_name        => 'DbCheckSum',
          -parameters => {
                dir => "#output_dir#/#database#"
          },
          -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::ChecksumGenerator',
          -analysis_capacity => 10,
          -priority => 5,
            -flow_into       => {
              1 => 'DumpCheck',
          }
      },
      {
          -logic_name        => 'DumpCheck',
          -module            => 'Bio::EnsEMBL::Production::Pipeline::DatabaseDumping::MySQLDumpsCheck',
          -parameters        => {
              'user'     => $self->o('user'),
              'password' => $self->o('pass'),
              'host'     => $self->o('host'),
              'port'     => $self->o('port')
          },
          -analysis_capacity => 10
      },
  ];
}

1;
