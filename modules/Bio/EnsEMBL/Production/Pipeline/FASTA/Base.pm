=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FASTA::Base;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use File::Spec;
use File::Path qw/mkpath/;

sub index_path {
  my ( $self, $format, @extras ) = @_;
  my $base_dir = $self->param('base_path');
  my $dir = File::Spec->catdir( $base_dir, $self->division(), $format, @extras);
  mkpath($dir);
  return $dir;
}

sub old_path {
  my ($self, $species, $directory) = @_;
  my $base = $self->param('ftp_dir');
  my $prod = $self->production_name($species);
  my $release = $self->param('previous_release');
  $directory='dna' if !defined $directory;
  my $dir;
  if ($self->division() ne "vertebrates"){
    my $mc = $self->get_DBAdaptor()->get_MetaContainer();
    if ( $mc->is_multispecies() == 1 ) {
      my $collection_db;
      $collection_db = $1 if ( $mc->dbc->dbname() =~ /(.+)\_core/ );
      $dir = File::Spec->catdir($base, "release-$release",$self->division(), 'fasta', $collection_db, $prod, $directory);
    }
    else{
      $dir = File::Spec->catdir($base, "release-$release",$self->division(), 'fasta', $prod, $directory);
    }
  }
  else{
    $dir = File::Spec->catdir($base, "release-$release", 'fasta', $prod, $directory);
  }
}

# Filter a FASTA dump for reference regions only and parse names from the
# headers in the file e.g. NNN:NNN:NNN:1:80:1
sub filter_fasta_for_nonref {
  my ($self, $source_file, $target_fh) = @_;

  my $allowed_regions = $self->allowed_regions();
  
  $self->info('Filtering from %s', $source_file);
  
  open my $src_fh, '-|', "gzip -c -d $source_file" or $self->throw("Cannot decompress $source_file: $!");
  my $transfer = 0;
  while(my $line = <$src_fh>) {
    #HEADER
    if(index($line, '>') == 0) {
      #regex is looking for NNN:NNN:NNN:1:80:1 i.e. the name
      my ($name) = $line =~ />.+\s(.+:.+:.+:\d+:\d+:\d+)/; 
      $transfer = ($allowed_regions->{$name}) ? 1 : 0;
      if($transfer) {
        $self->info('%s was an allowed Slice', $name);
      }
      else {
        $self->info('%s will be skipped; not a reference Slice', $name);
      }
    }
    print $target_fh $line if $transfer;
  }
  close($src_fh);
  
  return;
}

sub allowed_regions {
  my ($self) = @_;
  my $filter_human = 1;
  my @slices = grep { $_->is_reference() } @{$self->get_Slices('core', $filter_human)};
  my %hash = map { $_->name() => 1 } @slices;
  return \%hash;
}

sub has_non_refs {
  my ($self) = @_;
  my $sql = <<'SQL';
select count(*)
from attrib_type at
join seq_region_attrib sra using (attrib_type_id)
join seq_region sr using (seq_region_id)
join coord_system cs using (coord_system_id)
where cs.species_id =?
and at.code =?
SQL
  my $dba = $self->get_DBAdaptor();
  return $dba->dbc()->sql_helper()->execute_single_result(
    -SQL => $sql, -PARAMS => [$dba->species_id(), 'non_ref']);
}


1;
