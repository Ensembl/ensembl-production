=pod

=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::GTF::DumpFile

=head1 DESCRIPTION

The main workhorse of the GTF dumping pipeline.

Allowed parameters are:

=over 8

=item species - The species to dump

=item base_path - The base of the dumps

=item release - The current release we are emitting

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::GTF::DumpFile;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::GTF::Base);

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::SeqDumper;
use Bio::EnsEMBL::Utils::IO qw/gz_work_with_file work_with_file/;
use File::Path qw/rmtree/;


sub fetch_input {
  my ($self) = @_;
    
  throw "Need a species" unless $self->param('species');
  throw "Need a release" unless $self->param('release');
  throw "Need a base_path" unless $self->param('base_path');
  
  return;
}

sub run {
  my ($self) = @_;
  
  my $root = $self->data_path();
  if(-d $root) {
    $self->info('Directory "%s" already exists; removing', $root);
    rmtree($root);
  }
  
  my $type = $self->param('type');
  my $target = "dump_${type}";
  my $seq_dumper = $self->_seq_dumper();
  
  my @chromosomes;
  my @non_chromosomes;
  foreach my $s (@{$self->get_Slices()}) {
    my $chr = $s->is_chromosome();
    push(@chromosomes, $s) if $chr;
    push(@non_chromosomes, $s) if ! $chr;
  }
  
  if(@non_chromosomes) {
    my $path = $self->_generate_file_name('nonchromosomal');
    $self->info('Dumping non-chromosomal data to %s', $path);
    gz_work_with_file($path, 'w', sub {
      my ($fh) = @_;
      foreach my $slice (@non_chromosomes) {
        $self->fine('Dumping non-chromosomal %s', $slice->name());
        $seq_dumper->$target($slice, $fh);
      }
      return;
    });
  }
  else {
    $self->info('Did not find any non-chromosomal data');
  }
  
  foreach my $slice (@chromosomes) {
    $self->fine('Dumping chromosome %s', $slice->name());
    my $path = $self->_generate_file_name($slice->coord_system_name(), $slice->seq_region_name());
    my $args = {};
    if(-f $path) {
      $self->fine('Path "%s" already exists; appending', $path);
      $args->{Append} = 1;
    }
    gz_work_with_file($path, 'w', sub {
      my ($fh) = @_;
      $seq_dumper->$target($slice, $fh);
      return;
    }, $args);
  }
  
  return;
}

sub _seq_dumper {
  my ($self) = @_;
  my $seq_dumper = Bio::EnsEMBL::Utils::SeqDumper->new();
  $seq_dumper->disable_feature_type('similarity');
  $seq_dumper->disable_feature_type('genscan');
  $seq_dumper->disable_feature_type('variation');
  $seq_dumper->disable_feature_type('repeat');
  return $seq_dumper;
}

sub _generate_file_name {
  my ($self, $section, $name) = @_;

  # File name format looks like:
  # <species>.<assembly>.<release>.<section.name|section>.dat.gz
  # e.g. Homo_sapiens.GRCh37.64.chromosome.20.dat.gz
  #      Homo_sapiens.GRCh37.64.nonchromosomal.dat.gz
  my @name_bits;
  push @name_bits, $self->web_name();
  push @name_bits, $self->assembly();
  push @name_bits, $self->param('release');
  push @name_bits, $section if $section;
  push @name_bits, $name if $name;
  push @name_bits, 'dat', 'gz';

  my $file_name = join( '.', @name_bits );
  my $path = $self->data_path();
  return File::Spec->catfile($path, $file_name);
}


1;

