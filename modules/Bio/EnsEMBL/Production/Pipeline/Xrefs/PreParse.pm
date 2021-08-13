=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Xrefs::PreParse;

use strict;
use warnings;
use File::Path qw(make_path);

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my ($self) = @_;

  my $parser       = $self->param_required('parser');
  my $xref_url     = $self->param_required('xref_url');
  my $name         = $self->param_required('name');
  my $version_file = $self->param('version_file');
  my $file         = $self->param_required('file');
  my $dbname       = $self->param_required('dbname');

  my ($user, $pass, $host, $port) = $self->parse_url($xref_url);

  my $xref_dbc = XrefParser::Database->new({
            host    => $host,
            dbname  => $dbname,
            port    => $port,
            user    => $user,
            pass    => $pass });
  $xref_dbc->disconnect_if_idle();

  my $dbi = $self->get_dbi($host, $port, $user, $pass, $dbname);

  my $source_id = $self->get_source_id($dbi, $parser, 1, $name, 1);

  my $module = "Bio::EnsEMBL::Production::Pipeline::Xrefs::Parser::$parser";
  eval "require $module";
  my $xref_run = $module->new($xref_dbc);
  $xref_run->run(
    { source_id => $source_id,
      rel_file => $version_file,
      dbi      => $dbi,
      file     => $file }) ;
}

1;
