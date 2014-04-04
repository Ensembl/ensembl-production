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

package Bio::EnsEMBL::EGPipeline::Common::Aligner::GsnapAligner;
use Log::Log4perl qw(:easy);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use base qw(Bio::EnsEMBL::EGPipeline::Common::Aligner);
use File::Basename;

my $logger = get_logger();
# gmap_build -D directory -d genome_name -k kmer_size fastafile
my $build_map = '%s -D %s -d %s -k %d %s';
# gsnap -N 1 -t nb_threads -A sam -D directory -d genome_name fastq1 fastq2
my $gsnap_pe = '%s -N 1 -t %s -A sam -D %s -d %s %s %s > %s';
my $gsnap_se = '%s -N 1 -t %s -A sam -D %s -d %s %s > %s';

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  ($self->{gmap_build}, $self->{gsnap}, $self->{kmer}, $self->{nb_threads}) = rearrange(['GMAP_BUILD', 'GSNAP', 'KMER', 'NB_THREADS'], @args);
  $self->{gmap_build} ||= 'gmap_build';
  $self->{gsnap}      ||= 'gsnap';
  $self->{kmer}       ||= 15;
  $self->{nb_threads} ||= '1';
  return $self;
}

sub index_file {
  my ($self, $file) = @_;
  my ($name, $directories, $suffix) = fileparse($file,qr/\.[^.]*/);
  my $comm = sprintf($build_map, $self->{gmap_build}, $directories, $name, $self->{kmer}, $file);
  $logger->debug("Executing $comm");
  system($comm) == 0 || throw "Cannot execute $comm";
  return;
}

sub align {
  my ($self, $ref, $sam, $file1, $file2) = @_;
  my ($refname, $refdir, $refsuffix) = fileparse($ref,qr/\.[^.]*/);

  if(defined $file2) {
   	$self->pairedend_to_sam($refname,$refdir,$sam,$file1,$file2);
  } else {
   	$self->single_to_sam($refname,$refdir,$sam,$file1);  	
  }
  return $sam;
}

sub pairedend_to_sam {
  my ($self, $refname,$refdir, $sam, $file1, $file2) = @_;
    my $comm = sprintf($gsnap_pe, $self->{gsnap}, $self->{nb_threads}, $refdir, $refname, $file1, $file2, $sam);
  $logger->debug("Executing $comm");
  system($comm) == 0 || throw "Cannot execute $comm";
  return $sam;
}

sub single_to_sam {
  my ($self, $refname,$refdir, $sam, $file1) = @_;
    my $comm = sprintf($gsnap_se, $self->{gsnap}, $self->{nb_threads}, $refdir, $refname, $file1, $sam);
  $logger->debug("Executing $comm");
  system($comm) == 0 || throw "Cannot execute $comm";
  return $sam;
}

1;
