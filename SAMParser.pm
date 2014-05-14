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
use FileHandle;
use POSIX;

use Bio::EnsEMBL::Utils::Exception qw/throw/;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $args  = ref $_[0] eq 'HASH' ? shift : { @_ };
  
  my $self  = {};
  bless($self, $class);
  
  my $sam_file = $args->{'sam_file'};
  
  $self->{'sam_file'} = $sam_file;

  # calmd_file allows us to define the perc_id
  
  # my $calmd_file = $args->{'calmd_file'};
  
  return $self;

} ## end sub new

sub get_ref_alignment_length {
    my ($cigar_line) = @_;
    
    my $ref_alignment_length = 0;
    $cigar_line =~ s/(\d+)[MX=DN]/$ref_alignment_length+=$1/eg;
    
    return $ref_alignment_length;
}

sub get_ref_cumulative_exon_length { 
    my ($cigar_line) = @_;
    
    my $ref_cumulative_exon_length = 0;
    $cigar_line =~ s/(\d+)[MX=D]/$ref_cumulative_exon_length+=$1/eg;
    
    return $ref_cumulative_exon_length;
}

sub get_query_cumulative_exon_length {
    my ($cigar_line) = @_;
    
    my $query_cumulative_exon_length = 0;
    $cigar_line =~ s/(\d+)[MX=I]/$query_cumulative_exon_length+=$1/eg;
    
    return $query_cumulative_exon_length;
}

sub get_perc_id {
    my ($query_sequence_calmd, $ref_cumulative_exon_length) = @_;
    
    # Get the number of matches in the alignment
    
    my $nb_matches = 0;
    $query_sequence_calmd =~ s/([=])/$nb_matches++/eg;
    
    # Don't take into account introns to determine the perc_id
    my $perc_id = POSIX::floor ($nb_matches * 100 / $ref_cumulative_exon_length);
    
    return $perc_id;
}


sub parse_sam {
    my $self = shift;
    my $calmd_file = $self->{'sam_file'};
    
    # $hit_start and $hit_end, and $hcoverage ?

    my $alignments_per_seqs_href = {};

    warn("Parsing sam calmd file, $calmd_file\n");

    my $sam_fh = new FileHandle;
    $sam_fh->open("<$calmd_file") or die "can't open sam calmd output file, $calmd_file!\n";
    while (<$sam_fh>) {
	my $line = $_;
	chomp $line;
	if ($line =~ /^@/) {
	    next;
	}
	if ($line =~ /^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t[^\t]+\t([^\t]+)\t[^\t]+\t[^\t]+\t[^\t]+\t([^\t]+)\t[^\t]+\t[^\t]+\t[^\t]+\t([^\t]+)\t.+/) {
	    
	    my $read_name = $1;
	    my $flag      = $2;
	    
	    my $seq_strand = 1;
	    my $hit_strand = ($flag & 16) ? -1 : 1;
	    
	    my $seq_region_name = $3;
	    my $seq_start  = $4;
	    
	    my $cigar_line = $5;
	    # where matched bases are replaced by '=' by samtools calmd
	    my $query_sequence_calmd = $6;
	    
	    my $score = $7;
	    $score =~ s/AS:i://;
	    
	    if (! defined $seq_start) {
		throw "Failed to parse the SAM line, $line!\n";
	    }
	    
	    #
            # Hit(query) stuff
            #

	    # Set the hit coordinates
	    
	    my $hit_start = 1;
	    my $clip_start_length = 0;
	    
	    # Parse the first clip block
	    # hit_start is based on the first 'S|H' value in the cigar string
	    
	    if ($cigar_line =~ /^(\d+)[SH]/) {
		$clip_start_length = $1;
	    }
	    
	    # print STDERR "clip_start_length, $clip_start_length\n";
	    
	    $hit_start += $clip_start_length;
	    
	    # Parse the last clip block
	    
	    $cigar_line =~ /^.+\D+(\d+)[SH]+$/;
	    
	    my $clip_end_length = $1 || 0;
	    
	    # From that point we no longer need clipping info in the cigar line, 
	    # and it is not expected by the Ensembl API, so let's remove them, if any
	    
	    $cigar_line =~ s/\d+[S|H]//g;
	    
	    # Get the hit_end (query/read end) and hcoverage
	    
	    my $query_cumulative_exon_length = get_query_cumulative_exon_length($cigar_line);
	    my $hit_length = $clip_start_length + $query_cumulative_exon_length + $clip_end_length;

	    my $hit_end = $clip_start_length + $query_cumulative_exon_length;	    
	    my $hcoverage = int ($query_cumulative_exon_length * 100 / $hit_length);
	    
	    #
	    # Reference stuff
	    #
	    
	    my $ref_alignment_length = get_ref_alignment_length($cigar_line);
	    
	    # print STDERR "alignment length on the reference (includes exons and introns), $ref_alignment_length\n";
	    
	    my $ref_cumulative_exon_length = get_ref_cumulative_exon_length($cigar_line);

	    # Reference seq end coordinate
	    
	    my $seq_end = $seq_start + $ref_alignment_length - 1;
	    
	    my $perc_id = undef;
	    if ($query_sequence_calmd =~ /=/) {
		# We can only compute the perc_id if the sam file has been processed with calmd tool before being supplied to the SAM parser
		$perc_id = get_perc_id ($query_sequence_calmd, $ref_cumulative_exon_length);
	    }
	    
	    # print STDERR "perc_id, $perc_id\n";
	    	
	    # Get this all into the hash

	    my $alignment_href = {
		'read_name'  => $read_name,
		'seq_start'  => $seq_start,
		'seq_end'    => $seq_end,
		'seq_strand' => $seq_strand,
		'cigar_line' => $cigar_line,
		'perc_id'    => $perc_id,
		'score'      => $score,
		'hit_start'  => $hit_start,
		'hit_end'    => $hit_end,
		'hit_strand' => $hit_strand,
		'hcoverage'  => $hcoverage,
	    };

	    my $alignments_aref = [];
	    if (defined $alignments_per_seqs_href->{$seq_region_name}) {
		$alignments_aref = $alignments_per_seqs_href->{$seq_region_name};
	    }
	    else {
		$alignments_per_seqs_href->{$seq_region_name} = $alignments_aref;
	    }
	    
	    push (@$alignments_aref, $alignment_href);

	}
	else {
	    throw("SAM line, $line\ndoesn't match the expected pattern structure!\n");
	}
    }

    $sam_fh->close();

    warn("Parsing done\n");

    return $alignments_per_seqs_href;
}

1;
