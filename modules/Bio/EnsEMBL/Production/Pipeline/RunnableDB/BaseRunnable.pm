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

 Bio::EnsEMBL::Production::Pipeline::RunnableDB::BaseRunnable;

=head1 DESCRIPTION


=head1 MAINTAINER

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::RunnableDB::BaseRunnable;

use strict;
use Carp;

use base ('Bio::EnsEMBL::Hive::Process');

sub hive_dbc {
  my $self = shift;

  my $dbc = $self->dbc();  
  confess('Type error!') unless($dbc->isa('Bio::EnsEMBL::DBSQL::DBConnection'));

  return $dbc;
}

sub hive_dbh {
  my $self = shift;

  my $dbh = $self->hive_dbc->db_handle();
  confess('Type error!') unless($dbh->isa('DBI::db'));

  return $dbh;
}

sub get_DBAdaptor {
  my ($self, $type) = @_;

  $type ||= 'core';
  my $species = ($type eq 'production') ? 'multi' : $self->param_required('species');

  return Bio::EnsEMBL::Registry->get_DBAdaptor($species, $type);
}

sub core_dba {	
  my $self = shift;

  my $dba = $self->get_DBAdaptor('core');
  confess('Type error!') unless($dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor'));
	
  return $dba;
}

sub core_dbc {
  my $self = shift;

  my $dbc = $self->core_dba()->dbc();	
  confess('Type error!') unless($dbc->isa('Bio::EnsEMBL::DBSQL::DBConnection'));

  return $dbc;
}

sub core_dbh {
  my $self = shift;

  my $dbh = $self->core_dbc->db_handle();
  confess('Type error!') unless($dbh->isa('DBI::db'));

  return $dbh;
}

sub otherfeatures_dba {	
  my $self = shift;

  my $dba = $self->get_DBAdaptor('otherfeatures');
  confess('Type error!') unless($dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor'));
	
  return $dba;
}

sub otherfeatures_dbc {
  my $self = shift;

  my $dbc = $self->otherfeatures_dba()->dbc();	
  confess('Type error!') unless($dbc->isa('Bio::EnsEMBL::DBSQL::DBConnection'));

  return $dbc;
}

sub otherfeatures_dbh {
  my $self = shift;

  my $dbh = $self->otherfeatures_dba()->dbc()->db_handle();	
  confess('Type error!') unless($dbh->isa('DBI::db'));

  return $dbh;
}

sub production_dba {
  my $self = shift;
  
  my $dba = $self->get_DBAdaptor('production');
  if (!defined $dba) {
    my %production_db = %{$self->param('production_db')};
    $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%production_db);
  }
  confess('Type error!') unless($dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor'));
	
  return $dba;
}

sub production_dbc {
  my $self = shift;

  my $dbc = $self->production_dba()->dbc();	
  confess('Type error!') unless($dbc->isa('Bio::EnsEMBL::DBSQL::DBConnection'));

  return $dbc;
}

sub production_dbh {
  my $self = shift;

  my $dbh = $self->production_dba()->dbc()->db_handle();	
  confess('Type error!') unless($dbh->isa('DBI::db'));

  return $dbh;
}

=head2 hive_database_string_for_user

  Return the name and location of the database in a human readable way.

=cut
sub hive_database_string_for_user {
  my $self = shift;
  return $self->hive_dbc->dbname . " on " . $self->hive_dbc->host 
  
}

=head2 core_database_string_for_user

	Return the name and location of the database in a human readable way.

=cut
sub core_database_string_for_user {
  my $self = shift;
  return $self->core_dbc->dbname . " on " . $self->core_dbc->host 
	
}

=head2 otherfeatures_database_name

	Return the name of the otherfeatures db
    
=cut
sub otherfeatures_database_name {
  my $self = shift;
  return $self->otherfeatures_dbc->dbname;
	
}

=head2 mysql_command_line_connect
=cut
sub mysql_command_line_connect {
  my $self = shift;

  my $cmd = 
      "mysql"
      . " --host ". $self->core_dbc->host
      . " --port ". $self->core_dbc->port
      . " --user ". $self->core_dbc->username
      . " --pass=". $self->core_dbc->password
  ;

  return $cmd;
}

=head2 mysql_command_line_connect_core_db
=cut
sub mysql_command_line_connect_core_db {
	
  my $self = shift;

  my $cmd =
      $self->mysql_command_line_connect
      . " ". $self->core_dbc->dbname
  ;

  return $cmd;
}

=head2 mysql_command_line_connect_otherfeatures_db
=cut
sub mysql_command_line_connect_otherfeatures_db {
	
  my $self = shift;

  my $cmd = 
      "mysql"
      . " --host ". $self->otherfeatures_dbc->host
      . " --port ". $self->otherfeatures_dbc->port
      . " --user ". $self->otherfeatures_dbc->username
      . " --pass=". $self->otherfeatures_dbc->password
      . " ". $self->otherfeatures_dbc->dbname
  ;

  return $cmd;
}

=head2 mysql_command_line_connect_core_db
=cut
sub mysqldump_command_line_connect_core_db {
	
  my $self = shift;

  my $cmd = 
      "mysqldump"
      . " --lock_table=FALSE --no-create-info"
      . " --host ". $self->core_dbc->host
      . " --port ". $self->core_dbc->port
      . " --user ". $self->core_dbc->username
      . " --pass=". $self->core_dbc->password
      . " ". $self->core_dbc->dbname
  ;

  return $cmd;
}

sub has_chromosomes {
  my ($self, $dba) = @_;
  my $helper = $dba->dbc->sql_helper();
  my $sql = q{
    SELECT COUNT(*) FROM
    coord_system cs INNER JOIN
    seq_region sr USING (coord_system_id) INNER JOIN
    seq_region_attrib sa USING (seq_region_id) INNER JOIN
    attrib_type at USING (attrib_type_id)
    WHERE cs.species_id = ?
    AND at.code = 'karyotype_rank'
  };
  my $count = $helper->execute_single_result(-SQL => $sql, -PARAMS => [$dba->species_id()]);
  
  $dba->dbc->disconnect_if_idle();
  
  return $count;
}

sub has_genes {
  my ($self, $dba) = @_;
  my $helper = $dba->dbc->sql_helper();
  my $sql = q{
    SELECT COUNT(*) FROM
    coord_system cs INNER JOIN
    seq_region sr USING (coord_system_id) INNER JOIN
    gene g USING (seq_region_id)
    WHERE cs.species_id = ?
  };
  my $count = $helper->execute_single_result(-SQL => $sql, -PARAMS => [$dba->species_id()]);
  
  $dba->dbc->disconnect_if_idle();
  
  return $count;
}

1;

