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
use Bio::EnsEMBL::Utils::IO qw/gz_work_with_file/;
use Bio::EnsEMBL::Utils::IO::GTFSerializer;
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

  my $path = $self->_generate_file_name();
  $self->info("Dumping GTF to %s", $path);
  gz_work_with_file($path, 'w', 
		    sub {
		      my ($fh) = @_;
		      my $gtf_serializer = 
			Bio::EnsEMBL::Utils::IO::GTFSerializer->new($fh);

		      # filter for 1st portion of human Y
		      foreach my $slice (@{$self->get_Slices('core', 1)}) { 
			foreach my $gene (@{$slice->get_all_Genes(undef, undef, 1)}) {
			  foreach my $transcript (@{$gene->get_all_Transcripts()}) {
			    $gtf_serializer->print_feature($transcript);
			  }
			}
		      }
		    });
  
  return;
}

sub _generate_file_name {
  my ($self) = @_;

  # File name format looks like:
  # <species>.<assembly>.<release>.gtf.gz
  # e.g. Homo_sapiens.GRCh37.71.gtf.gz
  my @name_bits;
  push @name_bits, $self->web_name();
  push @name_bits, $self->assembly();
  push @name_bits, $self->param('release');
  push @name_bits, 'gtf', 'gz';

  my $file_name = join( '.', @name_bits );
  my $path = $self->data_path();

  return File::Spec->catfile($path, $file_name);

}


1;

