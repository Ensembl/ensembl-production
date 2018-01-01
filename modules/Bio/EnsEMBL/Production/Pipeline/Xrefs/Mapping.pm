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

  my ($user, $pass, $host, $port, $dbname) = $self->parse_url($xref_url);

  my $registry = 'Bio::EnsEMBL::Registry';
  my $core_adaptor = $registry->get_DBAdaptor($species, 'Core');
  my $core_dbc = $core_adaptor->dbc;
  my $core_db = XrefMapper::db->new(
    -host    => $core_dbc->host,
    -dbname  => $core_dbc->dbname,
    -port    => $core_dbc->port,
    -user    => $core_dbc->user,
    -pass    => $core_dbc->pass
  );
  $core_db->dir($base_path);
  $core_db->species($species);
  my $cdna_path = $self->get_path($species, $base_path, 'transcripts.fa');
  my $pep_path = $self->get_path($species, $base_path, 'peptides.fa');
  $core_db->dna_file($cdna_path);
  $core_db->protein_file($pep_path);

  my $xref_db = XrefMapper::db->new(
    -host    => $host,
    -dbname  => $dbname,
    -port    => $port,
    -user    => $user,
    -pass    => $pass
  );

  # Look for species-specific mapper
  my $module = 'XrefMapper::BasicMapper';;
  my $class = "XrefMapper/$species.pm";
  my $eval_test = eval { require $class; };
  if (defined $eval_test) {
    $module = "XrefMapper::$species" if $eval_test == 1;
  }

  my $mapper = $module->new();
  $mapper->xref($xref_db);
  $mapper->add_meta_pair("xref", $host.":".$dbname);
  $mapper->core($core_db);
  $mapper->add_meta_pair("species", $host.":".$dbname);

  my $core_info = XrefMapper::CoreInfo->new($mapper);
  $core_info->get_core_data();
  $mapper->get_alt_alleles();

  my $coord = XrefMapper::CoordinateMapper->new($mapper);
  $coord->run_coordinatemapping(1);

  my $checksum_mapper = XrefMapper::UniParcMapper->new($mapper);
  $checksum_mapper->process($source_url);
  $checksum_mapper = XrefMapper::RNACentralMapper->new($mapper);
  $checksum_mapper->process($source_url);

  my $parser = XrefMapper::ProcessMappings->new($mapper);
  $parser->process_mappings();

  my $direct_mappings = XrefMapper::DirectXrefs->new($mapper);
  $direct_mappings->process();

  my $priority = XrefMapper::ProcessPrioritys->new($mapper);
  $priority->process();

  my $paired = XrefMapper::ProcessPaired->new($mapper);
  $paired->process();

  $mapper->biomart_testing();
  $mapper->source_defined_move();
  $mapper->process_alt_alleles();

  my $official_naming = XrefMapper::OfficialNaming->new($mapper);
  $official_naming->run();

  my $tester = XrefMapper::TestMappings->new($mapper);
  $tester->direct_stable_id_check(); # Will only give warnings
  $tester->entry_number_check();     # Will only give warnings
  $tester->name_change_check();      # Will only give warnings

  my $loader = XrefMapper::XrefLoader->new($mapper);
  $loader->update();

  my $display = XrefMapper::DisplayXrefs->new($mapper);
  $display->genes_and_transcripts_attributes_set();

}

1;

