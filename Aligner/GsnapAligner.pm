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

package Bio::EnsEMBL::EGPipeline::Common::Aligner::GsnapAligner;

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
  
  ($self->{kmer}) = rearrange(['KMER'], @args);
  $self->{kmer} ||= 15;
  
  $self->{index_program} = 'gmap_build';
  $self->{align_program} = 'gsnap';
  
  if ($self->{aligner_dir}) {
    $self->{index_program} = catdir($self->{aligner_dir}, $self->{index_program});
    $self->{align_program} = catdir($self->{aligner_dir}, $self->{align_program});
  }
  
  return $self;
}

sub index_file {
  my ($self, $file) = @_;
  
  my ($name, $path, undef) = fileparse($file, qr/\.[^.]*/);
  
  my $index_cmd  = $self->{index_program};
  $index_cmd    .= " -D $path -d $name -k $self->{kmer} ";
  $index_cmd    .= " $file ";
  
  $self->run_cmd($index_cmd, 'index');
}

sub index_exists {
  my ($self, $file) = @_;
  
  (my $index_name = $file) =~ s/\.\w+$//;
  my $exists = -e $index_name ? 1 : 0;
  
  return $exists;
}

sub align {
  my ($self, $ref, $sam, $file1, $file2) = @_;
  
  my ($name, $path, undef) = fileparse($ref, qr/\.[^.]*/);
  
  if (defined $file2) {
   	$sam = $self->align_file($name, $path, $sam, "$file1 $file2");
  } else {
   	$sam = $self->align_file($name, $path, $sam, $file1);
  }
  
  return $sam;
}

sub align_file {
  my ($self, $name, $path, $sam, $files) = @_;
  
  my $align_cmd = $self->{align_program};
  $align_cmd   .= " -D $path -d $name -N 1 -t $self->{threads} -A sam ";
  $align_cmd   .= " $files > $sam ";
  
  $self->run_cmd($align_cmd, 'align');
  
  return $sam;
}

1;
