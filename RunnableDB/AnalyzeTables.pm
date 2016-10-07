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

Bio::EnsEMBL::EGPipeline::Common::AnalyzeTables

=head1 DESCRIPTION

Analyze (or optionally optimize) all tables in a database.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalyzeTables;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

sub param_defaults {
  my ($self) = @_;
  
  return {
    'optimize_tables' => 0,
    'db_types' => ['core'],
  };
  
}

sub run {
  my ($self) = @_;
  
  my $command = $self->param('optimize_tables') ? 'OPTIMIZE' : 'ANALYZE';
  foreach my $db_type (@{$self->param('db_types')}) {
    my $dba = $self->get_DBAdaptor($db_type);
    if (defined $dba) {
      my $tables = $dba->dbc->db_handle->selectcol_arrayref('SHOW TABLES;');
      map {$dba->dbc->do("$command TABLE $_;")} @$tables;
      $dba->dbc->disconnect_if_idle();
    }
  }
}

1;
