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

package Bio::EnsEMBL::EGPipeline::Common::Aligner::StarAligner;

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
  ($aligner_dir, $self->{star}, $self->{max_intron_size}, $self->{threads}, $self->{read_type}, $self->{memory_mode}) =
    rearrange(['ALIGNER_DIR', 'STAR', 'MAX_INTRON_LENGTH', 'THREADS', 'READ_TYPE', 'MEMORY_MODE'], @args);
  
  $self->{star}            ||= 'STAR';
  $self->{threads}         ||= 1;
  $self->{max_intron_size} ||= 25000;
  $self->{memory_mode}     ||= 'default';
  $self->{read_type}       ||= 'default';

  $self->{star} = catdir($aligner_dir, $self->{star});
  
  # Make memory limit very large as we want the LSF to kill the job if too
  # much memory is required rather than being killed quietly by STAR.
  $self->{RAM_limit} ||= '66000000000';
  
  # These options were advised for long reads, see: 
  # https://groups.google.com/forum/#!searchin/rna-star/very$20long$20reads/rna-star/-2mBTPWRCJY/jgDbZjhl3NkJ
  # (Do not use seedSearchLmax parameter as it can not deal with reads with Ns or ambiguity bases.)
  $self->{long_read_options} =
    " --alignTranscriptsPerReadNmax 100000 ".
    " --alignTranscriptsPerWindowNmax 10000 ".
    " --alignWindowsPerReadNmax 30000 ".
    " --outFilterMatchNminOverLread 0.66 ".
    " --outFilterMultimapScoreRange 100 ".
    " --outFilterMismatchNmax 1000 ".
    " --outFilterScoreMinOverLread 0 ".
    " --seedPerReadNmax 100000 ".
    " --seedPerWindowNmax 1000 ".
    " --seedSearchStartLmax 12 ".
    " --winAnchorMultimapNmax 200 ";
  
  $self->{cross_species_options} =
    " --alignTranscriptsPerReadNmax 100000 ".
    " --alignTranscriptsPerWindowNmax 10000 ".
    " --outFilterMismatchNmax 1000 ".
    " --seedPerReadNmax 100000 ".
    " --seedPerWindowNmax 1000 ".
    " --seedSearchStartLmax 20 ";
  
  return $self;
}

sub index_file {
  my ($self, $file) = @_;
  
  my $index_cmd = $self->{star};
  my (undef, $path, undef) = fileparse($file, qr/\.[^.]*/);
  my $index_options =
    " --runMode genomeGenerate ".
    " --genomeDir $path ".
    " --genomeFastaFiles $file ".
    " --runThreadN $self->{threads} ".
    " --limitGenomeGenerateRAM $self->{RAM_limit} ";
  
  if ($self->{memory_mode} eq "himem") {
    my $size = -s $file;
    my $genomeSAindexNbases = ( log($size)/log(2) )/2 - 1;
    
    my $sequence_count = qx/cat $file | grep -c ">"/;
    chomp($sequence_count);
    my $genomeChrBinNbits = ( log($size/$sequence_count)/log(2) );
    
    $index_options .=
      " --genomeSAsparseD 2 ".
      " --genomeSAindexNbases $genomeSAindexNbases ".
      " --genomeChrBinNbits $genomeChrBinNbits";
  }
  
  my $cmd = "$index_cmd $index_options";
  system($cmd) == 0 || throw "Cannot execute $cmd";
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
  
  my $sam_cmd = $self->{star};
  my $sam_options =
    " --genomeDir $path ".
    " --runThreadN $self->{threads} ".
    " --alignIntronMax $self->{max_intron_size} ".
    " --readFilesIn $files ".
    " --outStd SAM ";
  
  if ($self->{read_type} eq 'long_reads') {
    $sam_cmd .= 'long';
    $sam_options .= $self->{long_read_options};
  } elsif ($self->{read_type} eq 'cross_species') {
    $sam_cmd .= 'long';
    $sam_options .= $self->{cross_species_options};
  }
  
  my $cmd = "$sam_cmd $sam_options > $sam";
  system($cmd) == 0 || throw "Cannot execute $cmd";
  
  return $sam;
}

1;
