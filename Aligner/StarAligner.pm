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

package Bio::EnsEMBL::EGPipeline::Common::Aligner::StarAligner;

use Log::Log4perl qw(:easy);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use base qw(Bio::EnsEMBL::EGPipeline::Common::Aligner);
use File::Basename;

my $logger = get_logger();

# Optimized to require less memory but slower at mapping stage
my $build_map_himem = 'STAR --runMode genomeGenerate --genomeDir %s --genomeFastaFiles %s --runThreadN %s --limitGenomeGenerateRAM %s --genomeSAsparseD 2 --genomeSAindexNbases 15 --genomeChrBinNbits 15';
# Default
my $build_map_default = 'STAR --runMode genomeGenerate --genomeDir %s --genomeFastaFiles %s --runThreadN %s --limitGenomeGenerateRAM %s';

my $build_map = undef;

# Default - use this with short reads

my $star_default_pe = 'STAR --genomeDir %s --runThreadN %s --alignIntronMax %s --readFilesIn %s %s --outStd SAM > %s';
my $star_default_se = 'STAR --genomeDir %s --runThreadN %s --alignIntronMax %s --readFilesIn %s --outStd SAM > %s';

# Do not use seedSearchLmax parameter as it can not deal with reads with Ns or ambiguity bases

# Long Reads

# Adviced was:
# Using STARLong
# --outFilterMultimapScoreRange 20   --outFilterScoreMinOverLread 0   --outFilterMatchNminOverLread 0.66   --outFilterMismatchNmax 1000   --winAnchorMultimapNmax 200   --seedSearchStartLmax 12   --seedPerReadNmax 100000   --seedPerWindowNmax 100   --alignTranscriptsPerReadNmax 100000   --alignTranscriptsPerWindowNmax 10000
# See
# https://groups.google.com/forum/#!searchin/rna-star/very$20long$20reads/rna-star/-2mBTPWRCJY/jgDbZjhl3NkJ

# --alignWindowsPerReadNmax 30000 added to accommodate very long reads (>= 5000bp)

my $star_long_reads_pe = 'STARlong --genomeDir %s --runThreadN %s --alignIntronMax %s --readFilesIn %s %s --outStd SAM --outFilterMultimapScoreRange 100  --outFilterScoreMinOverLread 0 --outFilterMatchNminOverLread 0.66 --outFilterMismatchNmax 1000 --winAnchorMultimapNmax 200 --seedSearchStartLmax 12 --alignWindowsPerReadNmax 30000 --seedPerReadNmax 100000 --seedPerWindowNmax 1000 --alignTranscriptsPerReadNmax 100000 --alignTranscriptsPerWindowNmax 10000 > %s';
my $star_long_reads_se = 'STARlong --genomeDir %s --runThreadN %s --alignIntronMax %s --readFilesIn %s --outStd SAM --outFilterMultimapScoreRange 100  --outFilterScoreMinOverLread 0 --outFilterMatchNminOverLread 0.66 --outFilterMismatchNmax 1000 --winAnchorMultimapNmax 200 --seedSearchStartLmax 12 --alignWindowsPerReadNmax 30000 --seedPerReadNmax 100000 --seedPerWindowNmax 1000 --alignTranscriptsPerReadNmax 100000 --alignTranscriptsPerWindowNmax 10000 > %s';

# Optimized for cross species comparison (ie for sensitivity)
# but gives very long introns

# --outFilterMismatchNmax 100   --seedSearchStartLmax 10   --seedPerReadNmax 100000   --seedPerWindowNmax 1000   --alignTranscriptsPerReadNmax 100000   --alignTranscriptsPerWindowNmax 10000

#my $star_long_reads_pe = 'STARlong --genomeDir %s --runThreadN %s --alignIntronMax %s --readFilesIn %s %s --outStd SAM --outFilterMismatchNmax 1000 --seedSearchStartLmax 20 --seedPerReadNmax 100000 --seedPerWindowNmax 1000 --alignTranscriptsPerReadNmax 100000 --alignTranscriptsPerWindowNmax 10000 > %s';
#my $star_long_reads_se = 'STARlong --genomeDir %s --runThreadN %s --alignIntronMax %s --readFilesIn %s --outStd SAM --outFilterMismatchNmax 1000 --seedSearchStartLmax 20 --seedPerReadNmax 100000 --seedPerWindowNmax 1000 --alignTranscriptsPerReadNmax 100000 --alignTranscriptsPerWindowNmax 10000 > %s';

my $star_pe = undef;
my $star_se = undef;

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  ($self->{nb_threads},$self->{max_intron_size},$self->{memory_mode},$self->{read_type}) = rearrange(['NB_THREADS', 'MAX_INTRON_LENGTH', 'MEMORY_MODE', 'READ_TYPE'], @args);
  $self->{nb_threads}  ||= 4;
  $self->{max_intron_size} ||= 25000;
  $self->{memory_mode} ||= 'default';
  $self->{read_type}   ||= 'default';

  # Let's make it very large as anyway we want the LSF to kill the job if too much memory is required
  # rather than being killed quietly by STAR if memory max requirements are reached
  $self->{RAM_limit} ||= '66000000000';

  warn("memory_mode for indexing the genome, " . $self->{memory_mode} . "\n");

  if ($self->{memory_mode} eq "default") {
      $build_map = $build_map_default;
  }
  elsif ($self->{memory_mode} eq "himem") {
      $build_map = $build_map_himem;
  }

  warn("read_type for running the genome, " . $self->{read_type} . "\n");

  if ($self->{read_type} eq "default") {
      $star_se = $star_default_se;
      $star_pe = $star_default_pe;
  }
  elsif ($self->{read_type} eq "long_reads") {
      $star_se = $star_long_reads_se;
      $star_pe = $star_long_reads_pe;
  }
  else {
      throw("read type, " . $self->{read_type} . " is not allowed [default|long_reads]\n");
  }

  return $self;
}

sub index_file {
  my ($self, $file) = @_;
  my ($name, $directories, $suffix) = fileparse($file,qr/\.[^.]*/);
  
  my $comm = sprintf($build_map, $directories, $file, $self->{nb_threads}, $self->{RAM_limit});
  $logger->debug("Executing $comm");
  system($comm) == 0 || throw "Cannot execute command, $comm";
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
  my $comm = sprintf($star_pe, $refdir, $self->{nb_threads}, $self->{max_intron_size}, $file1, $file2, $sam);
  $logger->debug("Executing $comm");
  #system($comm) == 0 || throw "Cannot execute command, $comm";
  my $wd = $sam;
  $wd =~ s/[^\/]+$//;
  my $stderr = qx(bash -c 'cd $wd && $comm' 2>&1 1>/dev/null);
  if ($stderr) {
      throw("Failed to execute external command, $comm, because of $stderr");
      #throw "Cannot execute command, $comm";
  }
  return $sam;
}

sub single_to_sam {
  my ($self, $refname,$refdir, $sam, $file1) = @_;
  my $comm = sprintf($star_se, $refdir, $self->{nb_threads}, $self->{max_intron_size}, $file1, $sam);
  $logger->debug("Executing command, $comm");
  #system($comm) == 0 || throw "Cannot execute command, $comm";
  my $wd = $sam;
  $wd =~ s/[^\/]+$//;
  my $stderr = qx(bash -c 'cd $wd && $comm' 2>&1 1>/dev/null);
  if ($stderr) {
      warn("Failed to execute external command, $@, because of $stderr\n");
      throw "Cannot execute command, $comm";
  }
  return $sam;
}

1;
