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

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  
  my $aligner_dir;
  ( $aligner_dir, $self->{bwa}, $self->{program}, $self->{read_type} ) =
    rearrange(['ALIGNER_DIR', 'BWA', 'PROGRAM', 'READ_TYPE'], @args);
  
  $self->{bwa}       ||= 'bwa';
  $self->{read_type} ||= 'default';
  $self->{program}   ||= ($self->{read_type} eq 'long_reads') ? 'mem' : 'aln';
  
  $self->{bwa} = catdir($aligner_dir, $self->{bwa});
  
  return $self;
}

sub index_file {
  my ($self, $file) = @_;
  
  my $index_cmd = "$self->{bwa} index ";
  my $index_options = " -a bwtsw ";
  my $cmd = "$index_cmd $index_options $file";
  system($cmd) == 0 || throw "Cannot execute $cmd";
  
  my $samtools_index_cmd = "$self->{samtools} faidx ";
  $cmd = "$samtools_index_cmd $file";
  system($cmd) == 0 || throw "Cannot execute $cmd";
}

sub align {
  my ($self, $ref, $sam, $file1, $file2) = @_;
  
  if ($self->{program} eq 'aln') {
    if (defined $file2) {
      my $aligned1 = $self->sai_file($ref, $file1);
      my $aligned2 = $self->sai_file($ref, $file2);
      $sam = $self->align_file($ref, $sam, "$file1 $file2", "$aligned1 $aligned2", 'sampe');
      unlink $aligned1 if $self->{cleanup};
      unlink $aligned2 if $self->{cleanup};
    } else {
      my $aligned1 = $self->sai_file($ref, $file1);
      $sam = $self->align_file($ref, $sam, $file1, $aligned1, 'samse');
      unlink $aligned1 if $self->{cleanup};
    }
  } else {
    if (defined $file2) {
      $sam = $self->align_file($ref, $sam, "$file1 $file2", '', $self->{program});
    } else {
      $sam = $self->align_file($ref, $sam, $file1, '', $self->{program});
    }
  }
  
  return $sam;
}

sub sai_file {
  my ($self, $ref, $file)  = @_;
  
  my $sai_file = "$file.sai";
  my $align_cmd = "$self->{bwa} $self->{program} ";
  my $cmd = "$align_cmd $ref $file > $sai_file";
  system($cmd) == 0 || throw "Cannot execute $cmd";
  
  return $sai_file;
}

sub align_file {
  my ($self, $ref, $sam, $files, $aligneds, $program) = @_;
  
  my $sam_cmd = "$self->{bwa} $program ";
  my $cmd = "$sam_cmd $ref $aligneds $files > $sam";
  system($cmd) == 0 || throw "Cannot execute $cmd";
  
  return $sam;
}

1;
