=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Xref_TSV;

use strict;
use warnings;
use feature 'say';
use base qw(Bio::EnsEMBL::Production::Pipeline::FileDump::Base_Filetype);

use File::Spec::Functions qw/catdir/;
use Path::Tiny;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    timestamped  => 1,
    data_type    => 'xref',
    file_type    => 'tsv',
    external_dbs => [],
  };
}

sub run {
  my ($self) = @_;

  my $data_type    = $self->param_required('data_type');
  my $external_dbs = $self->param_required('external_dbs');
  my $filenames    = $self->param_required('filenames');

  my $dba = $self->dba;

  # The API code accepts '%' as a pattern-matching character, so this
  # is an easy way to get all xrefs, if no external_dbs are given.
  if (scalar @$external_dbs == 0) {
    push @$external_dbs, '%';
  }

  my $ga = $dba->get_adaptor('Gene');

  my ($chr, $non_chr, $non_ref) = $self->get_slices($dba);
  my @all_slices = (@$chr, @$non_chr, @$non_ref);

  my $filename = $$filenames{$data_type};

  my $fh = path($filename)->filehandle('>');
  $self->print_header($fh);

  while (my $slice = shift @all_slices) {
    my $genes = $ga->fetch_all_by_Slice($slice);
    $self->print_xrefs($fh, $genes, $external_dbs);
  }
}

sub timestamp {
  my ($self, $dba) = @_;

  $self->throw("Missing dba parameter: timestamp method") unless defined $dba;

  my $sql = qq/
    SELECT MAX(DATE_FORMAT(update_time, "%Y%m%d")) FROM
      information_schema.tables
    WHERE
      table_schema = database() AND
      table_name LIKE "%xref"
  /;
  my $result = $dba->dbc->sql_helper->execute_simple(-SQL => $sql);

  if (scalar(@$result)) {
    return $result->[0];
  } else {
    return Time::Piece->new->date("");
  }
}

sub print_header {
  my ($self, $fh) = @_;
  
  say $fh join("\t",
    qw(
      gene_stable_id transcript_stable_id protein_stable_id
      xref_id xref_label description db_name info_type
      dependent_sources ensembl_identity xref_identity linkage_type
    )
  );
}

sub print_xrefs {
  my ($self, $fh, $genes, $external_dbs) = @_;

  while (my $gene = shift @{$genes}) {
    my $g_id = $gene->stable_id;
    my %xrefs;

    foreach my $external_db (@$external_dbs) {
      my $xref_list = $gene->get_all_DBEntries($external_db);
      push @{$xrefs{'-'}{'-'}}, @$xref_list;
    }

    my $transcripts = $gene->get_all_Transcripts;
    foreach my $transcript (@$transcripts) {
      my $tn_id = defined($transcript->translation) ? $transcript->translation->stable_id : '-';

      foreach my $external_db (@$external_dbs) {
        my $xref_list = $transcript->get_all_DBLinks($external_db);
        push @{$xrefs{$transcript->stable_id}{$tn_id}}, @$xref_list;
      }
    }
    foreach my $tt_id (sort keys %xrefs) {
      foreach my $tn_id (sort keys %{$xrefs{$tt_id}}) {
        foreach my $xref (sort {$a->primary_id cmp $b->primary_id} @{$xrefs{$tt_id}{$tn_id}}) {
          my $xref_id    = $xref->primary_id;
          my $xref_label = $xref->display_id;
          my $xref_db    = $xref->db_display_name;
          my $xref_desc  = $xref->description || '';
          my $info_type  = $xref->info_type;

          my $ensembl_identity = '';
          my $xref_identity    = '';
          if ($xref->isa('Bio::EnsEMBL::IdentityXref')) {
            $ensembl_identity = $xref->ensembl_identity;
            $xref_identity = $xref->xref_identity; 
          }

          my @master_xrefs;
          my $linkage_type = '';
          if ($xref->isa('Bio::EnsEMBL::OntologyXref')) {
            @master_xrefs = map { $_->[1] } @{ $xref->get_all_linkage_info };
            $linkage_type = join('; ', @{$xref->get_all_linkage_types});
          } else {
            @master_xrefs = @{ $xref->get_all_masters };
          }
          my @sources = map { $_->db_display_name . ':' . $_->primary_id } @master_xrefs;
          my $sources = '' . join('; ', @sources);

          say $fh join("\t",
            $g_id, $tt_id, $tn_id,
            $xref_id, $xref_label, $xref_desc, $xref_db, $info_type,
            $sources, $ensembl_identity, $xref_identity, $linkage_type
          );
        }
      }
    }
  }
}

1;
