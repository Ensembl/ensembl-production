=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::DatabaseDumping::DbFactory;

=head1 DESCRIPTION

The factory will find all the databases on a given server. If run_all is set to 1,
the module will dataflow all the databases. If db_pattern is defined, dataflow the databases
matching the patterns

=cut

package Bio::EnsEMBL::Production::Pipeline::DatabaseDumping::DbDumpingFactory;

use base ('Bio::EnsEMBL::Hive::Process');
use strict;
use warnings;
use DBI;

sub run {
  my ($self) = @_;
  my $db_pattern      = $self->param_required('db_pattern') || [];
  my @db_pattern = ( ref($db_pattern) eq 'ARRAY' ) ? @$db_pattern : ($db_pattern);
  my $run_all = $self->param('run_all');

  my $host  = $self->param('host');
  my $user = $self->param('user');
  my $password = $self->param('password');
  my $port = $self->param('port');

#Connect to the MySQL server
  my $dsn=sprintf( "DBI:mysql:database=%s;host=%s;port=%d", 'information_schema', $host, $port );
  my $dbh = DBI->connect( $dsn, $user, $password, {'PrintError' => 1,'AutoCommit' => 0 } );
# Get the list of databases from the infromation_schema database excluding generic MysQL or system databases
  my $sth = $dbh->prepare('SELECT schema_name from SCHEMATA where schema_name not in ("performance_schema","mysql","information_schema","PERCONA_SCHEMA")') or die $dbh->errstr;
  $sth->execute() or die $dbh->errstr;
  my $server_databases = $sth->fetchall_arrayref;
  # If run_all is set to 1, dataflow all the databases
  if ($run_all){
    foreach my $database (@$server_databases){
      $self->dataflow_output_id({
			       database=>$database->[0]
			      }, 1);
    }
  }
  # If db_pattern is defined, find matching databases and dataflow them.
  elsif(@db_pattern){
    foreach my $database (@$server_databases){
      foreach my $db_pattern (@db_pattern){
        if ($database->[0] =~/$db_pattern/i){
          $self->dataflow_output_id({
			       database=>$database->[0]
			      }, 1);
        }
      }
    }
  }
 
}

1;
