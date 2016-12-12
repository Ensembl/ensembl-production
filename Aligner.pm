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
  
	(
    $self->{samtools_dir}, $self->{samtools},
    $self->{bcftools_dir}, $self->{bcftools}, $self->{vcfutils},
    $self->{aligner_dir},
    $self->{threads}, $self->{memory}, $self->{run_mode}, $self->{do_not_run}, $self->{cleanup},
  ) =
  rearrange(
    [
      'SAMTOOLS_DIR', 'SAMTOOLS',
      'BCFTOOLS_DIR', 'BCFTOOLS', 'VCFUTILS',
      'ALIGNER_DIR',
      'THREADS', 'MEMORY', 'RUN_MODE', 'DO_NOT_RUN', 'CLEANUP',
    ], @args
  );
  
	$self->{samtools}   ||= 'samtools';
	$self->{bcftools}   ||= 'bcftools';
	$self->{vcfutils}   ||= 'vcfutils.pl';
  $self->{threads}    ||= 1;
  $self->{run_mode}   ||= 'default';
  $self->{do_not_run} ||= 0;
  $self->{cleanup}    ||= 1;
  
  if ($self->{samtools_dir}) {
    $self->{samtools} = catdir($self->{samtools_dir}, $self->{samtools});
  }
  if ($self->{bcftools_dir}) {
    $self->{bcftools} = catdir($self->{bcftools_dir}, $self->{bcftools});
    $self->{vcfutils} = catdir($self->{bcftools_dir}, $self->{vcfutils});
  }
  
	return $self;
}

sub version {
  my ($self) = @_;
  
  my $cmd = $self->{align_program} . ' --version';
  my ($success, $error, $buffer) = run(command => $cmd);
  my $buffer_str = join "", @$buffer;
  
  if ($success) {
    $buffer_str =~ /version\s+(\S+)/m;
    return $1;
  } else {
    throw("Command '$cmd' failed, $error: $buffer_str");
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

sub run_cmd {
  my ($self, $cmd, $cmd_type) = @_;
  
  if (! $self->{do_not_run}) {
    system($cmd) == 0 || throw "Cannot execute $cmd: $@";
  }
  
  if ($cmd_type eq 'align') {
    $self->align_cmds($cmd);
  } elsif ($cmd_type eq 'index') {
    $self->index_cmds($cmd);
  }
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
		($bam = $sam) =~ s/\.sam$/\.bam/;
    if ($bam eq $sam) {
      $bam = "$sam.bam";
    }
	}
  # First part: conversion from SAM to BAM
  my $convert_cmd = "$self->{samtools} view -bS $sam";
  
  # Second part: sorting the BAM
  my $threads = $self->{threads};
  # Calculate the correct memory per thread
  my $mem = $self->{memory} / $threads;
  # Samtools sort is too greedy: we give it less
  $mem *= 0.8;
  my $mem_limit = $mem . 'M';
  # Final sort command
  my $sort_cmd = "$self->{samtools} sort -@ $threads -m $mem_limit -o $bam -O 'bam' -T $bam.sorting -";
  
  # Pipe both commands
  my $cmd = "$convert_cmd | $sort_cmd";
  
  $self->run_cmd($cmd);
  $self->align_cmds($cmd);
  
	return $bam;
}

sub merge_bam {
	my ($self, $bams, $out) = @_;
  
  my $bam = join( ' ', @$bams );
  my $threads = $self->{threads};
  my $cmd = "$self->{samtools} merge -@ $threads -f $out $bam";
  $self->run_cmd($cmd);
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
  my $cmd = "$self->{samtools} sort $bam $out_prefix";
  $self->run_cmd($cmd);
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
  $self->run_cmd($cmd);
  $self->align_cmds($cmd);
}

sub get_bam_stats {
	my ($self, $bam) = @_;
  
  my $cmd = "$self->{samtools} flagstat $bam";
  my $stats = `$cmd 2>&1`;
  
	return $stats;
}

sub generate_vcf {
	my ($self, $ref, $bam, $vcf) = @_;
  
	if (! defined $vcf) {
		($vcf = $bam) =~ s/\.bam/\.vcf/;
    if ($vcf eq $bam) {
      $vcf = "$bam.vcf";
    }
	}
  my $cmd = "$self->{samtools} mpileup -uf $ref $bam";
  $cmd   .= " | ";
  $cmd   .= "$self->{bcftools} call -mv -o $vcf";
  $self->run_cmd($cmd);
  $self->align_cmds($cmd);
  
	return $vcf;
}

sub dummy {
  my $self = shift;
  my ($dummy) = @_;
  
  if (defined $dummy) {
    $self->{do_not_run} = $dummy;
  }
  
  return $self->{do_not_run};
}

1;
