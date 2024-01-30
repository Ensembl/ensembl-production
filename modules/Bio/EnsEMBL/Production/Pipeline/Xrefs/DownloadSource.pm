=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License..

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
  my $skip_download    = $self->param_required('skip_download');
  my $db               = $self->param('db');
  my $version_file     = $self->param('version_file');
  my $preparse         = $self->param('preparse');
  my $rel_number       = $self->param('rel_number');
  my $catalog          = $self->param('catalog');

  $self->dbc()->disconnect_if_idle() if defined $self->dbc();

  my $extra_args = {};
  $extra_args->{'skip_download_if_file_present'} = $skip_download;
  $extra_args->{'rel_number'} = $rel_number if (defined($rel_number));
  $extra_args->{'catalog'} = $catalog if (defined($catalog));
  my $file_name = $self->download_file($file, $base_path, $name, $db, $extra_args);

  my $version;
  if (defined $version_file) {
    $extra_args->{'release'} = 'version';
    $version = $self->download_file($version_file, $base_path, $name, $db, $extra_args);
  }

  my ($user, $pass, $host, $port, $source_db) = $self->parse_url($db_url);
  my $dbi = $self->get_dbi($host, $port, $user, $pass, $source_db);
  my $insert_source_sth = $dbi->prepare("INSERT IGNORE INTO source (name, parser) VALUES (?, ?)");
  my $insert_version_sth = $dbi->prepare("INSERT ignore INTO version (source_id, uri, index_uri, count_seen, revision, preparse) VALUES ((SELECT source_id FROM source WHERE name = ?), ?, ?, ?, ?, ?)");
  $insert_source_sth->execute($name, $parser);
  $insert_version_sth->execute($name, $file_name, $db, $priority, $version, $preparse);
  $insert_source_sth->finish();
  $insert_version_sth->finish();
}

1;

