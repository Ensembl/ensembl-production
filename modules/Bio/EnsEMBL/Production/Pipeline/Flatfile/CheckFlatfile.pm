=pod

=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Production::Pipeline::Flatfile::CheckFlatfile

=head1 DESCRIPTION

Takes in a file and passes it through BioPerl's SeqIO parser code. This
is just a smoke test to ensure the files are well formatted.

Allowed parameters are:

=over 8

=item file - The file to parse

=item type - The format to parse

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Flatfile::CheckFlatfile;

use strict;
use warnings;

use Bio::SeqIO;
use File::Spec;

use base qw/Bio::EnsEMBL::Production::Pipeline::Flatfile::Base/;

use Bio::EnsEMBL::Utils::IO qw(filter_dir);
use Bio::EnsEMBL::Production::Pipeline::Flatfile::ValidatorFactoryMethod;

sub fetch_input {
  my ($self) = @_;

  $self->throw("No 'species' parameter specified") unless $self->param('species');
  $self->throw("No 'type' parameter specified") unless $self->param('type');

  return;
}

sub run {
  my ($self) = @_;

  # select dat.gz files in the directory
  my $data_path = $self->data_path();
  my $files = filter_dir($data_path, sub { 
			   my $file = shift;
			   return $file if $file =~ /\.dat\.gz$/; 
			 });

  my $validator_factory = 
    Bio::EnsEMBL::Production::Pipeline::Flatfile::ValidatorFactoryMethod->new();
  my $type = $self->param('type');

  foreach my $file (@{$files}) {
    my $full_path = File::Spec->catfile($data_path, $file);
    my $validator = $validator_factory->create_instance($type);

    $validator->file($full_path);
    my $count = 0;
    eval {
      while ( $validator->next_seq() ) {
	$self->fine("%s: OK", $file);
	$count++;
      }
    };
    $@ and $self->throw("Error parsing $type file $file: $@");

    my $msg = sprintf("%s: processed %d record(s)", $file, $count);
    $self->info($msg);
    $self->warning($msg);
  }

  return;
}

1;
