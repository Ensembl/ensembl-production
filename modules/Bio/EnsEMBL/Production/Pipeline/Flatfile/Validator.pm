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

=cut

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Flatfile::Validator

=head1 DESCRIPTION

Base class for validating a file of one of different formats
(e.g. EMBL/Genbank).

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Flatfile::Validator;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw/throw/;

=head2 new

  Arg [file] : String; the path to the file to validate
  Description: creates a new Validator object.
  Returntype : Bio::EnsEMBL::Production::Pipeline::Flatfile::Validator
  Exceptions : None
  Caller     : general
  Status     : Stable

=cut

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

=head2 file

  Arg [1]    : String; file path
  Description: opens a filehandle on the (compressed or not) file
               specified as argument
  Returntype : true on success
  Exceptions : if file doesn't exist, is empty or unreadable
  Caller     : general
  Status     : Stable

=cut

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

=head2 next_seq

  Arg [...]  : None
  Description: parse the next sequence entry in the stream
  Returntype : true on success
  Exceptions : if file hasn't been specified either from the
               constructor or by calling the file method
  Caller     : general
  Status     : Stable

=cut

sub next_seq {
  my $self = shift;

  if ( my $fh = $self->_fh ) {
    return $self->_parse;
  } else {
    throw "Can't call 'next_seq' without a 'file' argument";
  }
}

=head2 _parse

  Arg [...]  : None
  Description: abstract method, must be implemented in subclasses
  Returntype : None
  Exceptions : if file hasn't been specified either from the
               constructor or by calling the file method
  Caller     : general
  Status     : Stable

=cut

sub _parse {
  my $self = shift;

  throw "Can't call _parse method on Validator";
}

=head2 _readline

  Arg [...]  : None
  Description: reads a line of input from the stream
  Returntype : String; the line which has been read
  Exceptions : None
  Caller     : Bio::EnsEMBL::Production::Pipeline::Flatfile::Validator::_parse
  Status     : Stable

=cut

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

=head2 _pushback

  Arg [...]  : None
  Description: puts a line previously read with _readline back into a buffer,
               buffer can hold as many lines as system memory permits.
  Returntype : None
  Exceptions : None
  Caller     : Bio::EnsEMBL::Production::Pipeline::Flatfile::Validator::_parse
  Status     : Stable

=cut

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
