=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Production::SnpDensity;

use base qw/Bio::EnsEMBL::Production::Pipeline::Production::DensityGenerator/;


use strict;
use warnings;



sub get_density {
  my ($self, $block) = @_;
  my $variation_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($self->param('species'), 'variation');
  my $helper = $variation_adaptor->dbc()->sql_helper();
  my $sql = q{
     SELECT count(*) FROM variation_feature
     WHERE seq_region_id = ?
     AND seq_region_start <= ?
     AND seq_region_end >= ? };
  my @params = [$block->get_seq_region_id, $block->end, $block->start];
  my $count = $helper->execute_single_result(-SQL => $sql, -PARAMS => @params);
  return $count;
}

sub get_total {
  my ($self, $option) = @_;
  my $species = $self->param('species');
  my $variation_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'variation');
  my $helper = $variation_adaptor->dbc()->sql_helper();
  my $sql = "SELECT count(*) FROM variation_feature";
  return $helper->execute_single_result(-SQL => $sql);
}

return 1;

