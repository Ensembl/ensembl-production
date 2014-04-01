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

Bio::EnsEMBL::EGPipeline::Common::SqlCmd

=head1 DESCRIPTION

This is a simple wrapper around the Hive module; all it's really doing
is creating an appropriate dbconn for that module.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::Common::SqlCmd;

use strict;
use warnings;

use base (
  'Bio::EnsEMBL::EGPipeline::Common::Base',
  'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd'
);

sub param_defaults {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::param_defaults},
    'type' => 'core',
  };
  
}

sub fetch_input {
  my $self = shift @_;
  $self->SUPER::fetch_input();
  
  $self->param('db_conn', $self->get_DBAdaptor($self->param('type'))->dbc);
  
}

1;
