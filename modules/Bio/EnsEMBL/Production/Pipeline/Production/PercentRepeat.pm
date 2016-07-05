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

package Bio::EnsEMBL::Production::Pipeline::Production::PercentRepeat;

use base qw/Bio::EnsEMBL::Production::Pipeline::Production::DensityGenerator/;
use Bio::EnsEMBL::Mapper::RangeRegistry;



use strict;
use warnings;


sub get_density {
  my ($self, $block) = @_;
  if ($block->length > 5000000) { return 0; }
  my $repeat_count = 0;
  my @repeats = @{ $block->get_all_RepeatFeatures() };
  @repeats = map { $_->[1] } sort { $a->[0] <=> $b->[0] } map { [$_->start, $_] } @repeats;
  my $curblock = undef;
  my @repeat_blocks;
  foreach my $repeat (@repeats) {
    if (defined($curblock) && $curblock->end >= $repeat->start) {
      if ($repeat->end > $block->length) {
        $curblock->end($block->length);
      } elsif ($repeat->end > $curblock->end) {
        $curblock->end($repeat->end);
      }
    } else {
      my $start = $repeat->start;
      my $end = $repeat->end;
      if ($repeat->end > $block->length) {
        $end = $block->length;
      }
      if ($repeat->start < 1) {
        $start = 1;
      }
      $curblock = Bio::EnsEMBL::Feature->new(-START => $start, -END => $end);
      push @repeat_blocks, $curblock;
    }
  }
  foreach my $repeat_block(@repeat_blocks) {
    $repeat_count += $repeat_block->length();
  }
  return 100*$repeat_count/$block->length();
}

sub get_total {
  my ($self) = @_;
  my $species = $self->param('species');
  my $slices = scalar(@{  Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice')->fetch_all('toplevel') });
  return $slices*$self->param('bin_count')*100;
}

return 1;

