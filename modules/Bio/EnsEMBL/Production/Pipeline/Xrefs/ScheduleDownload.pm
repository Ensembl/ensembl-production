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

package Bio::EnsEMBL::Production::Pipeline::Xrefs::ScheduleDownload;

use strict;
use warnings;
use DBI;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my ($self) = @_;
  my $base_path        = $self->param_required('base_path');
  my $config_file      = $self->param_required('config_file');
  my $source_dir       = $self->param_required('source_dir');
  my $reuse_db         = $self->param_required('reuse_db');
  my $skip_download    = $self->param_required('skip_download');

  my $user             = $self->param('source_user');
  my $pass             = $self->param('source_pass');
  my $db_url           = $self->param('source_url');
  my $source_db        = $self->param('source_db');
  my $host             = $self->param('source_host');
  my $port             = $self->param('source_port');

  if (defined $db_url) {
    ($user, $pass, $host, $port, $source_db) = $self->parse_url($db_url);
  } else {
    $db_url = sprintf("mysql://%s:%s@%s:%s/%s", $user, $pass, $host, $port, $source_db);
  }
  $self->create_db($source_dir, $user, $pass, $db_url, $source_db, $host, $port) unless $reuse_db;

  # Can re-use existing files if specified
  if ($skip_download) { return; }

  my $sources = $self->parse_config($config_file);
  my $dataflow_params;

  foreach my $source (@$sources) {
    my $name = $source->{'name'};
    my $parser = $source->{'parser'};
    my $priority = $source->{'priority'};
    my $file = $source->{'file'};
    my $db = $source->{'db'};
    my $version_file = $source->{'release'};
    $dataflow_params = {
      parser       => $parser,
      name         => $name,
      priority     => $priority,
      db           => $db,
      version_file => $version_file,
      db_url       => $db_url,
      file         => $file
    };
    $self->dataflow_output_id($dataflow_params, 2);
  }
    $dataflow_params = {
      db_url       => $db_url,
    };
    $self->dataflow_output_id($dataflow_params, 1);

}

1;

