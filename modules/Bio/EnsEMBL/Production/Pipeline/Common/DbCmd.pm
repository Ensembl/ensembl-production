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

package Bio::EnsEMBL::Production::Pipeline::Common::SqlExecute;


=head1 DESCRIPTION

Execute a set of SQL commands from a file by running mysql on the command line.

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::DbCmd;

use strict;
use warnings;

use base (
  'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
  'Bio::EnsEMBL::Production::Pipeline::Common::Base'
);

sub param_defaults {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::param_defaults},
    'db_type' => 'core',
  };
}

sub fetch_input {
  my $self = shift @_;
  my $db_type = $self->param('db_type');
  
  if ($db_type eq 'hive') {
    $self->param('db_conn', $self->dbc);
  } else {
    $self->param('db_conn', $self->get_DBAdaptor($db_type)->dbc);
  }
  
  $self->SUPER::fetch_input();
  
}

1;
