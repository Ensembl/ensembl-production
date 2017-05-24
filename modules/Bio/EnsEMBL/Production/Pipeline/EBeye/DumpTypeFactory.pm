=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::EBeye::DumpTypeFactory

=head1 DESCRIPTION

Small extension of the job factory to do default database type submission.

Allowed parameters are:

=over 8

=item types - The database types to use; defaults to core

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::EBeye::DumpTypeFactory;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Hive::RunnableDB::JobFactory/;
use Bio::EnsEMBL::Utils::Scalar qw/wrap_array/;

sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults()},
    column_names => ['type','species'],
    default_types => [qw/core/],
  };
}

sub fetch_input {
  my ($self) = @_;
  my $user_types = $self->param('types');
  my $types = (defined $user_types && @{$user_types}) ? $user_types : $self->param('default_types');
  $types = wrap_array($types);
  my @inputlist = map { [ $_, $self->param('species') ] } @{$types};
  $self->param('inputlist', \@inputlist);
  return;
}

1;
