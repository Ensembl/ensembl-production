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

Bio::EnsEMBL::Production::Pipeline::FASTA::CopyDNA

=head1 DESCRIPTION

Performs a find in the DNA dumps directory, for the given species, in the
previous release FTP dump directory. Any files matching the normal gzipped
fasta extension will be copied over to this release's directory.

Previous release is defined as V<release-1>; override this class if your
definition of the previous release is different. 

Allowed parameters are:

=over 8

=item release - Needed to build the target path

=item previous_release - Needed to build the source path

=item ftp_dir - Current location of the FTP directory for the previous 
                release. Should be the root i.e. the level I<release-XX> is in

=item species - Species to work with

=item base_path - The base of the dumps; reused files will be copied to here

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::FASTA::CopyDNA;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::FASTA::Base/;

use File::Copy;
use File::Find;
use File::Spec;

sub fetch_input {
  my ($self) = @_;
  my @required = qw/release ftp_dir species/;
  foreach my $key (@required) {
    $self->throw("Need to define a $key parameter") unless $self->param($key);
  }
  return;
}

sub run {
  my ($self) = @_;
  
  my $new_path = $self->new_path();
  #Remove all files from the new path
  $self->unlink_all_files($new_path);
  
  my $files = $self->get_dna_files();
  foreach my $old_file (@{$files}) {
    my $new_file = $self->new_filename($old_file);
    $self->fine('copy %s %s', $old_file, $new_file);
    copy($old_file, $new_file) or $self->throw("Cannot copy $old_file to $new_file: $!");
  }
  
  return;
}

sub new_filename {
  my ($self, $old_filename) = @_;
  my ($old_volume, $old_dir, $old_file) = File::Spec->splitpath($old_filename);
  my $old_release = $self->param('previous_release');
  my $release = $self->param('release');
  my $new_file = $old_file;
  $new_file =~ s/\.$old_release\./.$release./;
  my $new_path = $self->new_path();
  return File::Spec->catfile($new_path, $new_file);
}

sub new_path {
  my ($self) = @_;
  return $self->fasta_path('dna');
}

sub get_dna_files {
  my ($self) = @_;
  my $old_path = $self->old_path();
  my $filter = sub {
    my ($filename) = @_;
    return ($filename =~ /\.fa\.gz$/ || $filename eq 'README') ? 1 : 0;
  };
  my $files = $self->find_files($old_path, $filter);
  return $files;
}

1;
