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

package Bio::EnsEMBL::Production::Pipeline::Xrefs::ParseSource;

use strict;
use warnings;
use XrefParser::Database;
use File::Basename;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my ($self) = @_;
  my $parser       = $self->param_required('parser');
  my $species      = $self->param_required('species');
  my $file_name    = $self->param_required('file_name');
  my $source       = $self->param_required('name');
  my $xref_url     = $self->param_required('xref_url');
  my $db           = $self->param('db');
  my $release_file = $self->param('release_file');

  my ($user, $pass, $host, $port, $dbname) = $self->parse_url($xref_url);

  my $xref_dbc = XrefParser::Database->new({
            host    => $host,
            dbname  => $dbname,
            port    => $port,
            user    => $user,
            pass    => $pass });

  my $dbi = $self->get_dbi($host, $port, $user, $pass, $dbname);
  my $select_species_id_sth = $dbi->prepare("SELECT species_id FROM species where name = ?");
  $select_species_id_sth->execute($species);
  my $species_id = ($select_species_id_sth->fetchrow_array())[0];
  my $source_id = $self->get_source_id($dbi, $parser, $species_id);

  # Some sources are not available for all species
  if (!defined $source_id) { return; }

  # Some sources need connection to a species database
  my $dba;
  if (defined $db) {
    my $registry = 'Bio::EnsEMBL::Registry';
    $dba = $registry->get_DBAdaptor($species, $db);
    return unless $dba;
  }

  # Create list of files
  my $dir = dirname($file_name);
  my @list_files = `ls $dir`;
  my @files;
  foreach my $file (@list_files) {
    $file =~ s/\n//;
    $file = $dir . "/" . $file;
    if (defined $release_file and $file eq $release_file) { next; }
    push @files, $file;
  }

  my $module = "XrefParser::$parser";
  eval "require $module";
  my $xref_run = $module->new($xref_dbc);
  if (defined $dba) {
    $xref_run->run_script( { source_id  => $source_id,
                             species_id => $species_id,
                             dba        => $dba,
                             rel_file   => $release_file,
                             file       => $file_name }) ;
  } else {
    $xref_run->run( { source_id  => $source_id,
                      species_id => $species_id,
                      rel_file   => $release_file,
                      files      => [@files] }) ;
  }

  $select_species_id_sth->finish();

}

1;

