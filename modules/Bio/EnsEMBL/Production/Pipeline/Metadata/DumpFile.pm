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
files, taking data from the database and the formatting of the FASTA
headers. It is also responsible for the creation of README files pertaining
to the type of dumps produced. The final files are all Gzipped at normal
levels of compression.

B<N.B.> This code will remove any files already found in the target directory
on its first run as it assumes all data will be dumped in the one process. It
is selective of its directory meaning a rerun of DNA dumps will not cause
the protein/cdna files to be removed.

Allowed parameters are:

=over 8

=item species - The species to dump

=item release - A required parameter for the version of Ensembl we are dumping for

=item base_path - The base of the dumps

=item overwrite_files - If the same file name is generated we will overwrite 
                        the into that file rather than appending

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Metadata::DumpFile;

use strict;
use warnings;

use File::Spec;
use File::stat;

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::Scalar qw/check_ref/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;

sub param_defaults {
  my ($self) = @_;
  return {
    #user configurable
    overwrite_files => 0,
    
  };
}

sub fetch_input {
  my ($self) = @_;
 
  my $eg = $self->param('eg');
  $self->param('eg', $eg);

  if($eg){
     my $base_path  = $self->build_base_directory();
     $self->param('base_path', $base_path);
     
     my $release = $self->param('eg_version');
     $self->param('release', $release);
  }

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

  my $dba = $self->get_DBAdaptor($species, 'core', 'slice');
  if(! $dba) {
      $self->info("Cannot continue with %s as we cannot find a DBAdaptor", $type);
      next;
  }

  $self->_make_karyotype_file();

  return;
}

sub _make_karyotype_file {
  my $self = shift;

  my $dba = $self->get_DBAdaptor($species, 'core', 'slice');
  if(! $dba) {
      $self->info("Cannot continue with %s as we cannot find a DBAdaptor", $type);
      next;
  }

  $self->info( "Starting karyotype dump for " . $species );

  my $slices = $dba->fetch_all_karyotype();

  # If we don't have any slices (ie. chromosomes), don't make the file
  return unless($slices);

  my $file = $self->_generate_file_name('karyotype');

  work_with_file($file, 'w', sub {
      my ($fh) = @_;

      foreach my $slice (@{$slices}) {
	  print $fh $slice->chr_name . "\t" . $slice->length . "\n";
      }
  });

}

sub _generate_file_name {
  my $self = shift;
  my @name_bits = @_

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

sub data_path {
  my ($self) = @_;

  $self->throw("No 'species' parameter specified")
    unless $self->param('species');

  return $self->get_dir('txt', $self->param('species'));
}

1;
