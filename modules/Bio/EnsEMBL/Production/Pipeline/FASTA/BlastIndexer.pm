=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

A stub blast indexer of the given GZipped file. The resulting index
is created under the parameter location I<base_path> in I<blast_dir> and then in a
directory defined by the type of dump. The type of dump also changes the file
name generated. Genomic dumps have their release number replaced with the
last repeat masked date. 

Allowed parameters are:

=over 8

=item file - The file to index

=item program - The location of the xdformat program

=item molecule - The type of molecule to index. I<dna> and I<pep> are allowed

=item type - Type of index we are creating. I<genomic> and I<genes> are allowed

=item base_path - The base of the dumps

=item release - Required for correct DB naming

=item skip - Skip this iteration of the pipeline

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::FASTA::BlastIndexer;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::FASTA::Indexer/;

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use File::Copy qw/copy/;
use File::Spec;
use POSIX qw/strftime/;

sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults()},
#    program => 'xdformat', #program to use for indexing
#    molecule => 'pep', #pep or dna
#    type => 'genes',    #genes or genomic
#    blast_dir => 'blast_type_dir', # sets the type of directory used for 
  };
}

sub fetch_input {
  my ($self) = @_;
  return if ! $self->ok_to_index_file();
  my $mol = $self->param('molecule');
  throw "No molecule param given" unless defined $mol;
  if($mol ne 'dna' && $mol ne 'pep') {
    throw "param 'molecule' must be set to 'dna' or 'pep'. Value given was '${$mol}'";
  }
  my $type = $self->param('type');
  throw "No type param given" unless defined $type;
  if($type ne 'genomic' && $type ne 'genes') {
    throw "param 'type' must be set to 'genomic' or 'genes'. Value given was '${$type}'";
  }
  $self->assert_executable($self->param('program'));
  $self->assert_executable('gunzip');
}

sub write_output {
  my ($self) = @_;
  return if $self->param('skip');
  $self->dataflow_output_id({
    species     => $self->param('species'),
    type        => $self->param('type'),
    molecule    => $self->param('molecule'),
    index_base  => $self->param('index_base')
  }, 1);
  return;
}

sub target_file {
  my ($self, $file) = @_;
  my $target_dir = $self->target_dir();
  my $target_filename = $self->target_filename($file);
  return File::Spec->catfile($target_dir, $target_filename);
}

# Produce a dir like /nfs/path/to/<blast_dir>/genes/XXX && /nfs/path/to/<blast_dir>/dna/XXX
sub target_dir {
  my ($self) = @_;
  return $self->index_path($self->param('blast_dir'), $self->param('type'));
}

sub db_title {
  my ($self, $source_file) = @_;
  my ($vol, $dir, $file) = File::Spec->splitpath($source_file);
  my $release = $self->param('release');
  my $title = $file;
  $title =~ s/$release\.//;
  return $title;
}

sub db_date {
  my ($self) = @_;
  return strftime('%d-%m-%Y', gmtime());
}

#Source like Homo_sapiens.GRCh37.68.dna.toplevel.fa
#Filename like Homo_sapiens.GRCh37.20090401.dna.toplevel.fa
sub target_filename {
  my ($self, $source_file) = @_;
  my ($vol, $dir, $file) = File::Spec->splitpath($source_file);
  if($self->param('type') eq 'genomic') {
    my @split = split(/\./, $file);
    my $rm_date = $self->repeat_mask_date();
    splice @split, -3, 0, $rm_date;
    return join(q{.}, @split);
  }
  return $file;
}

1;
