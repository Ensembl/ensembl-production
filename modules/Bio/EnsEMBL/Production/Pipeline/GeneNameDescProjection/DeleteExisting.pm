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
package Bio::EnsEMBL::Production::Pipeline::GeneNameDescProjection::DeleteExisting;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::SqlHelper;

use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub run {
  my ($self) = @_;

  my $config_type = $self->param_required('config_type');

  my $helper = Bio::EnsEMBL::Utils::SqlHelper->new(
    -DB_CONNECTION => $self->core_dbc()
  );

  if ($config_type eq 'names') {
    $self->delete_gene_names($helper);
  } else {
    $self->delete_gene_descs($helper);
  }

  $self->core_dbc()->disconnect_if_idle();
}

sub delete_gene_names {
  my ($self, $helper) = @_;

  # Setting projected transcript display_xrefs amd description to NULL
  my $sql = q/
    UPDATE gene g, xref x, transcript t
      SET t.display_xref_id = NULL, t.description = NULL
    WHERE
      g.display_xref_id = x.xref_id AND
      g.gene_id = t.gene_id AND
      x.info_type = 'PROJECTION'
  /;
  $helper->execute_update(-SQL => $sql);

  # Setting gene display_xrefs that were projected to NULL
  $sql = q/
    UPDATE gene g, xref x
      SET g.display_xref_id = NULL
    WHERE
      g.display_xref_id = x.xref_id AND
      x.info_type = 'PROJECTION'
  /;
  $helper->execute_update(-SQL => $sql);

  # Deleting projected xrefs, object_xrefs and synonyms
  $sql = q/
    DELETE es FROM xref x, external_synonym es
    WHERE
      x.xref_id = es.xref_id AND
      x.info_type = 'PROJECTION'
  /;
  $helper->execute_update(-SQL => $sql);

  $sql = q/
    DELETE x, ox FROM xref x, object_xref ox, external_db e
    WHERE
      x.xref_id = ox.xref_id AND
      x.external_db_id = e.external_db_id AND
      x.info_type = 'PROJECTION' AND
      e.db_name <> 'GO'
  /;
  $helper->execute_update(-SQL => $sql);
}

sub delete_gene_descs {
  my ($self, $helper) = @_;

  my $sql = q/
    UPDATE gene g, xref x
      SET g.description = NULL
    WHERE
      g.display_xref_id = x.xref_id AND
      x.info_type = 'PROJECTION'
  /;

  $helper->execute_update(-SQL => $sql);
}

1;
