=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::Common::SqlCmd

=head1 DESCRIPTION

This is a simple wrapper around the Hive module; all it's really doing
is creating an appropriate dbconn for that module.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::SqlCmd;

use strict;
use warnings;

use base (
  'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
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
  $self->SUPER::fetch_input();
  
  my $db_type = $self->param('db_type');
  if ($db_type eq 'hive') {
    $self->param('db_conn', $self->dbc);
  } else {
    $self->param('db_conn', $self->get_DBAdaptor($db_type)->dbc);
  }
  
}

1;
