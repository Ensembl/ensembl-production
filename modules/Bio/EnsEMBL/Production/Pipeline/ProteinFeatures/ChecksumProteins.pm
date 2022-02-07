=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::ChecksumProteins;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Bio::SeqIO;
use DBI qw(:sql_types);
use Digest::MD5 qw(md5_hex);
use File::Spec::Functions qw(catdir);
use Path::Tiny;

sub run {
  my ($self) = @_;

  my $fasta_file         = $self->param_required('fasta_file');
  my $uniparc_xrefs      = $self->param_required('uniparc_xrefs');
  my $uniprot_xrefs      = $self->param_required('uniprot_xrefs');
  my $uniparc_logic_name = $self->param_required('uniparc_logic_name');
  my $uniprot_logic_name = $self->param_required('uniprot_logic_name');

  my $fasta = path($fasta_file);
  my $out_dir = $fasta->parent;
  my $basename = $fasta->basename;
  my $checksum_file = catdir($out_dir, 'checksum', $basename);
  my $nochecksum_file = catdir($out_dir, 'nochecksum', $basename);
  path($checksum_file)->parent->mkpath;
  path($nochecksum_file)->parent->mkpath;

  $self->param('checksum_file', $checksum_file);
  $self->param('nochecksum_file', $nochecksum_file);
  
  my $all        = Bio::SeqIO->new(-format => 'Fasta', -file => $fasta_file);
  my $checksum   = Bio::SeqIO->new(-format => 'Fasta', -file => ">$checksum_file");
  my $nochecksum = Bio::SeqIO->new(-format => 'Fasta', -file => ">$nochecksum_file");

  my $uniparc_sql = qq/
    SELECT upi FROM uniparc
    WHERE md5sum = ?
    /;
  my $dbh = $self->hive_dbh;
  my $uniparc_sth = $dbh->prepare($uniparc_sql) or $self->throw($dbh->errstr);

  my ($uniparc_analysis, $uniprot_analysis, $uniprot_sth, $dbea);
  if ($uniparc_xrefs) {
    my $dba = $self->get_DBAdaptor('core');
    my $aa = $dba->get_adaptor('Analysis');
    $dbea = $dba->get_adaptor('DBEntry');

    $uniparc_analysis = $aa->fetch_by_logic_name($uniparc_logic_name);
    $self->external_db_reset($dba, 'UniParc');

    if ($uniprot_xrefs) {
      # If our species has a tax_id at a 'subspecies' level,
      # we also annotate UniProt entries for the parent 'species',
      # for which we need the taxonomy db.
      my $tba = $self->get_DBAdaptor('taxonomy');
      my $tna = $tba->get_adaptor('TaxonomyNode');

      my $tax_id = $dba->get_adaptor('MetaContainer')->get_taxonomy_id();
      my @tax_ids = ($tax_id);
      my $node = $tna->fetch_by_taxon_id($tax_id);
      if (defined $node) {
        if ($node->rank ne 'species') {
          if ($node->parent->rank eq 'species') {
            push @tax_ids, $node->parent->taxon_id;
          }
        }
      }
      my $tax_ids = join(",", @tax_ids);

      $uniprot_analysis = $aa->fetch_by_logic_name($uniprot_logic_name);
      $self->external_db_reset($dba, 'UniProtKB_all');
      $self->external_db_reset($dba, 'Uniprot/Varsplic');

      my $uniprot_sql = qq/
        SELECT acc FROM uniprot
        WHERE upi = ? and tax_id IN ($tax_ids)
      /;
      $uniprot_sth = $dbh->prepare($uniprot_sql) or $self->throw($dbh->errstr);
    }

    $dba->dbc && $dba->dbc->disconnect_if_idle();
  }

  while (my $seq = $all->next_seq) {
    my $upi = $self->fetch_upi($uniparc_sth, md5_hex($seq->seq));

    if (defined $upi) {
      my $success = $checksum->write_seq($seq);
      $self->throw("Failed to write sequence to '$checksum_file'") unless $success;

      if ($uniparc_xrefs) {
        my $uniparc_xref = $self->add_uniparc_xref($upi, $uniparc_analysis, $dbea, $seq->id);
        if ($uniprot_xrefs) {
          my $accs = $self->fetch_acc($uniprot_sth, $upi);
          if (scalar(@$accs)) {
            $self->add_uniprot_xref($accs, $uniprot_analysis, $dbea, $seq->id, $uniparc_xref);
          }
        }
      }
    } else {
      my $success = $nochecksum->write_seq($seq);
      $self->throw("Failed to write sequence to '$nochecksum_file'") unless $success;
    }
  }
}

sub write_output {
  my ($self) = @_;
  
  $self->dataflow_output_id({'checksum_file' => $self->param('checksum_file')}, 3);
  $self->dataflow_output_id({'nochecksum_file' => $self->param('nochecksum_file')}, 4);
}

sub external_db_reset {
  my ($self, $dba, $db_name) = @_;

  my $dbh = $dba->dbc->db_handle();
  my $sql = "UPDATE external_db SET db_release = NULL WHERE db_name = ?;";
  my $sth = $dbh->prepare($sql);
  $sth->execute($db_name) or $self->throw("Failed to execute ($db_name): $sql");
}

sub fetch_upi {
  my ($self, $sth, $md5sum) = @_;

  $sth->bind_param(1, $md5sum, SQL_CHAR);
  $sth->execute();

  my $upi;
  my $results = $sth->fetchall_arrayref;

  if (scalar(@$results)) {
    $upi = $$results[0][0];
    if (scalar(@$results) > 1) {
      $self->warning("Multiple UPIs found for $md5sum");
    }
  }

  return $upi;
}

sub add_uniparc_xref {
  my ($self, $upi, $analysis, $dbea, $translation_id) = @_;

  my $xref = $self->create_uniparc_xref($upi, $analysis);
  $dbea->store($xref, $translation_id, 'Translation');

  return $xref;
}

sub create_uniparc_xref {
  my ($self, $upi, $analysis) = @_;

	my $xref = Bio::EnsEMBL::DBEntry->new(
    -PRIMARY_ID => $upi,
		-DISPLAY_ID => $upi,
		-DBNAME     => 'UniParc',
		-INFO_TYPE  => 'CHECKSUM',
  );
	$xref->analysis($analysis);

  return $xref;
}

sub fetch_acc {
  my ($self, $sth, $upi) = @_;

  $sth->bind_param(1, $upi, SQL_CHAR);
  $sth->execute();

  my @accs = map {@$_} @{ $sth->fetchall_arrayref };

  return \@accs;
}

sub add_uniprot_xref {
  my ($self, $accs, $analysis, $dbea, $translation_id, $uniparc_xref) = @_;

  foreach my $acc (@$accs) {
    my $xref = $self->create_uniprot_xref($acc, $analysis);
    $dbea->store($xref, $translation_id, 'Translation', undef, $uniparc_xref);
  }
}

sub create_uniprot_xref {
  my ($self, $acc, $analysis) = @_;

  my $external_db = 'UniProtKB_all';
  $external_db = 'Uniprot/Varsplic' if $acc =~ /\-\d+$/;

	my $xref = Bio::EnsEMBL::DBEntry->new(
    -PRIMARY_ID => $acc,
		-DISPLAY_ID => $acc,
		-DBNAME     => $external_db,
		-INFO_TYPE  => 'DEPENDENT',
  );
	$xref->analysis($analysis);

  return $xref;
}

1;
