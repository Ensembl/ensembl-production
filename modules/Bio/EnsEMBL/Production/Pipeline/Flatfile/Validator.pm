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

Bio::EnsEMBL::Production::Pipeline::Flatfile::DumpFile

=head1 DESCRIPTION

Base class for validating a file of one of different formats
(e.g. EMBL/Genbank).

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Flatfile::Validator;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw/throw/;

sub new {
  my $class = shift;
  my %args  = ( @_ && ref $_[0] eq 'HASH' ) ? %{ $_[0] } : @_;
  my $self  = bless \%args, $class;

  if ( $args{'file'} ) {
    $self->file( $args{'file'} );
  }

  return $self;
}

sub DESTROY {
  my $self = shift;

  if ( my $fh = $self->{'fh'} ) {
    close $fh;
  }
}

sub file {
  my $self = shift;

  if ( my $file = shift ) {
    # $file = canonpath( $file );

    if ( -e $file && -s _ && -r _ ) { 
      my $fh;
      if ($file =~ /\.gz$/) {
	open $fh, '-|', 'gzip -c -d '. $file or throw "Cannot open $file for gunzip: $!";
      } else {
	open $fh, '<', $file or throw "Can't read file '$file'; $!\n";
      }

      $self->{'file'} = $file;
      $self->{'fh'}   = $fh;
    } else {
      throw "Non-existent, empty or unreadable file: '$file'";
    }
  }

  return 1;
}


sub next_seq {
  my $self = shift;

  if ( my $fh = $self->_fh ) {
    return $self->_parse;
  } else {
    throw "Can't call 'next_seq' without a 'file' argument";
  }
}

sub _parse {
  my $self = shift;

  throw "Can't call _parse method on Validator";
}

sub _readline {
  my $self = shift;
  my %param =@_;
  my $fh = $self->_fh or return;
  my $line;
 
  # if the buffer been filled by _pushback then return the buffer
  # contents, rather than read from the filehandle
  if ( @{$self->{'_readbuffer'} || [] } ) {
    $line = shift @{$self->{'_readbuffer'}};
  } else {
    $line = <$fh>;
  }
     
  # strip line endings
  $line =~ s/\015\012/\012/g if $line; # Change all CR/LF pairs to LF
  # $line =~ tr/\015/\n/ unless $ONMAC; # Should change all single CRs to NEWLINE if not on Mac

  return $line;
}

sub _pushback {
  my ($self, $value) = @_;
  return unless $value;
  push @{$self->{'_readbuffer'}}, $value;
}

sub _fh {
  my ($self) = @_;

  return $self->{'fh'};
}

1; 
