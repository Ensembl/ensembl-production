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

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my ($self) = @_;
  my $config_file      = $self->param_required('config_file');
  my $source_dir       = $self->param_required('source_dir');
  my $skip_download    = $self->param_required('skip_download');

  my $db_url = $self->param_required('source_url');

  $self->create_db($source_dir, $db_url, $self->param_required('reuse_db'));

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
      file         => $file,
      skip_download=> $skip_download,
    };
    $self->dataflow_output_id($dataflow_params, 2);
  }
    $dataflow_params = {
      db_url       => $db_url,
    };
    $self->dataflow_output_id($dataflow_params, 1);

}

1;

