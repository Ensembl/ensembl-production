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


=pod

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 
=cut

package Bio::EnsEMBL::EGPipeline::Common::Aligner;

use Log::Log4perl qw(:easy);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

# samtools view -bS test.sam > test.bam
my $sam2bam = "%s view -bS %s > %s";
# samtools merge out.bam in1.bam in2.bam in3.bam
my $mergebam = "%s merge -f %s %s";
my $sortbam  = "%s sort %s %s";
my $indexbam = "%s index %s %s";
my $statbam  = "%s flagstat %s";
#samtools mpileup -ugf ${REFERENCE} bwa_sorted.bam | bcftools view -bvcg > bwa_sampe.raw.bcf
my $pileup = "%s mpileup -uf %s %s | %s view -bvcg - > %s";
#bcftools view var.raw.bcf | vcfutils.pl varFilter -D100 > var.flt.vcf
my $bcf2vcf = "%s view %s | %s varFilter -D100 > %s";

my $logger = get_logger();

sub new {
	my ( $class, @args ) = @_;
	my $self = bless( {}, ref($class) || $class );
	( $self->{bwa}, $self->{samtools}, $self->{bcftools}, $self->{vcfutils}, $self->{cleanup} ) =
	  rearrange( [ 'BWA', 'SAMTOOLS', 'BCFTOOLS', 'VCFUTILS', 'CLEANUP' ], @args );
	$self->{bwa}      ||= 'bwa';
	$self->{samtools} ||= 'samtools';
	$self->{bcftools} ||= 'bcftools';
	$self->{vcfutils} ||= 'vcfutils.pl';
	return $self;
}

sub index_file {
	throw "index_file unimplemented";
}

sub align_file {
	throw "align_file unimplemented";
}

sub pairedend_to_sam {
	throw "pairedend_to_sam unimplemented";
}

sub single_to_sam {
	throw "single_to_sam unimplemented";
}

sub sam_to_bam {
	my ( $self, $sam, $bam ) = @_;
	if ( !defined $bam ) {
		$bam = $sam;
		$bam =~ s/.sam/.bam/;
	}
	my $comm = sprintf( $sam2bam, $self->{samtools}, $sam, $bam );
	$logger->debug("Executing $comm");
	system($comm) == 0 || throw "Cannot execute $comm";
	return $bam;
}

sub merge_bam {
	my ( $self, $in, $out ) = @_;
	my $comm = sprintf( $mergebam, $self->{samtools}, $out, join( ' ', @$in ) );
	$logger->debug("Executing $comm");
	system($comm) == 0 || throw "Cannot execute $comm";
	return $out;
}

sub sort_bam {
	my ( $self, $in, $out ) = @_;
	if ( !defined $out ) {
		$out = $in;
		$out =~ s/.bam/.sorted/;
	}
	my $comm = sprintf( $sortbam, $self->{samtools}, $in, $out );
	$logger->debug("Executing $comm");
	system($comm) == 0 || throw "Cannot execute $comm";
	return $out.'.bam';
}

sub index_bam {
	my ( $self, $in, $use_csi ) = @_;

	if (!defined $use_csi || ! $use_csi) {
	    # Use BAI index format
	    $index_argument = '-b';
	}
	else {
	    # Use CSI index format
	    $index_argument = '-c';
	}
	
	my $comm = sprintf( $indexbam, $self->{samtools}, $index_argument, $in );
	$logger->info("Executing $comm");
	system($comm) == 0 || throw "Cannot execute $comm";
	return;
}

sub get_bam_stats {
	my ( $self, $in ) = @_;
	my $comm = sprintf( $statbam, $self->{samtools}, $in );
	$logger->debug("Executing $comm");
	system($comm) == 0 || throw "Cannot execute $comm";
	return;
}

sub generate_vcf {
	my ( $self, $bam, $ref ) = @_;
	my $bcf = $self->pileup_bam( $bam, $ref );
	my $vcf = $self->bcf2vcf($bcf);
	return $vcf;
}

sub pileup_bam {
	my ( $self, $bam, $ref, $bcf ) = @_;
	if ( !defined $bcf ) {
		$bcf = $bam;
		$bcf =~ s/.bam/.bcf/;
	}
	my $comm =
	  sprintf( $pileup, $self->{samtools}, $ref, $bam, $self->{bcftools},
			   $bcf );
	$logger->debug("Executing $comm");
	system($comm) == 0 || throw "Cannot execute $comm";
	return $bcf;
}

sub bcf2vcf {
	my ( $self, $bcf, $vcf ) = @_;
	if ( !defined $vcf ) {
	    $vcf = $bcf;
		$vcf =~ s/.bcf/.vcf/;
	}
	my $comm = sprintf( $bcf2vcf, $self->{bcftools}, $bcf, $self->{vcfutils}, $vcf );
	$logger->debug("Executing $comm");
	system($comm) == 0 || throw "Cannot execute $comm";
	return $vcf;
}


1;
