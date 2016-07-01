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

package Bio::EnsEMBL::Production::Pipeline::Production::StatsGenerator;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;


use Bio::EnsEMBL::Attribute;

sub run {
  my ($self) = @_;
  my $species    = $self->param('species');
  my $dba        = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
  my $ta         = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'transcript');
  my $aa         = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'attribute');

  my $has_readthrough = 0;
  my @readthroughs = @{ $aa->fetch_all_by_Transcript(undef, 'readthrough_tra') };
  if (@readthroughs) {
    $has_readthrough = 1;
  }

  my %attrib_codes = $self->get_attrib_codes($has_readthrough);
  $self->delete_old_attrib($dba, %attrib_codes);
  $self->delete_old_stats($dba, %attrib_codes);
  my %alt_attrib_codes = $self->get_alt_attrib_codes($has_readthrough);
  $self->delete_old_attrib($dba, %alt_attrib_codes);
  $self->delete_old_stats($dba, %alt_attrib_codes);
  my $total = $self->get_total();
  my $sum = 0;
  my $count;
  my $alt_count;
  my %slices_hash;
  my %stats_hash;
  my %stats_attrib;
  my $ref_length = $self->get_ref_length();
  if ($ref_length) {
    $stats_hash{ref_length} = $ref_length;
  }
  my $total_length = $self->get_total_length();
  if ($total_length) {
    $stats_hash{total_length} = $total_length;
  }

  my $all_slices = $self->get_all_slices($species);

  my @all_sorted_slices =
   sort( { $a->coord_system()->rank() <=> $b->coord_system()->rank()
           || $b->seq_region_length() <=> $a->seq_region_length() } @$all_slices) ;
  while (my $slice = shift @all_sorted_slices) {
    if ($slice->is_reference) {
      $stats_hash{'transcript'} += $ta->count_all_by_Slice($slice);
      $stats_attrib{'transcript'} = 'transcript_cnt';
      foreach my $ref_code (keys %attrib_codes) {
        $count = $self->get_feature_count($slice, $ref_code, $attrib_codes{$ref_code});
        if ($count > 0) {
          $self->store_attrib($slice, $count, $ref_code);
        }
        $stats_hash{$ref_code} += $count;
      }
      $count = $self->get_attrib($slice, 'noncoding_cnt_%');
      if ($count > 0) {
        $self->store_attrib($slice, $count, 'noncoding_cnt');
      }
      $stats_hash{'noncoding_cnt'} += $count;
      $stats_attrib{'noncoding_cnt'} = 'noncoding_cnt';
    } elsif ($slice->seq_region_name =~ /LRG/) {
      next;
    } else {
      my $sa = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice');
      my $alt_slices = $sa->fetch_by_region_unique($slice->coord_system->name(), $slice->seq_region_name());
      foreach my $alt_slice (@$alt_slices) {
        $stats_hash{'alt_transcript'} += $ta->count_all_by_Slice($alt_slice);
        $stats_attrib{'alt_transcript'} = 'transcript_acnt';
        foreach my $alt_code (keys %alt_attrib_codes) {
          $alt_count = $self->get_feature_count($alt_slice, $alt_code, $alt_attrib_codes{$alt_code});
          if ($alt_count > 0) {
            $self->store_attrib($slice, $alt_count, $alt_code);
          }
          $stats_hash{$alt_code} += $alt_count;
        }
        $alt_count = $self->get_attrib($slice, 'noncoding_acnt_%');
        if ($alt_count > 0) {
          $self->store_attrib($slice, $alt_count, 'noncoding_acnt');
        }
        $stats_hash{'noncoding_acnt'} += $alt_count;
        $stats_attrib{'noncoding_acnt'} = 'noncoding_acnt';
      }
    }
    if ($sum >= $total) {
      last;
    }
  }
  $self->store_statistics($species, \%stats_hash, \%stats_attrib); 
}

sub get_slices {
  my ($self, $species) = @_;
  my $slices = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice')->fetch_all('toplevel');
  return $slices;
}

sub get_all_slices {
  my ($self, $species) = @_;
  my $slices = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice')->fetch_all('toplevel', undef, 1);
  return $slices;
}

sub delete_old_attrib {
  my ($self, $dba, %attrib_codes) = @_;
  my $helper = $dba->dbc()->sql_helper();
  my $sql = q{
    DELETE sa
    FROM seq_region_attrib sa, attrib_type at, seq_region s, coord_system cs
    WHERE s.seq_region_id = sa.seq_region_id
    AND cs.coord_system_id = s.coord_system_id
    AND at.attrib_type_id = sa.attrib_type_id
    AND cs.species_id = ?
    AND at.code = ? };
  foreach my $code (keys %attrib_codes) {
    $helper->execute_update(-SQL => $sql, -PARAMS => [$dba->species_id(), $code]);
  }
}

sub delete_old_stats {
  my ($self, $dba, %attrib_codes) = @_;
  my $helper = $dba->dbc()->sql_helper();
  my $sql = q{
    DELETE g
    FROM genome_statistics g
    WHERE g.species_id = ?
    AND statistic = ? };
  foreach my $code (keys %attrib_codes) {
    $helper->execute_update(-SQL => $sql, -PARAMS => [$dba->species_id(), $code]);
  }
}


sub store_attrib {
  my ($self, $slice, $count, $code) = @_;
  my $aa          = Bio::EnsEMBL::Registry->get_adaptor($self->param('species'), 'core', 'Attribute');
  my $prod_dba    = $self->get_production_DBAdaptor();
  my $prod_helper = $prod_dba->dbc()->sql_helper();
  my $sql = q{
    SELECT name, description
    FROM attrib_type
    WHERE code = ? };
  my ($name, $description) = @{$prod_helper->execute(-SQL => $sql, -PARAMS => [$code])->[0]};
  my $attrib = Bio::EnsEMBL::Attribute->new(
    -NAME        => $name,
    -CODE        => $code,
    -VALUE       => $count,
    -DESCRIPTION => $description
  );
  my @attribs = ($attrib);
  $aa->remove_from_Slice($slice, $code);
  $aa->store_on_Slice($slice, \@attribs);
}

sub get_attrib {
  my ($self, $slice, $code) = @_;
  my $aa          = Bio::EnsEMBL::Registry->get_adaptor($self->param('species'), 'core', 'Attribute');
  my $attributes = $aa->fetch_all_by_Slice($slice, $code);
  my $count = 0;
  foreach my $attribute (@$attributes) {
    $count += $attribute->value();
  }
  return $count;
}

sub get_biotype_group {
  my ($self, $biotype) = @_;
  my $prod_dba = $self->get_production_DBAdaptor();
  my $helper = $prod_dba->dbc()->sql_helper();
  my $sql = q{
     SELECT name
     FROM biotype
     WHERE object_type = 'gene'
     AND is_current = 1
     AND biotype_group = ?
     AND db_type like '%core%' };
  my @biotypes = @{ $helper->execute_simple(-SQL => $sql, -PARAMS => [$biotype]) };
  return \@biotypes;
}

sub store_statistics {
  my ($self, $species, $stats_hash, $stats_attrib) = @_;
  my $stats;
  my $genome_container = Bio::EnsEMBL::Registry->get_adaptor($self->param('species'), 'core', 'GenomeContainer');
  my $attrib;
  foreach my $stats (keys %$stats_hash) {
    if ($stats_attrib->{$stats}) {
      $attrib = $stats_attrib->{$stats};
    } else {
      $attrib = $stats;
    }
    $genome_container->store($stats, $stats_hash->{$stats}, $attrib);
  }
}

sub get_ref_length {}
sub get_total_length {}



1;

