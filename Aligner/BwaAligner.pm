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

package Bio::EnsEMBL::EGPipeline::Common::Aligner::BwaAligner;

use strict;
use warnings;
use base qw(Bio::EnsEMBL::EGPipeline::Common::Aligner);

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

use File::Spec::Functions qw(catdir);
use IPC::Cmd qw(run);

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  
  $self->{index_program} = 'bwa';
  $self->{align_program} = 'bwa';
  
  if ($self->{aligner_dir}) {
    $self->{index_program} = catdir($self->{aligner_dir}, $self->{index_program});
    $self->{align_program} = catdir($self->{aligner_dir}, $self->{align_program});
  }
  
  return $self;
}

sub version {
  my ($self) = @_;
  
  my $cmd = $self->{align_program};
  my (undef, $error, $buffer) = run(command => $cmd);
  my $buffer_str = join "", @$buffer;
  
  if ($buffer_str =~ /Version:\s+(\S+)/m) {
    return $1;
  } else {
    $self->throw("Command '$cmd' failed, $error: $buffer_str");
  }
}

sub index_file {
  my ($self, $file) = @_;
  
  my $index_cmd  = "$self->{index_program} index ";
  $index_cmd    .= " -a bwtsw ";
  $index_cmd    .= " $file ";
  
  $self->run_cmd($index_cmd, 'index');
  
  my $samtools_index_cmd = "$self->{samtools} faidx ";
  $samtools_index_cmd   .= " $file ";
  
  $self->run_cmd($samtools_index_cmd, 'index');
}

sub index_exists {
  my ($self, $file) = @_;
  
  my $exists = -e "$file.sa" ? 1 : 0;
  
  return $exists;
}

sub align {
  my ($self, $ref, $sam, $file1, $file2) = @_;
  
  if ($self->{run_mode} eq 'long_reads') {
    if (defined $file2) {
      $sam = $self->align_file($ref, $sam, "$file1 $file2", '', 'mem');
    } else {
      $sam = $self->align_file($ref, $sam, $file1, '', 'mem');
    }
  } else {
    if (defined $file2) {
      my $aligned1 = $self->sai_file($ref, $file1, 'aln');
      my $aligned2 = $self->sai_file($ref, $file2, 'aln');
      $sam = $self->align_file($ref, $sam, "$file1 $file2", "$aligned1 $aligned2", 'sampe');
      unlink $aligned1 if $self->{cleanup};
      unlink $aligned2 if $self->{cleanup};
    } else {
      my $aligned1 = $self->sai_file($ref, $file1, 'aln');
      $sam = $self->align_file($ref, $sam, $file1, $aligned1, 'samse');
      unlink $aligned1 if $self->{cleanup};
    }
  }
  
  return $sam;
}

sub sai_file {
  my ($self, $ref, $file, $program)  = @_;
  
  my $sai_file  = "$file.sai";
  my $align_cmd = "$self->{align_program} $program ";
  $align_cmd   .= " $ref $file > $sai_file ";
  
  $self->run_cmd($align_cmd, 'align');
  
  return $sai_file;
}

sub align_file {
  my ($self, $ref, $sam, $files, $aligneds, $program) = @_;
  
  my $align_cmd = "$self->{align_program} $program ";
  $align_cmd   .= " -v 2 ";
  $align_cmd   .= " $ref $aligneds $files > $sam";
  
  $self->run_cmd($align_cmd, 'align');
  
  return $sam;
}

1;
