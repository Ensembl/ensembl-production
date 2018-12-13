=pod 
=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION 

Hive pipeline to dump all the databases or a set of databases from a MySQL server
The pipeline will create a database directory, dump database files, dump sql schema file,
compress all the files and create a CHECKSUM file 

=head1 LICENSE
    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016-2018] EMBL-European Bioinformatics Institute
    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
         http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.
=head1 CONTACT
    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates
=cut


package Bio::EnsEMBL::Production::Pipeline::PipeConfig::MySQLDumping_conf;

use strict;
use warnings;
use Data::Dumper;
use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly
use Cwd;

sub resource_classes {
    my ($self) = @_;
    return { 'default' => { 'LSF' => '-q production-rh7' }};
}


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
        	   ## General parameters
        'user'     => $self->o('user'),
        'pass'     => $self->o('pass'),
        'host'     => $self->o('host'),
        'port'     => $self->o('port'),
        'meta_user'     => $self->o('meta_user'),
        'meta_host'     => $self->o('meta_host'),
        'meta_port'     => $self->o('meta_port'),
        'meta_database' => $self->o('meta_database'),
        'base_dir'  => $self->o('ensembl_cvs_root_dir'),
        'pipeline_name'  => 'mysql_dumping',
        'division' => [],
        'base_output_dir'     	   => '/nfs/nobackup/dba/sysmysql/',
        'vertebrates_release' => $self->o('vertebrates_release'),
        'non_vertebrates_release' => $self->o('non_vertebrates_release'),
        ## 'DbDumpingFactory' parameters
        'databases'    => [],
    }
}

=head2 pipeline_wide_parameters
=cut

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
    %{ $self->SUPER::pipeline_wide_parameters
      } # here we inherit anything from the base class, then add our own stuff
  };
}


=head2 pipeline_analyses
=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [
    {
      -logic_name        => 'DbDumpingFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::DatabaseDumping::DbDumpingFactory',
      -max_retry_count   => 1,
      -input_ids         => [ {} ],
      -parameters        => {
                              division        => $self->o('division'),
                              databases         => $self->o('databases'),
                              meta_user      => $self->o('meta_user'),
                              meta_host      => $self->o('meta_host'),
                              meta_port      => $self->o('meta_port'),
                              meta_database => $self->o('meta_database'),
                              base_output_dir => $self->o('base_output_dir'),
                              vertebrates_release => $self->o('vertebrates_release'),
                              non_vertebrates_release => $self->o('non_vertebrates_release'),
                            },
      -flow_into         => {
                              1 => 'DatabaseDump',
                            }
    },
     {
      -logic_name  => 'DatabaseDump',
      -module      => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -meadow_type => 'LSF',
      -parameters  => {
        'cmd' =>
'#base_dir#/ensembl-production/modules/Bio/EnsEMBL/Production/Utils/MySQLDumping.sh  #database# #output_dir# #host# #user# #password# #port#',
        'user'      => $self->o('user'),
        'password'      => $self->o('pass'),
        'host'      => $self->o('host'),
        'port'      => $self->o('port'),
        'base_dir'  => $self->o('base_dir')
        },
      -rc_name          => 'default',
      -analysis_capacity => 10
    },
   ];
}
1;
