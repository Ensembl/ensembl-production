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

package Bio::EnsEMBL::Production::Pipeline::Production::SnpCount;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Production::StatsGenerator/;



sub get_feature_count {
  my ($self, $slice, $key) = @_;
  my $variation_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($self->param('species'), 'variation');
  my $helper = $variation_adaptor->dbc()->sql_helper();
  my $sql = q{
     SELECT count(*) FROM variation_feature
     WHERE seq_region_id = ? };
  my @params = [$slice->get_seq_region_id];
  my $count = $helper->execute_single_result(-SQL => $sql, -PARAMS => @params);
  return $count;
}


sub get_total {
  my ($self) = @_;
  my $variation_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($self->param('species'), 'variation');
  my $helper = $variation_adaptor->dbc()->sql_helper();
  my $sql = q{
     SELECT count(*) FROM variation_feature };
  my $count = $helper->execute_single_result(-SQL => $sql);
  return $count;
}


sub get_slices {
  my ($self, $species) = @_;
  my @slices;
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'variation');
  my $sa = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice');
  my $helper = $dba->dbc()->sql_helper();
  my $sql = q{
    SELECT DISTINCT seq_region_id FROM variation_feature };
  my @ids = @{ $helper->execute_simple(-SQL => $sql) };
  foreach my $id(@ids) {
    push @slices, $sa->fetch_by_seq_region_id($id);
  }
  return \@slices;
}


sub get_attrib_codes {
  my ($self) = @_;
  my $prod_dba   = $self->get_production_DBAdaptor();
  my $prod_helper     = $prod_dba->dbc()->sql_helper();
  my $sql = q{
    SELECT code, name
    FROM attrib_type
    WHERE code = 'SNPCount' };
  my %attrib_codes = %{ $prod_helper->execute_into_hash(-SQL => $sql) };
  return %attrib_codes;
}

# Blank as I don't think there are any alt attrib codes for this ATMO
sub get_alt_attrib_codes {
  my ($self) = @_;
  return;
}


1;

