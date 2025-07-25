=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2025] EMBL-European Bioinformatics Institute

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
  my $species_id   = $self->param_required('species_id');
  my $file_name    = $self->param_required('file_name');
  my $source_id    = $self->param_required('source');
  my $xref_url     = $self->param_required('xref_url');
  my $source_xref  = $self->param('source_xref');
  my $db           = $self->param('db');
  my $release_file = $self->param('release_file');

  $self->dbc()->disconnect_if_idle() if defined $self->dbc();

  my ($user, $pass, $host, $port, $dbname) = $self->parse_url($xref_url);
  
  my ($source_user, $source_pass, $source_host, $source_port, $source_dbname, $source_dbi);
  if ($source_xref) {
    ($source_user, $source_pass, $source_host, $source_port, $source_dbname) = $self->parse_url($source_xref);
    $source_dbi = $self->get_dbi($source_host, $source_port, $source_user, $source_pass, $source_dbname);
  }

  my $xref_dbc = XrefParser::Database->new({
            host    => $host,
            dbname  => $dbname,
            port    => $port,
            user    => $user,
            pass    => $pass });
  $xref_dbc->disconnect_if_idle();

  my $dbi = $self->get_dbi($host, $port, $user, $pass, $dbname);

  my @files;
  push @files, $file_name;

  my $module = "XrefParser::$parser";
  eval "require $module";
  my $xref_run = $module->new($xref_dbc);
  my $failure = 0;
  if (defined $db) {
    my $registry = 'Bio::EnsEMBL::Registry';
    my $dba = $registry->get_DBAdaptor($species, $db);
    $dba->dbc()->disconnect_if_idle();
    $failure += $xref_run->run_script( { source_id  => $source_id,
                             species_id => $species_id,
                             dba        => $dba,
                             rel_file   => $release_file,
                             dbi        => $dbi,
                             species    => $species,
			     xref_source=> $source_dbi,
                             file       => $file_name}) ;
    $self->cleanup_DBAdaptor($db);
  } else {
    my $run_params = {
      source_id  => $source_id,
      species_id => $species_id,
      species    => $species,
      rel_file   => $release_file,
      dbi        => $dbi,
      xref_source => $source_dbi,
      files      => [@files]
    };
    $run_params->{hgnc_file} = $self->param('hgnc_file') if ($parser =~ /^UniProt/);
    $failure += $xref_run->run( $run_params ) ;
  }
  if ($failure) { die; }

}

1;

