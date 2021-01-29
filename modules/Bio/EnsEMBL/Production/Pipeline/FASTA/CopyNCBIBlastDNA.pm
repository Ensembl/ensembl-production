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

Bio::EnsEMBL::Production::Pipeline::FASTA::CopyNCBIBlastDNA

=head1 DESCRIPTION

Performs a find in the ncbi_blast dumps directory, for the given species, in the
previous release FTP dump directory. Any files starting with the given species name
will be copied over to this release's directory.

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

=item type - the ncbi_blast type. Here we only want to copy genomic data

=item blast_dir - This is ncbi_blast at the moment. This information is used by BlastIndexer to create current dir

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::FASTA::CopyNCBIBlastDNA;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::FASTA::BlastIndexer/;

use File::Copy;
use File::Find;
use File::Spec;

sub fetch_input {
  my ($self) = @_;
  my @required = qw/release ftp_dir species/;
  foreach my $key (@required) {
    $self->throw("Need to define a $key parameter") unless $self->param($key);
  }
  my $release = $self->param('release');
  my $prev_release = $release - 1;
  $self->param('previous_release', $prev_release);
  return;
}

sub run {
  my ($self) = @_;
  my $new_path = $self->target_dir();
  my $files = $self->get_blast_files();
  foreach my $file (@{$files}) {
    $self->fine('copy %s to %s', $file, $new_path);
    copy($file, $new_path) or $self->throw("Cannot copy $file to $new_path: $!");
  }
  return;
}

sub get_blast_files {
  my ($self) = @_;
  my $old_release = $self->param('previous_release');
  my $release = $self->param('release');
  my $species = ucfirst($self->param('species'));
  my $base = $self->param('ftp_dir');
  my $type = $self->param('type');
  my $old_path = File::Spec->catdir($base, "release-$old_release", 'ncbi_blast', $type);
  my $filter = sub {
    my ($filename) = @_;
    return ($filename =~ /$species\./) ? 1 : 0;
  };
  my $files = $self->find_files($old_path, $filter);
  return $files;
}

1;
