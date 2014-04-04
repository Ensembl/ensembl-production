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

package Bio::EnsEMBL::EGPipeline::Common::Aligner::BwaAligner;
use Log::Log4perl qw(:easy);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use base qw(Bio::EnsEMBL::EGPipeline::Common::Aligner);

# Index the reference fasta file with something like: bwa index -a bwtsw database.fasta
my $index = "%s index -a bwtsw %s";
# samtools faidx v61_all.con
my $faindex = "%s faidx %s";
# bwa aln database.fasta short_read_1.fastq > aln_sa1.sai
# bwa aln database.fasta short_read_2.fastq > aln_sa2.sai
my $aln = "%s aln %s %s > %s";
# bwa sampe database.fasta aln_sa1.sai aln_sa2.sai read1.fq read2.fq > aln.sam
my $sampe = "%s sampe %s %s %s %s %s > %s";
#bwa samse database.fasta aln_sa.sai short_read.fastq > aln.sam
my $samse = "%s samse %s %s %s > %s";

my $logger = get_logger();

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  ($self->{bwa}) = rearrange(['BWA'], @args);
  $self->{bwa} ||= 'bwa';
  return $self;
}

sub index_file {
  my ($self, $file) = @_;
  my $comm = sprintf($index, $self->{bwa}, $file);
  $logger->debug("Executing $comm");
  system($comm) == 0 || throw "Cannot execute $comm";
  my $comm = sprintf($faindex, $self->{samtools}, $file);
  $logger->debug("Executing $comm");
  system($comm) == 0 || throw "Cannot execute $comm";
  return;
}

sub _align_file {
  my ($self, $ref, $file) = @_;
  my $output = $file;
  $output =~ s/.fastq/.sai/;
  my $comm = sprintf($aln, $self->{bwa}, $ref, $file, $output);
  $logger->debug("Executing $comm");
  system($comm) == 0 || throw "Cannot execute $comm";
  return $output;
}

sub align {
  my ($self, $ref, $sam, $file1, $file2) = @_;
  if (defined $file2) {
	# paired end
	$logger->info("Aligning single read file $file1");
	my $aligned_1 = $self->_align_file($ref, $file1);
	$logger->info("Alignment stored in $aligned_1");
	$logger->info("Aligning single read file $file2");
	my $aligned_2 = $self->_align_file($ref, $file2);
	$logger->info("Alignment stored in $aligned_2");
	# create sam
	$logger->info("Creating SAM file $sam");
	$self->_pairedend_to_sam($ref, $aligned_1, $file1, $aligned_2, $file2, $sam);
	unlink $aligned_1 if ($self->{cleanup});
	unlink $aligned_2 if ($self->{cleanup});
  } else {
	          # single
	          # align concatenate file
	$logger->info("Aligning single read file $file1");
	my $aligned = $self->_align_file($ref, $file1);
	$logger->info("Alignment stored in $aligned");
	# create sam
	$logger->info("Creating SAM file $sam");
	$self->_single_to_sam($ref, $aligned, $file1, $sam);
	unlink $aligned if ($self->{cleanup});
  }
  return $sam;
} ## end sub align

sub _pairedend_to_sam {
  my ($self, $ref, $file1_aln, $file1_fastq, $file2_aln, $file2_fastq, $output) = @_;
  my $comm = sprintf($sampe, $self->{bwa}, $ref, $file1_aln, $file2_aln, $file1_fastq, $file2_fastq, $output);
  $logger->debug("Executing $comm");
  system($comm) == 0 || throw "Cannot execute $comm";
  return $output;
}

sub _single_to_sam {
  my ($self, $ref, $file1_aln, $file1_fastq, $output) = @_;
  my $comm = sprintf($samse, $self->{bwa}, $ref, $file1_aln, $file1_fastq, $output);
  $logger->debug("Executing $comm");
  system($comm) == 0 || throw "Cannot execute $comm";
  return $output;
}

1;
