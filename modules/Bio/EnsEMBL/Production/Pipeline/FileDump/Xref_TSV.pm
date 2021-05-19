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

  my $filename = $$filenames{$data_type};
  my $file = path($filename);

  $self->print_xrefs($file, $external_dbs);

  $file->spew($self->header, sort $file->lines);
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

sub header {
  my ($self) = @_;

  join("\t",
    qw(
      gene_stable_id transcript_stable_id protein_stable_id
      xref_id xref_label description db_name info_type
      source ensembl_identity xref_identity
    )
  );
}

sub print_xrefs {
  my ($self, $file, $external_dbs) = @_;

  # It takes a long time to use the API to retrieve the xrefs,
  # and the code would also need to be quite complicated.
  # Direct SQL queries are two orders of magnitude quicker,
  # and although there are a lot of joins are probably easier
  # to understand and maintain.

  my $edb_filter = '';
  if (scalar(@$external_dbs)) {
    my $external_db_list = join(", ", map { "'$_'" } @$external_dbs);
    $edb_filter = " AND e.db_name in ($external_db_list) ";
  }

  $self->print_xref_subset( $file, $self->go_xref_sql($edb_filter) );
  $self->print_xref_subset( $file, $self->gene_xref_sql($edb_filter) );
  $self->print_xref_subset( $file, $self->transcript_xref_sql($edb_filter) );
  $self->print_xref_subset( $file, $self->translation_xref_sql($edb_filter) );
}

sub print_xref_subset {
  my ($self, $file, $sql) = @_;

  my $helper  = $self->dba->dbc->sql_helper;
  my $results = $helper->execute(
    -SQL => $sql,
    -CALLBACK => sub {
                   my @row = @{ shift @_ };
                   return { join("\t", @row) };
                 }
  );

  $file->spew(join("\n", @$results));
}

sub go_xref_sql {
  my ($self, $external_db_filter) = @_;

  my $sql = qq/
    select
      g.stable_id as gene_stable_id,
      t.stable_id as transcript_stable_id,
      coalesce(tn.stable_id, "") as protein_stable_id,
      x.dbprimary_acc as xref_id,
      x.display_label as xref_label,
      coalesce(x.description, ""),
      e.db_display_name as db_name,
      x.info_type,
      coalesce(group_concat(distinct replace(e2.db_display_name, " generic accession number (TrEMBL or SwissProt not differentiated)", ""), ":", x2.dbprimary_acc, ":", linkage_type separator "; "), "") as source,
      "" as ensembl_identity,
      "" as xref_identity
    from
      gene g inner join
      transcript t using (gene_id) left outer join
      translation tn using (transcript_id) inner join
      object_xref ox on t.transcript_id = ox.ensembl_id inner join
      xref x on ox.xref_id = x.xref_id inner join
      external_db e on x.external_db_id = e.external_db_id inner join
      ontology_xref ontx on ox.object_xref_id = ontx.object_xref_id inner join
      xref x2 on ontx.source_xref_id = x2.xref_id inner join
      external_db e2 on x2.external_db_id = e2.external_db_id
    where
      ox.ensembl_object_type = "Transcript" and
      e.db_display_name = "GO" $external_db_filter
    group by
      g.stable_id,
      t.stable_id,
      tn.stable_id,
      x.dbprimary_acc,
      x.display_label,
      x.description,
      e.db_display_name
  /;

  return $sql;
}

sub gene_xref_sql {
  my ($self, $external_db_filter) = @_;

  my $sql = qq/
    select
      g.stable_id as gene_stable_id,
      "",
      "",
      x.dbprimary_acc as xref_id,
      x.display_label as xref_label,
      coalesce(x.description, ""),
      e.db_display_name as db_name,
      x.info_type,
      coalesce(group_concat(e2.db_display_name, ":", x2.dbprimary_acc separator'; '), "") as dependent_sources,
      coalesce(ix.ensembl_identity, ""),
      coalesce(ix.xref_identity, "")
    from
      gene g inner join
      object_xref ox on g.gene_id = ox.ensembl_id inner join
      xref x on ox.xref_id = x.xref_id inner join
      external_db e on x.external_db_id = e.external_db_id left outer join
      identity_xref ix on ox.object_xref_id = ix.object_xref_id left outer join
      dependent_xref dx on ox.object_xref_id = dx.object_xref_id left outer join
      xref x2 on dx.master_xref_id = x2.xref_id left outer join
      external_db e2 on x2.external_db_id = e2.external_db_id
    where
      ox.ensembl_object_type = "Gene" and
      e.db_display_name <> "GO" $external_db_filter
    group by
      g.stable_id,
      x.dbprimary_acc,
      x.display_label,
      x.description,
      e.db_display_name,
      ix.ensembl_identity,
      ix.xref_identity
  /;

  return $sql;
}

sub transcript_xref_sql {
  my ($self, $external_db_filter) = @_;

  my $sql = qq/
    select
      g.stable_id as gene_stable_id,
      t.stable_id as transcript_stable_id,
      coalesce(tn.stable_id, "") as protein_stable_id,
      x.dbprimary_acc as xref_id,
      x.display_label as xref_label,
      coalesce(x.description, ""),
      e.db_display_name as db_name,
      x.info_type,
      coalesce(group_concat(e2.db_display_name, ":", x2.dbprimary_acc separator'; '), "") as dependent_sources,
      coalesce(ix.ensembl_identity, ""),
      coalesce(ix.xref_identity, "")
    from
      gene g inner join
      transcript t using (gene_id) left outer join
      translation tn using (transcript_id) inner join
      object_xref ox on t.transcript_id = ox.ensembl_id inner join
      xref x on ox.xref_id = x.xref_id inner join
      external_db e on x.external_db_id = e.external_db_id left outer join
      identity_xref ix on ox.object_xref_id = ix.object_xref_id left outer join
      dependent_xref dx on ox.object_xref_id = dx.object_xref_id left outer join
      xref x2 on dx.master_xref_id = x2.xref_id left outer join
      external_db e2 on x2.external_db_id = e2.external_db_id
    where
      ox.ensembl_object_type = "Transcript" and
      e.db_display_name <> "GO" $external_db_filter
    group by
      g.stable_id,
      t.stable_id,
      tn.stable_id,
      x.dbprimary_acc,
      x.display_label,
      x.description,
      e.db_display_name,
      ix.ensembl_identity,
      ix.xref_identity
  /;

  return $sql;
}

sub translation_xref_sql {
  my ($self, $external_db_filter) = @_;

  my $sql = qq/
    select
      g.stable_id as gene_stable_id,
      t.stable_id as transcript_stable_id,
      tn.stable_id as protein_stable_id,
      x.dbprimary_acc as xref_id,
      x.display_label as xref_label,
      coalesce(x.description, ""),
      e.db_display_name as db_name,
      x.info_type,
      coalesce(group_concat(e2.db_display_name, ":", x2.dbprimary_acc separator'; '), "") as dependent_sources,
      coalesce(ix.ensembl_identity, ""),
      coalesce(ix.xref_identity, "")
    from
      gene g inner join
      transcript t using (gene_id) left outer join
      translation tn using (transcript_id) inner join
      object_xref ox on tn.translation_id = ox.ensembl_id inner join
      xref x on ox.xref_id = x.xref_id inner join
      external_db e on x.external_db_id = e.external_db_id left outer join
      identity_xref ix on ox.object_xref_id = ix.object_xref_id left outer join
      dependent_xref dx on ox.object_xref_id = dx.object_xref_id left outer join
      xref x2 on dx.master_xref_id = x2.xref_id left outer join
      external_db e2 on x2.external_db_id = e2.external_db_id
    where
      ox.ensembl_object_type = "Translation" and
      e.db_display_name <> "GO" $external_db_filter
    group by
      g.stable_id,
      t.stable_id,
      tn.stable_id,
      x.dbprimary_acc,
      x.display_label,
      x.description,
      e.db_display_name,
      ix.ensembl_identity,
      ix.xref_identity
  /;

  return $sql;
}

1;
