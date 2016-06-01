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

=head1 NAME

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::RestoreBackups;

=head1 DESCRIPTION

Module to automatically restore backups

=head1 AUTHOR

Thomas Maurel

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::RestoreBackups;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::Base');
use Bio::EnsEMBL::Utils::SqlHelper;


sub fetch_input {
    my ($self)  = @_;

    my $core_dbh   = $self->core_dbh;
    my $output_dir = $self->param_required('output_dir');

    $output_dir    = $output_dir.'/backup';
    $self->check_directory($output_dir);

    $self->param('core_dbh',  $core_dbh);
    $self->param('output_dir',$output_dir);

return 0;
}


sub write_output {
    my ($self)  = @_;

return 0;
}

sub run {
    my ($self)       = @_;

    my $dbc          = $self->core_dbc();
    my $host         = $dbc->host();
    my $port         = $dbc->port();
    my $user         = $dbc->username();
    my $pass         = $dbc->password();
    my $dbname       = $dbc->dbname();
    my $mysql_binary = 'mysql';
    my $output_dir   = $self->param('output_dir');
    my $tables       = $self->param_required('dump_tables');

    $self->check_directory($output_dir);

   #Checking if all the table for a given species has already been backed up
   foreach my $table (@$tables) {
     unless (system("set -o pipefail; zcat $output_dir/$dbname.$table.sql.gz | $mysql_binary -h$host -P$port -u$user -p$pass $dbname") == 0) {
       $self->warning("Can't restore the $table table for $dbname because $!\n");
     }
   }
   $dbc->disconnect_if_idle();

return 0;
}

=head2 check_directory

  Arg[1]     : -none-
  Example    : $self->check_directory;
  Function   : Check if the directory exists
  Returns    : None
  Exceptions : dies if directory don't exist

=cut
sub check_directory {
    my ($self,$dir) = @_;

    unless (-e $dir) {
        die "$dir doesn't exists, can't restore backups\n";
    }

return;
}




1;
