=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::FASTA::BlastIndexer

=head1 DESCRIPTION

Creates 2bit file of the given GZipped file. The resulting index
is created under the parameter location I<base_path> in blat/index.

The module also performs filtering of non-reference sequence regions
and can filter the redundant Y chromosome piece for human (as 2bit does
not like repeated sequence region names).

Allowed parameters are:

=over 8

=item file - The file to index

=item program - The location of the faToTwoBit program

=item base_path - The base of the dumps

=item index     - The type of file to index; supported values are empty, 
                  I<dna>, I<dna_sm> or I<dna_rm>. If specified we will look for this
                  string in the filename surrounded by '.' e.g. .dna.

=item skip - Skip this iteration of the pipeline

=item index_masked_files - If set to false then we will skip processing every masked file name

=back

=cut


package Bio::EnsEMBL::Production::Pipeline::FASTA::BlatIndexer;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::FASTA::Indexer/;

use File::Spec;
use File::stat;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;
use Bio::EnsEMBL::Utils::Exception qw/throw/;

#A hash of species names and their port numbers. The latter is
#needed to create the final file name.
my $species_port = {
  'lates_calcarifer'  => 30080,
  'Homo_sapiens'          => 30001,
  'Mus_musculus'          => 30002,
  'Danio_rerio'           => 30003,
  'Rattus_norvegicus'     => 30005,
  'Gallus_gallus'         => 30010,
  'Canis_familiaris'      => 30013,
  'Bos_taurus'            => 30017,
  'Oryctolagus_cuniculus' => 30025,
  'Oryzias_latipes'       => 30026,
  'Sus_scrofa'            => 30039,
  'Meleagris_gallopavo'   => 30064,
  'Anas_platyrhynchos'    => 30066,
  'Ovis_aries'            => 30068,
  'Oreochromis_niloticus' => 30072,
  'Gadus_morhua'          => 30071,
};

sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults()},
    program => 'faToTwoBit',
    'index' => 'dna', #or dna_rm and dna_sm
  };
}

sub fetch_input {
  my ($self) = @_;
  return if ! $self->ok_to_index_file();
  $self->assert_executable($self->param('program'));
  $self->assert_executable('gunzip');
  return;
}

sub run {
  my ($self) = @_;
  return if ! $self->ok_to_index_file();
  if($self->run_indexing()) {
    $self->SUPER::run();
  }
  return;
}

sub run_indexing {
  my ($self) = @_;
  my $index = $self->param('index');
  if($index) {
    my $file = $self->param('file');
    return (index($file, ".${index}.") > -1) ? 1 : 0;
  }
  return 1;
}

sub index_file {
  my ($self, $file) = @_;
  
  my $target_file = $self->target_file();
  my $cmd = sprintf(q{%s %s %s}, 
    $self->param('program'), $file, $target_file);
  
  $self->run_cmd($cmd);
  unlink $file or throw "Cannot remove the file '$file' from the filesystem: $!";
  
  #Check the file size. If it's 16 bytes then reject as that is an empty file for 2bit
  my $filesize = stat($target_file)->size();
  if($filesize <= 16) {
    unlink $file;
    my $msg = sprintf(
      'The file %s produced a 2bit file %d byte(s). Lower than 17 bytes therefore empty 2 bit file',
      $file, $filesize
    );
    $self->throw($msg);
  }
  
  return;
}

sub decompress {
  my ($self) = @_;
  
  #If we have no non-reference seq regions then use normal decompress
  if(! $self->has_non_refs()) {
    return $self->SUPER::decompress();
  }
  
  #Filter for non-refs
  my $source = $self->param('file');
  my $target_dir = $self->target_dir();
  my ($vol, $dir, $file) = File::Spec->splitpath($source);
  $file =~ s/.gz$//;
  my $target = File::Spec->catdir($target_dir, $file);
  $self->info('Writing to %s', $target);
  work_with_file($target, 'w', sub {
    my ($trg_fh) = @_;
    $self->filter_fasta_for_nonref($source, $trg_fh);
    return;
  });

  return $target;
}

#Filename like 30001.Homo_sapiens.GRCh38.2bit
sub target_filename {
  my ($self) = @_;

  my ($name, $port, $assembly);
  foreach my $species (keys $species_port) {
    next if $species =! $self->web_name();
    $name = $species;
    $port = $species_port->{$species};
    $assembly = $self->assembly();
  }

  return join(q{.}, $port, $name, $assembly, '2bit');
}

sub target_file {
  my ($self) = @_;
  my $target_dir = $self->target_dir();
  my $target_filename = $self->target_filename();
  return File::Spec->catfile($target_dir, $target_filename);
  return;
}

sub target_dir {
  my ($self) = @_;
  return $self->index_path('blat', $self->param('index'));
}

1;
