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
use XrefMapper::Methods::MySQLChecksum;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;


sub run {
  my ($self) = @_;
  my $xref_url     = $self->param_required('xref_url');
  my $species      = $self->param_required('species');
  my $base_path    = $self->param_required('base_path');
  my $db_url       = $self->param_required('source_url');
  my $release      = $self->param_required('release');

  $self->dbc()->disconnect_if_idle() if defined $self->dbc();

  my $species_id = $self->get_taxon_id($species);
  my $mapper = XrefMapper::UniParcMapper->new($self->get_xref_mapper($xref_url, $species, $base_path, $release, $taxon));

  # Unroll this method to avoid an extra "check if there is data before proceeding"
  # $mapper->process($source_url, $species_id);

  my $target = $mapper->target;
  my $object_type = $mapper->object_type;
  my $source_id = $mapper->source_id;

  my $method = XrefMapper::Methods::MySQLChecksum->new( -MAPPER => $mapper);
  my $results = $method->run($target, $source_id, $object_type, $db_url);
  $mapper->upload($results, $species_id) if @{$results};
}

1;

