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

package Bio::EnsEMBL::Production::Pipeline::Xrefs::DownloadSource;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my ($self) = @_;
  my $base_path        = $self->param_required('base_path');
  my $parser           = $self->param_required('parser');
  my $name             = $self->param_required('name');
  my $priority         = $self->param_required('priority');
  my $db_url           = $self->param_required('db_url');
  my $file             = $self->param_required('file');
  my $db               = $self->param('db');
  my $version_file     = $self->param('version_file');

  $self->dbc()->disconnect_if_idle() if defined $self->dbc();
  my ($user, $pass, $host, $port, $source_db) = $self->parse_url($db_url);
  my $dbi = $self->get_dbi($host, $port, $user, $pass, $source_db);
  my $insert_source_sth = $dbi->prepare("INSERT IGNORE INTO source (name, parser) VALUES (?, ?)");
  my $insert_version_sth = $dbi->prepare("INSERT ignore INTO version (source_id, uri, index_uri, count_seen, revision) VALUES ((SELECT source_id FROM source WHERE name = ?), ?, ?, ?, ?)");

  my $file_name = $self->download_file($file, $base_path, $name, $db);
  my $version;
  if (defined $version_file) {
    $version = $self->download_file($version_file, $base_path, $name, $db, 'version');
  }

  $insert_source_sth->execute($name, $parser);
  $insert_version_sth->execute($name, $file_name, $db, $priority, $version);
  $insert_source_sth->finish();
  $insert_version_sth->finish();
}

1;

