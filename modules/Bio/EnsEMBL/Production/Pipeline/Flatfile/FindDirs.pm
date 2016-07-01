=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::Flatfile::FindDirs

=head1 DESCRIPTION

Finds all directories under the given species directory. This is used to
flow any further processing only dependent on the directory

Allowed parameters are:

=over 8

=item species - The species to work with

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::FASTA::FindDirs;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::FindDirs Bio::EnsEMBL::Production::Pipeline::Flatfile::Base/;

use File::Spec;

sub fetch_input {
  my ($self) = @_;
  $self->throw("No 'species' parameter specified") unless $self->param('species');
  $self->param('path', $self->data_path());
  $self->SUPER::fetch_input();
  return;
}

1;
