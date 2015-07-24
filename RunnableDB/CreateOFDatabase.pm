=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::CreateOFDatabase;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

sub param_defaults {
  return {
    'copy_tables' => 
    [
      'meta',
      'assembly',
      'coord_system',
      'seq_region',
      'seq_region_attrib',
      'attrib_type',
      'external_db',
      'misc_set',
      'unmapped_reason',
    ],
  };
}

sub run {
  my ($self) = @_;
  my $species = $self->param_required('species');
  my $copy_tables = $self->param_required('copy_tables');
  
  my $core_dba = $self->core_dba;
  my $core_dbh = $core_dba->dbc->db_handle;
  my $core_db = $core_dba->dbc->dbname;
  my @tables = $core_dbh->tables();
  
  (my $of_db = $core_db) =~ s/_core_/_otherfeatures_/;
  $core_dbh->do("CREATE DATABASE $of_db;") or $self->throw($core_dbh->errstr);
  
  foreach my $table (@tables) {
    (my $of_table = $table) =~ s/_core_/_otherfeatures_/;
    my $sql = "CREATE TABLE $of_table LIKE $table;";
    $core_dbh->do($sql) or $self->throw($core_dbh->errstr);
  }
  
  foreach my $table (@{$copy_tables}) {
    my $sql = "INSERT INTO $of_db.$table SELECT * FROM $core_db.$table;";
    $core_dbh->do($sql) or $self->throw($core_dbh->errstr);
  }
  
}

1;

