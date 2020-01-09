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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::DatabaseDumping::MySQLDumpsCheck;

=head1 DESCRIPTION

This module with check that we have a MySQL dump for all the tables of a database
It will also check that we have generated the table.sql and CHECKSUMS files.

=cut

package Bio::EnsEMBL::Production::Pipeline::DatabaseDumping::MySQLDumpsCheck;

use base ('Bio::EnsEMBL::Hive::Process');
use warnings;
use strict;
use Bio::EnsEMBL::DBSQL::DBConnection;

sub run {
  my ($self) = @_;
  my $database_name = $self->param_required('database');
  my $dump_path = $self->param_required('output_dir');
  my $table_list_sql = qq/SELECT TABLE_NAME FROM 
                 information_schema.tables WHERE 
                 table_schema = '$database_name'
                 AND TABLE_NAME not like 'MTMP_%'
  /;
  my $dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(
    -user   => $self->param('user'),
    -host   => $self->param('host'),
    -port   => $self->param('port'),
    -pass => $self->param('password'),
    -dbname => $database_name,
    -driver => 'mysql',
  );
  my $helper = $dbc->sql_helper;
  my $tables = $helper->execute(-SQL => $table_list_sql);
  foreach (@$tables) {
    my $table_name = $_->[0];
    # Check that we have a mysql dump file for each of the database table
    my $file = $dump_path."/".$database_name."/".$table_name.".txt.gz";
    if (! -e $file){
      die "$table_name.txt.gz is missing from $dump_path";
    }
  }
  # Check that the table.sql file exists
  if (! -e $dump_path."/".$database_name."/".$database_name.".sql.gz"){
    die "$database_name.sql.gz table sql file missing from $dump_path";
  }
  # Check that the CHECKSUMS file exists
  if (! -e $dump_path."/".$database_name."/CHECKSUMS"){
    die "CHECKSUMS missing from $dump_path";
  }
  return;
}

1;
