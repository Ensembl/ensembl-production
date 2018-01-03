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

package Bio::EnsEMBL::Production::Pipeline::Xrefs::Checksum;

use strict;
use warnings;
use DBI;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my ($self) = @_;
  my $base_path        = $self->param_required('base_path');
  my $skip_download    = $self->param_required('skip_download');
  my $db_url           = $self->param('db_url');

  return if $skip_download;
  my ($user, $pass, $host, $port, $source_db) = $self->parse_url($db_url);
  my $dbi = $self->get_dbi($host, $port, $user, $pass, $source_db);

}

1;

