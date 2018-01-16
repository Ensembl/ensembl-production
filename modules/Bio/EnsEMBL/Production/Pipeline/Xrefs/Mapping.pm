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

package Bio::EnsEMBL::Production::Pipeline::Xrefs::Mapping;

use strict;
use warnings;

use XrefMapper::BasicMapper;
use XrefMapper::ProcessPrioritys;
use XrefMapper::ProcessPaired;
use XrefMapper::TestMappings;
use XrefMapper::XrefLoader;
use XrefMapper::DisplayXrefs;
use XrefMapper::OfficialNaming;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;


sub run {
  my ($self) = @_;
  my $xref_url     = $self->param_required('xref_url');
  my $species      = $self->param_required('species');
  my $base_path    = $self->param_required('base_path');
  my $release      = $self->param_required('release');

  $self->dbc()->disconnect_if_idle() if defined $self->dbc();

  my $mapper = $self->get_xref_mapper($xref_url, $species, $base_path, $release);
  my $dbi = $mapper->xref->dbc();

  my $priority = XrefMapper::ProcessPrioritys->new($mapper);
  $priority->process();

  my $paired = XrefMapper::ProcessPaired->new($mapper);
  $paired->process();

  $mapper->biomart_testing();
  $mapper->source_defined_move($dbi);
  $mapper->process_alt_alleles($dbi);

  my $official_naming = XrefMapper::OfficialNaming->new($mapper);
  $official_naming->run();

  my $tester = XrefMapper::TestMappings->new($mapper);
  $tester->direct_stable_id_check();
  $tester->entry_number_check();
  $tester->name_change_check();

  ## From this step on, will update the core database
  my $loader = XrefMapper::XrefLoader->new($mapper);
  $loader->update();
  my $display = XrefMapper::DisplayXrefs->new($mapper);
  $display->genes_and_transcripts_attributes_set();

}

1;

