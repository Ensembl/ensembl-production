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
use Bio::EnsEMBL::Hive::Utils::URL;
use File::Basename;
use File::Spec::Functions;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;


sub run {
  my ($self) = @_;
  my $parser       = $self->param_required('parser');
  my $species      = $self->param_required('species');
  my $file_name    = $self->param_required('file_name');
  my $source       = $self->param_required('name');
  my $xref_url     = $self->param_required('xref_url');

  my $parsed_url = Bio::EnsEMBL::Hive::Utils::URL::parse($xref_url);
  my $user   = $parsed_url->{'user'};
  my $pass   = $parsed_url->{'pass'};
  my $host   = $parsed_url->{'host'};
  my $port   = $parsed_url->{'port'};
  my $dbname = $parsed_url->{'dbname'};

  my $xref_dbc = XrefParser::Database->new({
            host    => $host,
            dbname  => $dbname,
            port    => $port,
            user    => $user,
            pass    => $pass });

  my $dbconn = sprintf("dbi:mysql:host=%s;port=%s;database=%s", $host, $port, $dbname);
  my $dbi = DBI->connect( $dbconn, $user, $pass, { 'RaiseError' => 1 } ) or croak( "Can't connect to database: " . $DBI::errstr );
  my $select_species_id_sth = $dbi->prepare("SELECT species_id FROM species where name = ?");
  my $select_source_id_sth = $dbi->prepare("SELECT source_id FROM source_url WHERE parser = ? and species_id = ?");
  $select_species_id_sth->execute($species);
  my $species_id = ($select_species_id_sth->fetchrow_array())[0];
  $select_source_id_sth->execute($parser, $species_id);
  my $source_id = ($select_source_id_sth->fetchrow_array())[0];

  # Some sources are not available for all species
  if (!defined $source_id) { return; }

  my $dir = dirname($file_name);
  my @files = `ls $dir`;

  my $module = "XrefParser::$parser";
  eval "require $module";
  my $xref_run = $module->new($xref_dbc);
  $xref_run->run( { source_id  => $source_id,
                    species_id => $species_id,
                    files      => [@files] }) ;

  $select_species_id_sth->finish();
  $select_source_id_sth->finish();

}

1;

