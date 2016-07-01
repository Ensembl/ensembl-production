=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::FASTA::CreatePrimaryAssembly

=head1 DESCRIPTION

Scans the given file and attempts to create a primary assembly file which
is a file containing only those regions we believe to be part of the 
core assembly e.g. in Human this is 1-22, X, Y & MT

Allowed parameters are:

=over 8

=item species - Required to indicate which species we are working with

=item file - The file to filter

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::FASTA::CreatePrimaryAssembly;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::FASTA::Base/;

use File::Spec;
use File::stat;

sub fetch_input {
  my ($self) = @_;
  foreach my $key (qw/data_type file/) {
    $self->throw("Cannot find the required parameter $key") unless $self->param($key);
  }
  return;
}

# Creates the file only if required i.e. has non-reference toplevel sequences
sub run {
  my ($self) = @_;
  if($self->has_non_refs()) {
    my @file_list = @{$self->get_dna_files()};
    my $count = scalar(@file_list);
    my $running_total_size = 0;

    if($count) {
      my $target_file = $self->target_file();
      $self->info("Concatting type %s with %d file(s) into %s", $self->param('data_type'), $count, $target_file);
  
      if(-f $target_file) {
        $self->info("Target already exists. Removing");
        unlink $target_file or $self->throw("Could not remove $target_file: $!");
      }
  
      $self->info('Running concat');
      foreach my $file (@file_list) {
        $self->fine('Processing %s', $file);
        $running_total_size += stat($file)->size;
        system("cat $file >> $target_file")
          and $self->throw( sprintf('Cannot concat %s into %s. RC %d', $file, $target_file, ($?>>8)));
      }
  
      $self->info("Catted files together");
  
      my $catted_size = stat($target_file)->size;
  
      if($running_total_size != $catted_size) {
        $self->throw(sprintf('The total size of the files catted together should be %d but was in fact %d. Failing as we expect the catted size to be the same', $running_total_size, $catted_size));
      }
  
      $self->param('target_file', $target_file);
    }
    else {
      $self->throw("Cannot continue as we found no files to concat");
    }
  }
  return;
}

sub target_file {
  my ($self) = @_;
  # File name format looks like:
  # <species>.<assembly>.<sequence type>.<id type>.<id>.fa.gz
  # e.g. Homo_sapiens.GRCh37.dna_rm.toplevel.fa.gz -> Homo_sapiens.GRCh37.dna_rm.primary_assembly.fa.gz
  my $file = $self->param('file');
  $file =~ s/\.toplevel\./.primary_assembly./;
  return $file;
}

sub file_pattern {
  my ($self,$type) = @_;
   my %regexes = (
    dna => qr/.+\.dna\..+\.fa\.gz$/,
    dna_rm => qr/.+\.dna_rm\..+\.fa\.gz$/,
    dna_sm => qr/.+\.dna_sm\..+\.fa\.gz$/,
  );
  return $regexes{$type};
}

sub get_dna_files {
  my ($self) = @_;
  my $path = $self->fasta_path('dna');
  my $data_type = $self->param('data_type');

  my $regex = $self->file_pattern($data_type);
  my $filter = sub {
    my ($filename) = @_;
    return ($filename =~ $regex && $filename !~ /\.toplevel\./ && $filename !~ /\.alt\./) ? 1 : 0;
  };
  my $files = $self->find_files($path, $filter);
  return [ sort @{$files} ];
}

1;
