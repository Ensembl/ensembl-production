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

package Bio::EnsEMBL::Production::Pipeline::Common::SqlExecute;


=head1 DESCRIPTION

Execute a set of SQL commands from a file by running mysql on the command line.

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::SqlExecute;

use strict;
use warnings;

use base 'Bio::EnsEMBL::Production::Pipeline::Common::Base';

sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults},
    db_type  => 'core',
    out_file => '/dev/null',
  };
}

sub run {
  my ($self) = @_;
  my $db_type  = $self->param_required('db_type');
  my $sql_file = $self->param_required('sql_file');
  my $out_file = $self->param_required('out_file');
  
  my $dba = $self->get_DBAdaptor($db_type);
  my $dbc = $dba->dbc;
  my $cmd = 'mysql'.
    ' -N'.
    ' --host '.$dbc->host.
    ' --port '.$dbc->port.
    ' --user '.$dbc->user.
    ' --pass='.$dbc->pass.
    '        '.$dbc->dbname.
    " < $sql_file > $out_file ";
  
  system($cmd) == 0 or $self->throw("Failed to run ".$cmd)
}

1;
