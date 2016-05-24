=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::TSV::DumpFileMetadata;

=head1 DESCRIPTION

The main workhorse of the Metadata dumping pipeline. So far the only metadata
file being dumped is a tab delimited file containing primary assembly chromosome
names and their size, sorted in karyotype order.

The script is responsible for creating the filenames of these target
files, taking data from the database and the formatting of metadata files.

Currently the only metadata file created is a list of karyotypes of an species,
if it exists along with the chromosome size.

Allowed parameters are:

=item species - The species to dump

=item release - A required parameter for the version of Ensembl we are dumping for

=item base_path - The base of the dumps


=cut
package Bio::EnsEMBL::Production::Pipeline::TSV::DumpFileMetadata;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::TSV::Base/;

use File::Spec;
use File::stat;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::Scalar qw/check_ref/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;

sub param_defaults {
 return {
   type   => 'karyotype',
 };
}

sub fetch_input {
    my ($self) = @_;

    my $eg     = $self->param_required('eg');
    $self->param('eg', $eg);

    if($eg){
       my $base_path = $self->build_base_directory();
       my $release   = $self->param('eg_version');
       $self->param('base_path', $base_path);
       $self->param('release', $release);
    }

    throw "Need a species" unless $self->param('species');
    throw "Need a release" unless $self->param('release');
    throw "Need a base_path" unless $self->param('base_path');

return;
}

sub run {
  my ($self) = @_;
  
  $self->_make_karyotype_file();
  
return;
}

sub _make_karyotype_file {
    my ($self) = @_;

    my $sp = $self->param_required('species');
    my $sa = Bio::EnsEMBL::Registry->get_adaptor($sp, 'core', 'slice');
   
    if(! $sa) {
        $self->info("Cannot continue as we cannot find a core:slice DBAdaptor for %s", $sp);
        return;
    }

    $self->info( "Starting karyotype dump for " . $sp );

    my $slices = $sa->fetch_all_karyotype();
    # If we don't have any slices (ie. chromosomes), don't make the file
    return unless($slices);
 
    my $file = $self->_generate_file_name();
  
    work_with_file($file, 'w', sub {
      my ($fh) = @_;
      # They're returned in order, so cycle through and print them
      foreach my $slice (@{$slices}) {
     	  print $fh $slice->seq_region_name . "\t" . $slice->length . "\n";
      }
   });

  $self->info( "Compressing tsv dump for " . $sp);
  my $unzip_file = $file;
  `gzip $unzip_file`;

return;
}

1;
