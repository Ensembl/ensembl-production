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

package Bio::EnsEMBL::EGPipeline::Common::Aligner::TopHat2Aligner;

use strict;
use warnings;
use base qw(Bio::EnsEMBL::EGPipeline::Common::Aligner::Bowtie2Aligner);

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

use File::Basename;
use File::Spec::Functions qw(catdir);
use IPC::Cmd qw(run);

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  
  (
    $self->{max_intron_length},
    $self->{gtf_file}
  ) =
  rearrange(
    [
      'MAX_INTRON_LENGTH', 'GTF_FILE'
    ], @args
  );
  
  $self->{align_program} = 'tophat2';
  
  if ($self->{run_mode} eq 'lenient') {
    $self->{align_params} = ' --read-mismatches=12 --read-gap-length=3 --read-edit-dist=15 --segment-mismatches=3 ';
  } else {
    $self->{align_params} = '';
  }
  
  if ($self->{max_intron_length}) {
    $self->{align_params} .= " --max-intron-length $self->{max_intron_length} ";
  }
  
  if ($self->{gtf_file}) {
    $self->{align_params} .= " -G $self->{gtf_file} ";
  }
  
  if ($self->{aligner_dir}) {
    $self->{align_program} = catdir($self->{aligner_dir}, $self->{align_program});
  }
  
  return $self;
}

sub align {
  my ($self, $ref, $sam, $file1, $file2) = @_;
  
  (my $index_name = $ref) =~ s/\.\w+$//;
  if (defined $file2) {
   	$sam = $self->align_file($index_name, $sam, " $file1 $file2 ");
  } else {
   	$sam = $self->align_file($index_name, $sam, " $file1 ");
  }
  
  return $sam;
}

sub align_file {
  my ($self, $index_name, $sam, $files) = @_;
  
  my $format = $files =~ /fastq/ ? ' -q ' : ' -f ';
  
  my $align_cmd = $self->{align_program};
  $align_cmd   .= " -x $index_name ";
  $align_cmd   .= " -p $self->{threads} ";
  $align_cmd   .= " $self->{align_params} ";
  $align_cmd   .= " $format ";
  $align_cmd   .= " $files > $sam ";
  
  $self->run_cmd($align_cmd, 'align');
  
  return $sam;
}

sub align_file {
  my ($self, $index_name, $sam, $files) = @_;
  
  my (undef, $dir, undef) = fileparse($sam);
  my $output_dir = "$sam\_out";
  mkdir $output_dir unless -e $output_dir;
  
  my $align_cmd = $self->{align_program};
  $align_cmd   .= " -o $output_dir ";
  $align_cmd   .= " --no-convert-bam  ";
  $align_cmd   .= " -p $self->{threads} ";
  $align_cmd   .= " $self->{align_params} ";
  $align_cmd   .= " $index_name $files ";
  
  $self->run_cmd($align_cmd, 'align');
  
  my $mv_cmd = "mv $output_dir/accepted_hits.sam $sam";
  $self->run_cmd($mv_cmd, 'align');
  
  return $sam;
}

1;
