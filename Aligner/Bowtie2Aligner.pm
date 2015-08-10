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

package Bio::EnsEMBL::EGPipeline::Common::Aligner::Bowtie2Aligner;

use strict;
use warnings;
use base qw(Bio::EnsEMBL::EGPipeline::Common::Aligner);

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use File::Basename;
use File::Spec::Functions qw(catdir);

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  
  my $aligner_dir;
  ($aligner_dir, $self->{bowtie2_build}, $self->{bowtie2}, $self->{threads}) =
    rearrange(['ALIGNER_DIR', 'BOWTIE2_BUILD', 'BOWTIE2', 'THREADS'], @args);
  
  $self->{bowtie2_build} ||= 'bowtie2-build';
  $self->{bowtie2}       ||= 'bowtie2';
  $self->{threads}       ||= 1;
  
  $self->{bowtie2_build} = catdir($aligner_dir, $self->{bowtie2_build});
  $self->{bowtie2}       = catdir($aligner_dir, $self->{bowtie2});
  
  return $self;
}

sub index_file {
  my ($self, $file) = @_;
  
  my $index_cmd = $self->{bowtie2_build};
  (my $index_name = $file) =~ s/\.\w+$//;
  my $cmd = "$index_cmd $file $index_name";
  system($cmd) == 0 || throw "Cannot execute $cmd";
}

sub align {
  my ($self, $ref, $sam, $file1, $file2) = @_;
  
  (my $index_name = $ref) =~ s/\.\w+$//;
  if (defined $file2) {
   	$sam = $self->align_file($index_name, $sam, " -1 $file1 -2 $file2 ");
  } else {
   	$sam = $self->align_file($index_name, $sam, " -U $file1 ");
  }
  
  return $sam;
}

sub align_file {
  my ($self, $index_name, $sam, $files) = @_;
  
  my $format;
  if ($files =~ /fastq/) {
    $format = ' -q ';
  } else {
    $format = ' -f ';
  }
  
  my $sam_cmd = $self->{bowtie2};
  my $sam_options = " -x $index_name $format --local -p $self->{threads} ";
  my $cmd = "$sam_cmd $sam_options $files > $sam";
  system($cmd) == 0 || throw "Cannot execute $cmd";
  
  return $sam;
}

1;
