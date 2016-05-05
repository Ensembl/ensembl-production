=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::Metadata::DumpFile

=head1 DESCRIPTION

The main workhorse of the Metadata dumping pipeline. So far the only metadata
file being dumped is a tab delimited file containing primary assembly chromosome
names and their size, sorted in karyotype order.

=back

The script is responsible for creating the filenames of these target
files, taking data from the database and the formatting of metadata files.

Currently the only metadata file created is a list of karyotypes of an species,
if it exists along with the chromosome size.

Allowed parameters are:

=over 8

=item species - The species to dump

=item release - A required parameter for the version of Ensembl we are dumping for

=item base_path - The base of the dumps

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Metadata::DumpFile;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Metadata::Base);

use File::Spec;
use File::stat;

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::Scalar qw/check_ref/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;

sub param_defaults {
  my ($self) = @_;
  return {
    #user configurable
    
  };
}

sub fetch_input {
  my ($self) = @_;
 
  my $eg = $self->param('eg');

  if($eg){
     my $base_path  = $self->build_base_directory();
     $self->param('base_path', $base_path);
     
     my $release = $self->param('eg_version');
     $self->param('release', $release);
  }

  # Ensure the needed parameters have been given
  my $base_path     = $self->param('base_path');
  my $species       = $self->param('species');
  my $release       = $self->param('release');  

  throw "Need a species" unless $species;
  throw "Need a release" unless $release;
  throw "Need a base_path" unless $base_path;  

  return;
}

sub run {
  my ($self) = @_;

  my $species = $self->param('species');

  # Try to fetch a slice adaptor for the species, sanity checking before we begin
  my $dba = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice');
  if(! $dba) {
      $self->info("Cannot continue as we cannot find a core:slice DBAdaptor for %s", $species);
      return;
  }

  # Create the karyotype file for the species
  $self->_make_karyotype_file($species);

  return;
}

sub _make_karyotype_file {
  my $self = shift;
  my $species = shift;

  my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'slice');
  if(! $slice_adaptor) {
      $self->info("Cannot continue as we cannot find a core:slice DBAdaptor for %s", $species);
      return;
  }

  $self->info( "Starting karyotype dump for " . $species );

  # Try to get karyotypes for the species
  my $slices = $slice_adaptor->fetch_all_karyotype();

  # If we don't have any slices (ie. chromosomes), don't make the file
  return unless($slices);

  # Create the filename we're going to save the karyotypes to
  my $file = $self->_generate_file_name('karyotype');

  work_with_file($file, 'w', sub {
      my ($fh) = @_;

      # They're returned in order, so cycle through and print them
      foreach my $slice (@{$slices}) {
	  print $fh $slice->seq_region_name . "\t" . $slice->length . "\n";
      }
  });

}

sub _generate_file_name {
  my $self = shift;
  my @name_bits = @_;

  # File name format looks like:
  # <species>.[<extabits>.]<assembly>.<release>.txt
  # e.g. Homo_sapiens.karyotype.GRCh38.84.txt
  unshift @name_bits, $self->web_name();
  push @name_bits, $self->assembly();
  push @name_bits, $self->param('release');
  push @name_bits, 'txt';

  my $file_name = join( '.', @name_bits );
  my $path = $self->data_path();

  return File::Spec->catfile($path, $file_name);

}

1;
