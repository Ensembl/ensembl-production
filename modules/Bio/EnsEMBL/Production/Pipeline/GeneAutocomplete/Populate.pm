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

=head1 NAME
Bio::EnsEMBL::Production::Pipeline::GeneAutocomplete::Populate

=head1 DESCRIPTION
Populate the gene_autocomplete table inside the ensembl_autocomplete
(formerly ensembl_website) database. This table is used on the ensembl
website "region in detail" page, when you type a name in the "gene" box.

=cut

package Bio::EnsEMBL::Production::Pipeline::GeneAutocomplete::Populate;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Bio::EnsEMBL::Utils::URI qw/parse_uri/;

sub run {
  my ($self) = @_;

  my $incremental = $self->param_required('incremental');
  my $db_url      = $self->param_required('db_url');
  my $species     = $self->param_required('species');

  # We don't support otherfeatures dbs, but if we did,
  # we'd need to add some extra code to filter out genes which
  # are configured to not display in the browser.
  my $group = 'core';
  my $dba = $self->get_DBAdaptor($group);

  # Functionality is not supported for collection databases.
  if (! $dba->is_multispecies) {
    my $uri = parse_uri($db_url);
    my $autocomplete_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
      -host   => $uri->host,
      -port   => $uri->port,
      -user   => $uri->user,
      -pass   => $uri->pass,
      -dbname => $uri->db_params->{dbname},
    );

    my $select_sql = qq/
      SELECT
        g.stable_id,
        x.display_label,
        concat(
          sr.name,
          ':',
          g.seq_region_start,
          '-',
          g.seq_region_end
        ) as location
      FROM
        gene g INNER JOIN
        xref x ON g.display_xref_id  = x.xref_id INNER JOIN
        seq_region sr ON g.seq_region_id    = sr.seq_region_id
    /;
    my $genes = $dba->dbc->sql_helper->execute(-SQL => $select_sql);
    $dba->dbc->disconnect_if_idle();

    # If it's not incremental, we will have deleted all existing
    # data in an earlier stage of the pipeline, so don't need
    # to do this for each species as well.
    if ($incremental) {
      my $delete_sql = qq/
        DELETE FROM gene_autocomplete
        WHERE species = ? AND db = ?
      /;
      $autocomplete_dba->dbc->sql_helper->execute_update(
        -SQL    => $delete_sql,
        -PARAMS => [$species, $group]
      );
    }

    my $insert_sql = qq/
      INSERT INTO
        gene_autocomplete (species, stable_id, display_label, location, db)
      VALUES
        (?,?,?,?,?)
    /;

    foreach my $gene (@$genes) {
      $autocomplete_dba->dbc->sql_helper->execute_update(
        -SQL    => $insert_sql,
	      -PARAMS => [$species, @$gene, $group]
      );
    }
    $autocomplete_dba->dbc->disconnect_if_idle();
  }
}

1;
