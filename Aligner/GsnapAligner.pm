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
  
  my $aligner_dir;
  ($aligner_dir, $self->{gmap_build}, $self->{gsnap}, $self->{kmer}, $self->{threads}) =
    rearrange(['ALIGNER_DIR', 'GMAP_BUILD', 'GSNAP', 'KMER', 'THREADS'], @args);
  
  $self->{gmap_build} ||= 'gmap_build';
  $self->{gsnap}      ||= 'gsnap';
  $self->{kmer}       ||= 15;
  $self->{threads}    ||= 1;
  
  $self->{gmap_build} = catdir($aligner_dir, $self->{gmap_build});
  $self->{gsnap}      = catdir($aligner_dir, $self->{gsnap});
  
  return $self;
}

sub index_file {
  my ($self, $file) = @_;
  
  my $index_cmd = $self->{gmap_build};
  my ($name, $path, undef) = fileparse($file, qr/\.[^.]*/);
  my $index_options = " -D $path -d $name -k $self->{kmer}";
  my $cmd = "$index_cmd $index_options $file";
  $self->execute($cmd);
  $self->index_cmds($cmd);
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
  
  my $sam_cmd = $self->{gsnap};
  my $sam_options = " -D $path -d $name -N 1 -t $self->{threads} -A sam ";
  my $cmd = "$sam_cmd $sam_options $files > $sam";
  $self->execute($cmd);
  $self->align_cmds($cmd);
  
  return $sam;
}

1;
