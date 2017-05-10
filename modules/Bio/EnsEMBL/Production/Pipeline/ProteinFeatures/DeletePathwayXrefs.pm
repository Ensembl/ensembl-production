=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::EGPipeline::ProteinFeatures::DeletePathwayXrefs;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

sub run {
  my ($self) = @_;
  
  my $pathway_sources = $self->param('pathway_sources') || [];
  
  my $delete_xref_sql =
    'DELETE x.* FROM '.
    'xref x LEFT OUTER JOIN '.
    'object_xref ox ON x.xref_id = ox.xref_id INNER JOIN '.
    'external_db edb ON x.external_db_id = edb.external_db_id '.
    'WHERE edb.db_name = ? AND ox.xref_id IS NULL;';
  my $delete_xref_sth = $self->core_dbh->prepare($delete_xref_sql);
  
  foreach my $db_name (@{$pathway_sources}) {
    $delete_xref_sth->execute($db_name);
  }
}

1;
