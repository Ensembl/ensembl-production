
=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::Release::DivisionFactory;

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk

=cut

package Bio::EnsEMBL::Production::Pipeline::Release::DivisionFactory;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub fetch_input {
  my ($self) = @_;

  return 0;
}

sub run {
  my ($self) = @_;

  return 0;
}

sub write_output {
  my ($self) = @_;

  my $division = $self->param_required('division');

  if ( ref($division) ne 'ARRAY' ) {
    $division = [$division];
  }

  foreach my $div (@$division) {

    $self->dataflow_output_id( { 'division' => $div,
                                 'prod_db' =>
                                   $self->param_required('prod_db'), },
                               2 );

  }

  return 0;
}

1;

