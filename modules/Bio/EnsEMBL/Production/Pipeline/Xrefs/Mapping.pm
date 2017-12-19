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

#use XrefMapper::SubmitMapper;
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
use Bio::EnsEMBL::Registry;
use XrefMapper::db;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;


sub run {
  my ($self) = @_;
  my $xref_url     = $self->param_required('xref_url');
  my $species      = $self->param_required('species');
  my $base_path    = $self->param_required('base_path');

  my $parsed_url = Bio::EnsEMBL::Hive::Utils::URL::parse($xref_url);
  my $user   = $parsed_url->{'user'};
  my $pass   = $parsed_url->{'pass'};
  my $host   = $parsed_url->{'host'};
  my $port   = $parsed_url->{'port'};
  my $dbname = $parsed_url->{'dbname'};

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


  my $xref_db = XrefMapper::db->new(
    -host    => $host,
    -dbname  => $dbname,
    -port    => $port,
    -user    => $user,
    -pass    => $pass
  );

  my $mapper = XrefMapper::BasicMapper->new();
  $mapper->xref($xref_db);
  $mapper->add_meta_pair("xref", $host.":".$dbname);
  $mapper->core($core_db);
  $mapper->add_meta_pair("species", $host.":".$dbname);
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

