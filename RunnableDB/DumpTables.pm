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

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::DumpTables;

=head1 DESCRIPTION

This analysis will backup database tables specified in $table to directory specify in $output_dir.
The analysis checks the $output_dir first to make sure we don't overwrite backups. This is necessary as we can backup the same species multiple time for each projections

=head1 AUTHOR 

ckong and maurel

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::DumpTables; 

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::Base');

=head2 fetch_input

=cut
sub fetch_input {
    my ($self) 	= @_;

    my $core_dbh   = $self->core_dbh;
    my $output_dir = $self->param_required('output_dir');

    $output_dir    = $output_dir.'/backup';
    $self->check_directory($output_dir);

    $self->param('core_dbh',  $core_dbh);
    $self->param('output_dir',$output_dir);

return 0;
}

=head2 write_output 

=cut
sub write_output {
    my ($self)  = @_;

    $self->dataflow_output_id({}, 1 );

return 0;
}

=head2 run

  Arg[1]     : -none-
  Example    : $self->run;
  Function   : 
  Returns    : 1 on successful completion
  Exceptions : dies if runnable throws an unexpected error

=cut
sub run {
    my ($self)       = @_;

    my $dbc          = $self->core_dbc();
    my $host         = $dbc->host();
    my $port         = $dbc->port();
    my $user         = $dbc->username();
    my $pass         = $dbc->password();
    my $dbname       = $dbc->dbname();
    my $mysql_binary = 'mysqldump';
    my $tables       = $self->param_required('dump_tables');
    my $output_dir   = $self->param('output_dir'); 

    #Checking if all the table for a given species has already been backed up
    foreach my $table (@$tables) {
      if (-e $output_dir."/".$dbname.".".$table.".sql.gz"){
        1;
      }
      else {
        unless (system("set -o pipefail; $mysql_binary -h$host -P$port -u$user -p$pass $dbname $table | gzip -c -6 > $output_dir/$dbname.$table.sql.gz") == 0) {
          $self->warning("Can't dump the original $table table from $dbname for backup because $!\n");
          exit 1;
       } else {
          $self->warning("Original $table table backed up in $dbname.$table.sql\n");
       }
      }
    }
return 0;
}


1;


