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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::FASTA::BlastConverter;

=head1 DESCRIPTION

=head1 MAINTAINER

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::FASTA::BlastConverter; 

use strict;
use warnings;
use base qw(Bio::EnsEMBL::Production::Pipeline::FASTA::Base);

use Bio::EnsEMBL::Utils::Exception qw(throw);
use File::Spec;
use File::Path qw/mkpath/;
use IO::File;
use IO::Uncompress::Gunzip qw/$GunzipError/;

sub param_defaults {
  return {
    header_prefix  => 'EG:',
    directory_name => 'blast_fasta',
  };
}

sub fetch_input {
    my ($self) = @_;

    my $eg     = $self->param_required('eg');
    $self->param('eg', $eg);
    $self->param('blast_path',$self->param('base_path')); 

    if($eg){
       my $base_path = $self->build_base_directory();
       my $release   = $self->param('eg_version');
       $self->param('base_path', $base_path);
       $self->param('release', $release);
    }

return;
}

sub run {
    my ($self) = @_;

   $self->info( "Working with species " . $self->param('species'));
   $self->info( "Detected prefix is " . $self->param('header_prefix'));

   foreach my $params (@{$self->_types()}) { $self->_convert(@{$params});}

return;  
}

sub _types {
    my ($self) = @_;
    # These parameters values are in the form:
    #  dir, type, subtype
    # and used as parameters to the _convert method below.
return [
  [qw/dna dna toplevel/],
  [qw/dna dna_rm toplevel/],
  [qw/pep pep all/],
# [qw/pep pep abinitio/],
  [qw/cdna cdna all/],
# [qw/cdna cdna abinitio/],
  [qw/ncrna ncrna/],
 ];
}

sub _convert {
    my ($self, $dir, $type, $subtype) = @_;

    my $prefix      = $self->param('header_prefix');
    my $file_name   = $self->_get_file_name($dir, $type, $subtype);
    my $source_dir  = $self->fasta_path($dir);
    my $source_file = File::Spec->catdir($source_dir, $file_name).q{.gz};
    my $species     = $self->_species_dir();
    my @target_dirs = ($self->param('blast_path'), $self->param('directory_name'), $self->division(), $species);    
    my $target_dir  = File::Spec->catdir(@target_dirs);
    mkpath($target_dir);

    if(-f $source_file) {
      $self->info( "Processing file $file_name");
      my $target_file       = File::Spec->catdir($target_dir, $file_name).q{.gz};
      my $target_file_unzip = File::Spec->catdir($target_dir, $file_name);

      `cp $source_file $target_dir`;
      `gunzip $target_file`;
      # Replace fasta header
      `perl -pi -e 's/^>/>$prefix/' $target_file_unzip`;
    }

return;
}

sub _get_file_name {
    my ($self, $data_type, $type, $subtype ) = @_;
    # File name format looks like:
    # <species>.<assembly>.<eg_version>.<sequence type>.<id type>.fa
    # e.g. Fusarium_oxysporum.FO2.dna.toplevel.fa    
    #      Fusarium_oxysporum.FO2.dna_rm.toplevel.fa    
    my @name_bits;
    push @name_bits, $self->web_name();
    push @name_bits, $self->assembly();
    #push @name_bits, $self->param('eg_version');
    push @name_bits, lc($type);
    push @name_bits, $subtype if(defined $subtype);
    push @name_bits, 'fa';

    my $file_name = join( '.', @name_bits );

return $file_name;
}

sub _species_dir {
   my ($self) = @_;

   my @sp_dir;
   my $mc      = $self->get_DBAdaptor()->get_MetaContainer();
   my $species = $mc->get_production_name();
   push @sp_dir, $species;

   if($mc->is_multispecies()==1){
      my $collection_db;
      $collection_db = $1 if($mc->dbc->dbname()=~/(.+)\_core/);
      my $sp    = pop(@sp_dir);
      push @sp_dir, $collection_db;
      push @sp_dir, $sp;
   }

return File::Spec->catdir(@sp_dir);
}

1;
