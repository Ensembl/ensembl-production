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

package Bio::EnsEMBL::Production::Pipeline::Production::GeneCount;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref assert_integer wrap_array);


use base qw/Bio::EnsEMBL::Production::Pipeline::Production::StatsGenerator/;

sub run {
  my ($self) = @_;
  my $species    = $self->param('species');

  $self->dbc()->disconnect_if_idle() if defined $self->dbc();

  my $dba        = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
  my $ta         = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'transcript');
  my $aa         = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'attribute');

  my $has_readthrough = 0;
  my @readthroughs = @{ $aa->fetch_all_by_Transcript(undef, 'readthrough_tra') };
  $has_readthrough = 1 if @readthroughs;

  my %attrib_codes = $self->get_attrib_codes($has_readthrough);
  $self->delete_old_attrib($dba, %attrib_codes);
  $self->delete_old_stats($dba, %attrib_codes);
  
  my %alt_attrib_codes = $self->get_alt_attrib_codes($has_readthrough);
  $self->delete_old_attrib($dba, %alt_attrib_codes);
  $self->delete_old_stats($dba, %alt_attrib_codes);
  
  my $count;
  my $alt_count;

  my %stats_hash;
  my %stats_attrib;

  my $ref_length = $self->get_ref_length();
  $stats_hash{ref_length} = $ref_length if $ref_length;
  
  my $total_length = $self->get_total_length();
  $stats_hash{total_length} = $total_length if $total_length;

  my @all_sorted_slices =
   sort( { $a->coord_system()->rank() <=> $b->coord_system()->rank()
           || $b->seq_region_length() <=> $a->seq_region_length() } @{$self->get_all_slices($species)}) ;
  while (my $slice = shift @all_sorted_slices) {
    next if $slice->seq_region_name =~ /LRG/;
    
    if ($slice->is_reference) {
      $stats_hash{'transcript'} += $ta->count_all_by_Slice($slice);
      $stats_attrib{'transcript'} = 'transcript_cnt';
      
      foreach my $ref_code (keys %attrib_codes) {
        $count = $self->get_feature_count($slice, $ref_code, $attrib_codes{$ref_code});
	$self->store_attrib($slice, $count, $ref_code) if $count > 0;
        $stats_hash{$ref_code} += $count;
      }
      
      $count = $self->get_attrib($slice, 'noncoding_cnt_%');
      $self->store_attrib($slice, $count, 'noncoding_cnt') if $count > 0;
      
      $stats_hash{'noncoding_cnt'} += $count;
      $stats_attrib{'noncoding_cnt'} = 'noncoding_cnt';
      
    } else {
      my $sa = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice');
      my $alt_slices = $sa->fetch_by_region_unique($slice->coord_system->name(), $slice->seq_region_name());
      
      foreach my $alt_slice (@$alt_slices) {
        $stats_hash{'alt_transcript'} += $ta->count_all_by_Slice($alt_slice);
        $stats_attrib{'alt_transcript'} = 'transcript_acnt';
	
        foreach my $alt_code (keys %alt_attrib_codes) {
          $alt_count = $self->get_feature_count($alt_slice, $alt_code, $alt_attrib_codes{$alt_code});
	  $self->store_attrib($slice, $alt_count, $alt_code) if $alt_count > 0;
          $stats_hash{$alt_code} += $alt_count;
        }
	
        $alt_count = $self->get_attrib($slice, 'noncoding_acnt_%');
	$self->store_attrib($slice, $alt_count, 'noncoding_acnt') if $alt_count > 0;
	
        $stats_hash{'noncoding_acnt'} += $alt_count;
        $stats_attrib{'noncoding_acnt'} = 'noncoding_acnt';
      }
    }    
  }
  
  $self->store_statistics($species, \%stats_hash, \%stats_attrib);

  # disconnecting from the registry
  $dba->dbc->disconnect_if_idle();
  my $prod_dba    = $self->get_production_DBAdaptor();
  $prod_dba->dbc()->disconnect_if_idle();
}

sub get_attrib_codes {
  my ($self, $has_readthrough) = @_;
  my @attrib_codes = ('coding_cnt', 'pseudogene_cnt', 'noncoding_cnt_s', 'noncoding_cnt_l', 'noncoding_cnt_m');
  if ($has_readthrough) {
    push @attrib_codes, ('coding_rcnt', 'pseudogene_rcnt', 'noncoding_rcnt_s', 'noncoding_rcnt_l', 'noncoding_rcnt_m');
  }
  my %biotypes;
  foreach my $code (@attrib_codes) {
    my ($group, $subgroup) = $code =~ /(\w+)\_r?cnt_?([a-z]?)/;
    if ($subgroup) { $group = $subgroup . $group; }
    my $biotypes = $self->get_biotype_group($group);
    $biotypes{$code} = $biotypes;
  }
  return %biotypes;
}

sub get_alt_attrib_codes {
  my ($self, $has_readthrough) = @_;
  my @alt_attrib_codes = ('coding_acnt', 'pseudogene_acnt', 'noncoding_acnt_s', 'noncoding_acnt_l', 'noncoding_acnt_m');
  if ($has_readthrough) {
    push @alt_attrib_codes, ('coding_racnt', 'pseudogene_racnt', 'noncoding_racnt_s', 'noncoding_racnt_l', 'noncoding_racnt_m');
  }
  my %biotypes;
  foreach my $alt_code (@alt_attrib_codes) {
    my ($group, $subgroup) = $alt_code =~ /(\w+)\_r?acnt_?([a-z]?)/;
    if ($subgroup) { $group = $subgroup . $group; }
    my $biotypes = $self->get_biotype_group($group);
    $biotypes{$alt_code} = $biotypes;
  }
  return %biotypes;
}

sub get_total {
  my ($self) = @_;
  my $species = $self->param('species');
  my $total = scalar(@{ Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'gene')->fetch_all });
  return $total;
}

sub get_ref_length {
  my ($self) = @_;
  my $species = $self->param('species');
  my @slices = @{ Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice')->fetch_all('toplevel') };
  my $ref_length = 0;
  foreach my $slice (@slices) {
    $ref_length += $slice->length();
  }
  return $ref_length;
}

sub get_total_length {
  my ($self) = @_;
  my $species = $self->param('species');
  my @slices = @{ Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice')->fetch_all('seqlevel') };
  my $total_length = 0;
  foreach my $slice (@slices) {
    $total_length += $slice->length();
  }
  return $total_length;
}

sub get_slices {
  my ($self, $species) = @_;
  my @slices;
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
  my $sa = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice');
  my $helper = $dba->dbc()->sql_helper();
  my $sql = q{
    SELECT DISTINCT seq_region_id FROM gene 
join seq_region using (seq_region_id)
join coord_system cs using (coord_system_id)
    WHERE cs.species_id=? AND seq_region_id NOT IN 
    (SELECT seq_region_id 
    FROM seq_region_attrib sa, attrib_type at
    WHERE at.attrib_type_id = sa.attrib_type_id
    AND at.code= "non_ref") };
  my @ids = @{ $helper->execute_simple(-SQL => $sql, -PARAMS=>[$dba->species_id()]) };
  foreach my $id(@ids) {
    push @slices, $sa->fetch_by_seq_region_id($id);
  }
  $dba->dbc()->disconnect_if_idle();
  $sa->dbc()->disconnect_if_idle();
  return \@slices;
}

sub get_all_slices {
  my ($self, $species) = @_;
  my @slices;
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
  my $sa = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice');
  my $helper = $dba->dbc()->sql_helper();
  my $sql = q{
    SELECT DISTINCT seq_region_id FROM gene join seq_region using (seq_region_id) join coord_system using (coord_system_id) where species_id=? };
  my @ids = @{ $helper->execute_simple(-SQL => $sql, -PARAMS=>[$dba->species_id()]) };
  foreach my $id(@ids) {
    push @slices, $sa->fetch_by_seq_region_id($id);
  }
  $dba->dbc()->disconnect_if_idle();
  $sa->dbc()->disconnect_if_idle();
  return \@slices;
}


sub get_feature_count {
  my ($self, $slice, $key, $biotypes) = @_;
  my $species = $self->param('species');
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
  my $helper = $dba->dbc()->sql_helper();
  if ($key =~ /_ra?cnt/) {
    my $slice_id = $slice->get_seq_region_id();
    my $sql = q{
       SELECT COUNT(distinct(g.gene_id)) FROM gene g, transcript t, transcript_attrib ta, attrib_type at
       WHERE g.gene_id=t.gene_id AND t.transcript_id=ta.transcript_id AND ta.attrib_type_id=at.attrib_type_id
       AND at.code='readthrough_tra' AND g.seq_region_id = ? AND g.biotype in 
    }; 
    $sql .= "(" .join(q{,}, map { qq{'${_}'} } @{$biotypes}) . ")" ;
    my $count = $helper->execute_single_result(-SQL => $sql, -PARAMS=>[$slice_id]);
    return $count;
  }
  my $ga = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'gene');
  return $ga->count_all_by_Slice($slice, $biotypes);
}


1;

