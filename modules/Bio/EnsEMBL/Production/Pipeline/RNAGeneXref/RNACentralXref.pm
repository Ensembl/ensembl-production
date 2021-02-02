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
limitations under the License.

=cut

package Bio::EnsEMBL::Production::Pipeline::RNAGeneXref::RNACentralXref;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use DBI qw(:sql_types);
use Digest::MD5 qw(md5_hex);
use File::Spec::Functions qw(catdir);
use Path::Tiny;

sub run {
  my ($self) = @_;

  my $logic_name = $self->param_required('logic_name');

  my $sql = "SELECT urs FROM rnacentral WHERE md5sum = ?";
  my $dbh = $self->hive_dbh;
  my $sth = $dbh->prepare($sql) or $self->throw($dbh->errstr);

  my $dba  = $self->get_DBAdaptor('core');
  my $aa   = $dba->get_adaptor('Analysis');
  my $ba   = $dba->get_adaptor('Biotype');
  my $ta   = $dba->get_adaptor('Transcript');
  my $dbea = $dba->get_adaptor('DBEntry');

  my $analysis = $aa->fetch_by_logic_name($logic_name);

  my $snoncoding = $ba->fetch_all_by_group_object_db_type('snoncoding', 'transcript');
  my $lnoncoding = $ba->fetch_all_by_group_object_db_type('lnoncoding', 'transcript');
  my @rna_biotypes = map { $_->name } (@$snoncoding, @$lnoncoding);

  $dba->dbc && $dba->dbc->disconnect_if_idle();

  my $transcripts = $ta->fetch_all_by_biotype(\@rna_biotypes);
  foreach my $transcript (@$transcripts) {
    my $urs = $self->fetch_urs($sth, md5_hex($transcript->seq->seq));

    if (defined $urs) {
      $self->add_xref($urs, $analysis, $dbea, $transcript->dbID);
    }
  }
}

sub fetch_urs {
  my ($self, $sth, $md5sum) = @_;

  $sth->bind_param(1, $md5sum, SQL_CHAR);
  $sth->execute();

  my $urs;
  my $results = $sth->fetchall_arrayref;

  if (scalar(@$results)) {
    $urs = $$results[0][0];
    if (scalar(@$results) > 1) {
      $self->warning("Multiple URSs found for $md5sum");
    }
  }

  return $urs;
}

sub add_xref {
  my ($self, $urs, $analysis, $dbea, $transcript_id) = @_;

  my $xref = $self->create_xref($urs, $analysis);
  $dbea->store($xref, $transcript_id, 'Transcript');

  return $xref;
}

sub create_xref {
  my ($self, $urs, $analysis) = @_;

	my $xref = Bio::EnsEMBL::DBEntry->new(
    -PRIMARY_ID => $urs,
		-DISPLAY_ID => $urs,
		-DBNAME     => 'RNACentral',
		-INFO_TYPE  => 'CHECKSUM',
    -VERSION    => 1
  );
	$xref->analysis($analysis);

  return $xref;
}

1;
