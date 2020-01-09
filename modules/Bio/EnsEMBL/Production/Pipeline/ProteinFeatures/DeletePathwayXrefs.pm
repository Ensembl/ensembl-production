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

package Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::DeletePathwayXrefs;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub run {
  my ($self) = @_;
  
  my $pathway_sources = $self->param('pathway_sources') || [];
  
  my $species_id = $self->core_dba()->species_id();

  my $delete_xref_sql =
    q/DELETE x.* 
    FROM 
    xref x 
    LEFT OUTER JOIN object_xref ox ON x.xref_id = ox.xref_id 
    JOIN external_db edb ON x.external_db_id = edb.external_db_id
    JOIN translation t ON (ox.ensembl_id=t.translation_id)
    JOIN transcript tl USING (transcript_id)
    JOIN seq_region s USING (seq_region_id)
    JOIN coord_system c USING (coord_system_id)
    WHERE 
    edb.db_name = ? AND ox.xref_id IS NULL
    AND ox.ensembl_object_type='Translation'
    AND c.species_id=?/;
  my $delete_xref_sth = $self->core_dbh->prepare($delete_xref_sql);
  
  foreach my $db_name (@{$pathway_sources}) {
    $delete_xref_sth->execute($db_name, $species_id);
  }
}

1;
