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
  
  (
    $self->{max_intron_length},
    $self->{index_mode},
  ) =
  rearrange(
    [
      'MAX_INTRON_LENGTH',
      'INDEX_MODE'
    ], @args
  );
  
  $self->{index_program} = 'STAR';
  $self->{align_program} = 'STAR';
  
  $self->{index_mode} ||= 'default';
  
  # Make memory limit very large as we want the LSF to kill the job if too
  # much memory is required rather than being killed quietly by STAR.
  $self->{RAM_limit} = '66000000000';
  
  if ($self->{run_mode} eq 'long_reads') {
    $self->{align_program} .= 'long';
    $self->{align_params}   = $self->long_read_options;
  } elsif ($self->{run_mode} eq 'cross_species') {
    $self->{align_program} .= 'long';
    $self->{align_params}   = $self->cross_species_options;
  } else {
    $self->{align_params} = '';
  }
  
  if ($self->{max_intron_length}) {
    $self->{align_params} .= " --alignIntronMax $self->{max_intron_length} ";
  }
    
  return $self;
}

sub long_read_options {
  my ($self) = @_;
  
  # These options were advised for long reads, see: 
  # https://groups.google.com/forum/#!searchin/rna-star/very$20long$20reads/rna-star/-2mBTPWRCJY/jgDbZjhl3NkJ
  # (Do not use seedSearchLmax parameter as it can not deal with reads with Ns or ambiguity bases.)
  
  return 
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
}

sub cross_species_options {
  my ($self) = @_;
  
  return 
    " --alignTranscriptsPerReadNmax 100000 ".
    " --alignTranscriptsPerWindowNmax 10000 ".
    " --outFilterMismatchNmax 1000 ".
    " --seedPerReadNmax 100000 ".
    " --seedPerWindowNmax 1000 ".
    " --seedSearchStartLmax 20 ";
}
sub version {
  my ($self) = @_;
  
  # STAR can't report it's own version (<sigh>), so we have to hope that
  # the directory has the default name, and extract it from there.
  my $version;
  
  my (undef, $dir, undef) = fileparse($self->{align_program});
  $dir =~ s!/$!!;
  if (-l $dir) {
    ($version) = readlink($dir) =~ /STAR_([0-9a-z\.]+)\.[^\/]+$/;
  } else {
    ($version) = $dir =~ /STAR_([0-9a-z\.]+)\.[^\/]+$/;
  }
  
  return $version || 'unknown';
}

sub index_file {
  my ($self, $file) = @_;
  
  my (undef, $path, undef) = fileparse($file, qr/\.[^.]*/);
  
  my $index_options =
    " --runMode genomeGenerate ".
    " --genomeDir $path ".
    " --genomeFastaFiles $file ".
    " --runThreadN $self->{threads} ".
    " --limitGenomeGenerateRAM $self->{RAM_limit} ";
  
  if ($self->{index_mode} eq "himem") {
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
  
  my $index_cmd = $self->{index_program};
  $index_cmd   .= " $index_options";
  
  $self->run_cmd($index_cmd, 'index');
}

sub index_exists {
  my ($self, $file) = @_;
  
  my (undef, $path, undef) = fileparse($file, qr/\.[^.]*/);
  my $index_name = catdir($path, 'SAindex');
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
  
  my $align_options =
    " --genomeDir $path ".
    " --runThreadN $self->{threads} ".
    " --readFilesIn $files ".
    " --outStd SAM ";
    
  my $align_cmd = $self->{align_program};
  $align_cmd   .= " $align_options ";
  $align_cmd   .= " $self->{align_params} ";
  $align_cmd   .= "  > $sam ";
  
  $self->run_cmd($align_cmd, 'align');
  
  return $sam;
}

1;
