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

Bio::EnsEMBL::Production::Pipeline::Flatfile::GenbankValidator

=head1 DESCRIPTION

Implements a validator for Genbank files.

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Flatfile::GenbankValidator;

use strict;
use warnings;
use Readonly;

use base qw(Bio::EnsEMBL::Production::Pipeline::Flatfile::Validator);
use Bio::EnsEMBL::Utils::Exception qw/throw/;

Readonly my $RECORD_SEPARATOR => "//\n";

sub _parse {
  my $self = shift;

  my $line = $self->_readline;
  # This needs to be before the first eof() test
 
  return unless defined $line; # no throws - end of file
 
  if ( $line =~ /^\s+$/ ) {
    while ( defined ($line = $self->_readline) ) {
      $line =~/^\S/ && last;
    }
    # return without error if the whole next sequence was just a single
    # blank line and then eof
    return unless $line;
  }
 
  # no ID as 1st non-blank line, need short circuit and exit routine
  throw "Genbank entry with no ID"
    unless $line =~ /^LOCUS\s+\S+/;
 
  # very simple check of LOCUS line
  #
  # TODO
  # Check validity of various tokens
  #
  throw "Unrecognized format for Genbank LOCUS header line:\n\n$line\n"
    unless $line =~ m/^LOCUS\s{7}\w+\s+(\S+)/;

  my $buffer = $self->_readline;

  local $_;

  my $end_of_entry = 0;

  until ( !defined $buffer ) {
    $_ = $buffer;

    m{^//} and do { $end_of_entry = 1; } and last;

    if (/^DEFINITION/) {
      /^DEFINITION\s{2}\S.*\S/ or
	throw "Invalid definition: $_";

      while ( defined ($_ = $self->_readline) ) {
	/^\S+/ and do { $self->_pushback($_); } and last;
	/\s{12}\S+/ or throw "Invalid definition: $_";
      }
    } elsif (/^ACCESSION/) {
      /^ACCESSION\s{3}\S+/ or throw "Invalid accession line: $_";
    }
    # HERE

    # accession number
    if (/^(AC|PA)/) { 
      if ( /^..\s{3}(.*)?/) {
	my @accs = split(/[; ]+/, $1); # allow space in addition
	throw "Cannot get accession numbers from line: $_" unless @accs;
      } else {
	throw "Invalid AC/PA line: $_";
      }
    } 

    # project identifier
    /^PR\s{3}\S/ or throw "Invalid PR line: $_"
      if /^PR/;
    
    # date
    if (/^DT/) {
      if ( /^DT\s{3}(.+)$/ ) {
	my $line = $1;
	my ($date, $version) = split(' ', $line, 2);
	
	$date =~ tr/,//d; # remove comma if new version
	throw "Invalid date: $_"
	  unless $date =~ /^\d{2}-[A-Z]{3}-\d{4}/;

      } else {
	throw "Invalid date format: $_";
      }
    }
   
    # description line(s)
    /^DE\s{3}\w/ or throw "Invalid DE line: $_"
      if /^DE/;

    # keywords
    /^KW\s{3}\S/ or throw "Invalid KW line: $_"
      if /^KW/;
    
    # organism name and phylogenetic information
    if (/^O[SCG]/) {
      /^O[SCG]\s{3}(.+)/;
      throw "Invalid organism/phylogenetic information on line: $_"
	unless $1;
    }
 
    # references
    /^R[NCPXGATL]\s{3}\S/ or throw "Invalid reference line: $_"
      if /^R/;
 
    # DB Xrefs
    if(/^DR/) {
      if (/^DR\s{3}([^\s;]+);\s*([^\s;]+);?\s*([^\s;]+)?\.$/) {
	throw "Missing database/primary identifier in line: $_"
	  unless $1 and $2;
      } else {
	throw "Invalid cross-reference: $_";
      }
    }
 
    # comments
    /^CC\s{3}\S/ or throw "Invalid comment line: $_"
      if /^CC/;

    $buffer = $self->_readline;
  }
 
  throw "Missing end-of-entry code"
    unless $end_of_entry;

  return 1;
}


1;
