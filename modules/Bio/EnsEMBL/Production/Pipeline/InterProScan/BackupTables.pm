=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::BackupTables;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR 

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::BackupTables;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::Base');

sub fetch_input {
    my ($self) 	= @_;

return 0;
}

sub write_output {
    my ($self)  = @_;

    $self->dataflow_output_id({}, 1 );

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
    my $mysql_binary = 'mysqldump';
    my $output_dir   = $self->param_required('pipeline_dir');
    my $tables       = $self->param_required('dump_tables');

    $output_dir = $output_dir.'/backup';
    $self->check_directory($output_dir);

   # Checking if all the table for a given species has already been backed up
   foreach my $table (@$tables) {
     if (-e $output_dir."/".$dbname.".".$table.".sql.gz"){
        1;
      }
      else {
        unless (system("$mysql_binary -h$host -P$port -u$user -p$pass $dbname $table | gzip -c -6 > $output_dir/$dbname.$table.sql.gz") == 0) {
          $self->warning("Can't dump the original $table table from $dbname for backup because $!\n");
          exit 1;
       } else {
          $self->warning("Original $table table backed up in $dbname.$table.sql\n");
       }
     }
   }
   $dbc->disconnect_if_idle();

return 0;
}

sub check_directory {
    my ($self,$dir) = @_;

    unless (-e $dir) {
        print STDERR "$dir doesn't exists. I will try to create it\n" if ($self->debug());
        print STDERR "mkdir $dir (0755)\n" if ($self->debug());
        die "Impossible create directory $dir\n" unless (mkdir $dir, 0755 );
    }

return;
}

1;


