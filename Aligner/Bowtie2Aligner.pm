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
  
  $self->{index_program} = 'bowtie2-build';
  $self->{align_program} = 'bowtie2';
  
  if ($self->{run_mode} eq 'local') {
    $self->{align_params} = ' --local ';
  } else {
    $self->{align_params} = '';
  }
  
  if ($self->{aligner_dir}) {
    $self->{index_program} = catdir($self->{aligner_dir}, $self->{index_program});
    $self->{align_program} = catdir($self->{aligner_dir}, $self->{align_program});
  }
  
  return $self;
}

sub index_file {
  my ($self, $file) = @_;
  
  (my $index_name = $file) =~ s/\.\w+$//;
  
  my $index_cmd = "$self->{index_program} --quiet $file $index_name ";
  
  $self->run_cmd($index_cmd, 'index');
}

sub index_exists {
  my ($self, $file) = @_;
  
  (my $index_name = $file) =~ s/\.\w+$//;
  my $exists = -e "$index_name.1.bt2" ? 1 : 0;
  
  return $exists;
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
  
  my $format = $files =~ /fastq/ ? ' -q ' : ' -f ';
  
  my $align_cmd = $self->{align_program};
  $align_cmd   .= " --quiet ";
  $align_cmd   .= " -x $index_name ";
  $align_cmd   .= " -p $self->{threads} ";
  $align_cmd   .= " $self->{align_params} ";
  $align_cmd   .= " $format ";
  $align_cmd   .= " $files > $sam ";
  
  $self->run_cmd($align_cmd, 'align');
  
  return $sam;
}

1;
