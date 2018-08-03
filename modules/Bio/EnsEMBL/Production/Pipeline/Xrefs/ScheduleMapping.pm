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

package Bio::EnsEMBL::Production::Pipeline::Xrefs::ScheduleMapping;

use strict;
use warnings;

use XrefMapper::BasicMapper;
use XrefMapper::ProcessMappings;
use XrefMapper::ProcessPrioritys;
use XrefMapper::ProcessPaired;
use XrefMapper::CoreInfo;
use XrefMapper::TestMappings;
use XrefMapper::XrefLoader;
use XrefMapper::DisplayXrefs;
use XrefMapper::CoordinateMapper;
use XrefMapper::UniParcMapper;
use XrefMapper::RNACentralMapper;
use XrefMapper::OfficialNaming;
use XrefMapper::DirectXrefs;
use XrefMapper::db;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;


sub run {
  my ($self) = @_;
  my $xref_url     = $self->param_required('xref_url');
  my $species      = $self->param_required('species');
  my $base_path    = $self->param_required('base_path');
  my $source_url   = $self->param_required('source_url');
  my $release      = $self->param_required('release');
  my $taxon        = $self->param('taxon');

  my $mapper = $self->get_xref_mapper($xref_url, $species, $base_path, $release, $taxon);

  my $core_info = XrefMapper::CoreInfo->new($mapper);
  $core_info->get_core_data();
  $mapper->get_alt_alleles();

  $self->dataflow_output_id( {
    xref_url   => $xref_url,
    species    => $species,
    base_path  => $base_path,
    release    => $release,
    source_url => $source_url
  }, 2);

  $self->dataflow_output_id( {
    xref_url   => $xref_url,
    species    => $species,
    base_path  => $base_path,
    release    => $release
  }, 1);

}

1;

