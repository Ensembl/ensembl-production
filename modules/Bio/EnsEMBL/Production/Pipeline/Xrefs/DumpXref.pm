=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.


=head1 DESCRIPTION

Produces FASTA dumps of sequence from Xref sources that we have parsed
Normally used for RefSeq (transcript and protein), Uniprot proteins, miRBase transcripts and UniGene genes

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::DumpXref;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;
use File::Path qw/make_path/;
use File::Spec;
use File::Basename;
use File::Spec::Functions;
use IO::File;
use XrefParser::Database;

sub run {
  my ($self) = @_;

  my $species   = $self->param_required('species');
  my $base_path = $self->param_required('base_path');
  my $xref_url  = $self->param_required('xref_url');
  my $file_path = $self->param_required('file_path');
  my $seq_type  = $self->param_required('seq_type');

  my ($user, $pass, $host, $port, $dbname);
  my $parsed_url = Bio::EnsEMBL::Hive::Utils::URL::parse($xref_url);
  $user = $parsed_url->{'user'};
  $pass = $parsed_url->{'pass'};
  $host = $parsed_url->{'host'};
  $port = $parsed_url->{'port'};
  $dbname = $parsed_url->{'dbname'};
  my $dbc = XrefParser::Database->new({
            host    => $host,
            dbname  => $dbname,
            port    => $port,
            user    => $user,
            pass    => $pass });

  my $dbconn = sprintf( "dbi:mysql:host=%s;port=%s;database=%s", $host, $port, $dbname);
  my $dbi = DBI->connect( $dbconn, $user, $pass, { 'RaiseError' => 1 } ) or croak( "Can't connect to database: " . $DBI::errstr );
  my $sequence_sth = $dbi->prepare("SELECT p.xref_id, p.sequence, x.species_id , x.source_id FROM primary_xref p, xref x WHERE p.xref_id = x.xref_id AND p.sequence_type = ?");

  my $full_path = File::Spec->catfile($base_path, $species, 'xref');
  make_path($full_path);
  my $filename = File::Spec->catfile($full_path, "$seq_type.fasta");
  open( my $DH,">", $filename) || die "Could not open $filename";

  $sequence_sth->execute($seq_type);
  my $count = 0;
  while(my @row = $sequence_sth->fetchrow_array()){
    $count++;
    # Ambiguous peptides must be cleaned out to protect Exonerate from J,O and U codes
    $row[1] = uc($row[1]);
    $row[1] =~ s/(.{60})/$1\n/g;
    if ($seq_type eq 'pep') { $row[1] =~ tr/JOU/X/ }
    print $DH ">".$row[0]."\n".$row[1]."\n";
  }

  close $DH;
  $sequence_sth->finish();

  if ($count > 0) {
    my $dataflow_params = {
      species       => $species,
      ensembl_fasta => $file_path,
      seq_type      => $seq_type,
      xref_url      => $xref_url,
      xref_fasta    => $filename
    };
    $self->dataflow_output_id($dataflow_params, 2);
  }
  return;
}

1;
