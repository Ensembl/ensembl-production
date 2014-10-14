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

=head1 AUTHOR 

ckong 

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::DumpTables; 

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::Base');

my ($core_dbh, $output_dir);

=head2 fetch_input

=cut
sub fetch_input {
    my ($self) 	= @_;

    $core_dbh   = $self->core_dbh;
    $output_dir = $self->param_required('output_dir');
    $output_dir = $output_dir.'/backup';
    $self->check_directory($output_dir);

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
    my $mysql_binary = 'mysql';
    my $tables       = $self->param_required('dump_tables');

    foreach my $table (@$tables) {
      unless (system("$mysql_binary -h$host -P$port -u$user -p$pass -N -e 'select * from $table' $dbname | gzip -c -6 > $output_dir/$dbname.$table.backup.gz") == 0) {
        print STDERR "Can't dump the original $table table from $dbname for backup\n";
        exit 1;
     } else {
        print "Original $table table backed up in $dbname.$table.backup\n";
     }
   }

return 0;
}


1;


