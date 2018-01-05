=head1 LICENSE

Copyright [2009-2015] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Xrefs::UniParcMapping;

use strict;
use warnings;

use XrefMapper::UniParcMapper;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;


sub run {
  my ($self) = @_;
  my $xref_url     = $self->param_required('xref_url');
  my $species      = $self->param_required('species');
  my $base_path    = $self->param_required('base_path');
  my $source_url   = $self->param_required('source_url');
  my $release      = $self->param_required('release');

  my $mapper = $self->get_xref_mapper($xref_url, $species, $base_path, $release);
  my $checksum_mapper = XrefMapper::UniParcMapper->new($mapper);
  $checksum_mapper->process($source_url);

}

1;

