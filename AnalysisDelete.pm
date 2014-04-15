=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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


=pod

=head1 NAME

Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisDelete

=head1 DESCRIPTION

Delete an analysis and any referenced data in other tables.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisDelete;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base);
use Bio::EnsEMBL::Analysis;

sub param_defaults {
  return {
    'db_type'            => 'core',
    'linked_tables'      => [],
    'db_backup_required' => 1,
    'throw_if_not_exist' => 1,
  };
}

sub fetch_input {
  my $self = shift @_;
  
  if ($self->param('db_backup_required')) {
    my $db_backup_file = $self->param_required('db_backup_file');
    
    if (!-e $db_backup_file) {
      $self->throw("Database backup file '$db_backup_file' does not exist");
    }
  }
  
}

sub run {
  my $self = shift @_;
  my $species = $self->param_required('species');
  my $logic_name = $self->param_required('logic_name');
  
  my $dba = $self->get_DBAdaptor($self->param('db_type'));
  my $dbh = $dba->dbc->db_handle;
  my $aa = $dba->get_adaptor('Analysis');
  my $analysis = $aa->fetch_by_logic_name($logic_name);
  
  if (defined $analysis) {
    my $analysis_id = $analysis->dbID;
    foreach my $table (@{$self->param('linked_tables')}) {
      my $sql = "DELETE FROM $table WHERE analysis_id = $analysis_id";
      my $sth = $dbh->prepare($sql) or throw("Failed to delete rows using '$sql': ".$dbh->errstr);
      $sth->execute or throw("Failed to delete rows using '$sql': ".$sth->errstr);
    }
    $aa->remove($analysis);
  } else {
    my $message = "Cannot delete analysis '$logic_name' because it doesn't exist.\n";
    if ($self->param('throw_if_not_exist')) {
      $self->throw($message);
    } else {
      $self->warning($message);
    }
  }
  
}

1;
