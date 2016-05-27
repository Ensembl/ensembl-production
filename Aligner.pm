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

package Bio::EnsEMBL::EGPipeline::Common::Aligner;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

use File::Spec::Functions qw(catdir);
use IPC::Cmd qw(run);

sub new {
	my ( $class, @args ) = @_;
	my $self = bless( {}, ref($class) || $class );
  my ($samtools_dir, $bcftools_dir);
  
	( $samtools_dir, $self->{samtools}, $bcftools_dir, $self->{bcftools}, $self->{cleanup}, $self->{threads}, $self->{merge_sort_memory} ) =
	  rearrange( [ 'SAMTOOLS_DIR', 'SAMTOOLS', 'BCFTOOLS_DIR', 'BCFTOOLS', 'CLEANUP', 'THREADS', 'MERGE_SORT_MEMORY' ], @args );
  
	$self->{samtools} ||= 'samtools';
	$self->{bcftools} ||= 'bcftools';
	$self->{vcfutils} ||= 'vcfutils.pl';
  $self->{cleanup}  ||= 1;
  $self->{merge_sort_memory} ||= '16000';
  $self->{merge_sort_memory} .= 'M';
  $self->{threads} ||= 4;
  
  $self->{samtools} = catdir($samtools_dir, $self->{samtools}) if defined $samtools_dir;
	$self->{bcftools} = catdir($bcftools_dir, $self->{bcftools}) if defined $bcftools_dir;
	$self->{vcfutils} = catdir($bcftools_dir, $self->{vcfutils}) if defined $bcftools_dir;
  
	return $self;
}

sub version {
  my ($self) = @_;
  
  my $cmd = $self->{bowtie2} . ' --version';
  my ($success, $error, $buffer) = run(command => $cmd);
  my $buffer_str = join "", @$buffer;
  
  if ($success) {
    $buffer_str =~ /version\s+(\S+)/m;
    return $1;
  } else {
    $self->throw("Command '$cmd' failed, $error: $buffer_str");
  }
}

sub index_file {
	throw "index_file unimplemented";
}

sub index_exists {
	throw "index_exists unimplemented";
}

sub align {
	throw "align unimplemented";
}

sub index_cmds {
	my ($self, $cmd) = @_;
  
  if (defined $cmd) {
    push @{$self->{index_cmds}}, $cmd;
  }
  return $self->{index_cmds};
}

sub align_cmds {
	my ($self, $cmd) = @_;
  
  if (defined $cmd) {
    push @{$self->{align_cmds}}, $cmd;
  }
  return $self->{align_cmds};
}

sub sam_to_bam {
	my ($self, $sam, $bam) = @_;
  
	if (! defined $bam) {
		($bam = $sam) =~ s/\.sam/\.bam/;
    if ($bam eq $sam) {
      $bam = "$sam.bam";
    }
	}
  my $cmd = "$self->{samtools} view -bS $sam > $bam";
  system($cmd) == 0 || throw "Cannot execute $cmd";
  $self->align_cmds($cmd);
  
	return $bam;
}

sub merge_bam {
	my ($self, $bams, $out) = @_;
  
  my $bam = join( ' ', @$bams );
  my $cmd = "$self->{samtools} merge -f $out $bam";
  system($cmd) == 0 || throw "Cannot execute $cmd";
  $self->align_cmds($cmd);
  
	return $out;
}

sub sort_bam {
	my ($self, $bam, $out_prefix) = @_;
  
	if (! defined $out_prefix) {
		($out_prefix = $bam) =~ s/\.bam/\.sorted/;
    if ($out_prefix eq $bam) {
      $out_prefix = "$bam.sorted";
    }
	}
  my $threads = $self->{threads};
  my $memory  = $self->{merge_sort_memory};
  my $cmd = "$self->{samtools} sort -\@ $threads -m $memory $bam $out_prefix";
  system($cmd) == 0 || throw "Cannot execute $cmd";
  $self->align_cmds($cmd);
  
	return "$out_prefix.bam";
}

sub index_bam {
	my ($self, $bam, $use_csi) = @_;
  
  my $index_options;
  if (defined $use_csi && $use_csi) {
    $index_options = '-c';
	} else {
    $index_options = '-b';
	}
	
  my $cmd = "$self->{samtools} index $index_options $bam";
  system($cmd) == 0 || throw "Cannot execute $cmd";
  $self->align_cmds($cmd);
}

sub get_bam_stats {
	my ($self, $bam) = @_;
  
  my $cmd = "$self->{samtools} flagstat $bam";
  my $stats = `$cmd 2>&1`;
  
	return $stats;
}

sub generate_vcf {
	my ($self, $bam, $ref) = @_;
  
	my $bcf = $self->pileup_bam($bam, $ref);
	my $vcf = $self->bcf2vcf($bcf);
  
	return $vcf;
}

sub pileup_bam {
	my ($self, $bam, $ref, $bcf) = @_;
  
	if (! defined $bcf) {
		($bcf = $bam) =~ s/\.bam/\.bcf/;
    if ($bcf eq $bam) {
      $bcf = "$bam.bcf";
    }
	}
  # Is the '-' required?
  my $cmd = "$self->{samtools} mpileup -uf $ref $bam | $self->{bcftools} view -bvcg - > $bcf";
  system($cmd) == 0 || throw "Cannot execute $cmd";
  $self->align_cmds($cmd);
  
	return $bcf;
}

sub bcf2vcf {
	my ($self, $bcf, $vcf) = @_;
  
	if (! defined $vcf) {
		($vcf = $bcf) =~ s/\.bcf/\.vcf/;
    if ($vcf eq $bcf) {
      $vcf = "$bcf.vcf";
    }
	}
  
  my $cmd = "$self->{bcftools} view  $bcf | $self->{vcfutils} varFilter -D100 > $vcf";
  system($cmd) == 0 || throw "Cannot execute $cmd";
  $self->align_cmds($cmd);
  
	return $vcf;
}

1;
