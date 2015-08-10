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

package Bio::EnsEMBL::EGPipeline::Common::SAMParser;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $args  = ref $_[0] eq 'HASH' ? shift : { @_ };
  
  my $self  = {};
  bless($self, $class);
  
  my $sam_file = $args->{'sam_file'};
  $self->{'sam_file'} = $sam_file;
  
  return $self;
}

sub get_ref_alignment_length {
  my ($self, $cigar_line) = @_;
  
  my $length = 0;
  $cigar_line =~ s/(\d+)[MX=DN]/$length+=$1/eg;
  
  return $length;
}

sub get_ref_cumulative_exon_length { 
  my ($self, $cigar_line) = @_;
  
  my $length = 0;
  $cigar_line =~ s/(\d+)[MX=D]/$length+=$1/eg;
  
  return $length;
}

sub get_query_cumulative_exon_length {
  my ($self, $cigar_line) = @_;
  
  my $length = 0;
  $cigar_line =~ s/(\d+)[MX=I]/$length+=$1/eg;
  
  return $length;
}

sub get_perc_id {
  my ($self, $cigar_line, $seq) = @_;
  
  my $length = $self->get_ref_cumulative_exon_length($cigar_line);
  
  my $identical_matches = 0;
  $seq =~ s/([=])/$identical_matches++/eg;
  
  my $perc_id;
  if ($length > 0) {
    $perc_id = sprintf "%.2f", ($identical_matches * 100 / $length);
  }
  
  return $perc_id;
}

sub parse_sam {
  my ($self, $sam_file) = @_;
  
  $sam_file = $self->{'sam_file'} unless defined $sam_file;
  
  my %alignments;
  
  open (my $fh, '<', $sam_file) or die "Failed to open file '$sam_file'";
  while (my $line = <$fh>) {
    chomp $line;
    next if ($line =~ /^@/);
    
    my @columns = split(/\t/, $line);
    
    if (scalar(@columns) >= 11) {
      my $read_name = $columns[0];
      my $flag = $columns[1];
      my $seq_region_name = $columns[2];
      my $seq_start = $columns[3];
      my $cigar_line = $columns[5];
      my $seq = $columns[9];
      
      # Skip unmapped sequences
      next if ($flag & (1 << 2));
      
      # Skip supplementary alignments
      next if ($flag & (1 << 11));
      
	    if (! defined $seq_start) {
        $self->throw("Failed to parse the SAM line, $line!\n");
	    }
	    
      # Retrieve (optional) score value if it exists
      my $score;
      for (my $i=11; $i < scalar(@columns); $i++) {
        if ($columns[$i] =~ /^AS:i:(.+)$/) {
          $score = $1;
        }
      }
      
      # If the sequence is reverse-complemented, a bitwise flag will be set.
      my $seq_strand = 1;
      if ($flag & (1 << 4)) {
        $seq_strand = -1;
      }
      
      # Detect hit start and stop, then remove from the cigar line
      # so that we don't double-count the values.
      my $hit_start = 1;
      my ($clip_h_start, $clip_s_start) = $cigar_line =~ /^(\d+)H(\d+)S/;
      unless (defined $clip_h_start && defined $clip_s_start) {
        ($clip_h_start) = $cigar_line =~ /^(\d+)H/;
        ($clip_s_start) = $cigar_line =~ /^(\d+)S/;
      }
      $hit_start += $clip_h_start || 0;
      $hit_start += $clip_s_start || 0;
      
      my ($clip_h_end, $clip_s_end) = $cigar_line =~ /(\d+)S(\d+)H$/;
      unless (defined $clip_h_end && defined $clip_s_end) {
        ($clip_h_end) = $cigar_line =~ /(\d+)H$/;
        ($clip_s_end) = $cigar_line =~ /(\d+)S$/;
      }
      
      my $hit_end = length($seq) + ($clip_h_start || 0) + ($clip_h_end || 0);
      $hit_end -= $clip_h_end || 0;
      $hit_end -= $clip_s_end || 0;
      
      $cigar_line =~ s/\d+[SH]//g;
      
      # Calculate hit coverage
      my $hcoverage = sprintf "%.2f", (($hit_end - $hit_start + 1) * 100 / length($seq));
      
      # Calculate alignment length and thus the end on the reference.
	    my $alignment_length = $self->get_ref_alignment_length($cigar_line);
	    my $seq_end = $seq_start + $alignment_length - 1;
	    
      # Calculate percentage identity
      my $perc_id = undef;
	    if ($seq =~ /=/) {
        $perc_id = $self->get_perc_id($cigar_line, $seq);
	    }
	    
	    my $alignment = {
        'seq_start'  => $seq_start,
        'seq_end'    => $seq_end,
        'seq_strand' => $seq_strand,
        'hit_start'  => $hit_start,
        'hit_end'    => $hit_end,
        'hit_strand' => 1,
        'read_name'  => $read_name,
        'cigar_line' => $cigar_line,
        'score'      => $score,
        'perc_id'    => $perc_id,
        'hcoverage'  => $hcoverage,
	    };
	    push @{$alignments{$seq_region_name}}, $alignment;
      
    } else {
      $self->throw("SAM line, $line\ndoesn't match the expected pattern structure!\n");
    }
  }
  
  close($fh);
  
  return \%alignments;
}

1;
