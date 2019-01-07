=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

sub run {
  my ($self) = @_;
  my $species    = $self->param('species');

  $self->dbc()->disconnect_if_idle() if defined $self->dbc();

  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
  my $aa  = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'attribute');

  my %attrib_codes = $self->get_attrib_codes();
  $self->delete_old_attrib($dba, %attrib_codes);
  $self->delete_old_stats($dba, %attrib_codes);
  
  my $count;
  my $alt_count;

  my %stats_hash;
  my %stats_attrib;

  my @all_sorted_slices =
   sort( { $a->coord_system()->rank() <=> $b->coord_system()->rank()
           || $b->seq_region_length() <=> $a->seq_region_length() } @{$self->get_all_slices($species)}) ;
  while (my $slice = shift @all_sorted_slices) {
    next unless $slice->is_reference; # no alt attribs ATMO
    
    foreach my $ref_code (keys %attrib_codes) {
      $count = $self->get_feature_count($slice, $ref_code, $attrib_codes{$ref_code});
      $self->store_attrib($slice, $count, $ref_code) if $count > 0;
      $stats_hash{$ref_code} += $count;
    }    
  }
  
  $self->store_statistics($species, \%stats_hash, \%stats_attrib);

  # disconnecting from the registry
  $dba->dbc->disconnect_if_idle();
  my $prod_dba    = $self->get_production_DBAdaptor();
  $prod_dba->dbc()->disconnect_if_idle();
}

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

1;

