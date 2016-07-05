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

Bio::EnsEMBL::Production::Pipeline::Flatfile::EMBLValidator

=head1 DESCRIPTION

Implements a validator for EMBL files.
Code is inspired by the BioPerl EMBL parser, see Bio::SeqIO::embl
from the BioPerl distribution.

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Flatfile::EMBLValidator;

use strict;
use warnings;
use Readonly;

use base qw(Bio::EnsEMBL::Production::Pipeline::Flatfile::Validator);
use Bio::EnsEMBL::Utils::Exception qw/throw/;

Readonly my $RECORD_SEPARATOR => "//\n";

=head2 _parse

  Arg [...]  : None
  Description: parse and validate a sequence entry from the stream
  Returntype : true on success
  Exceptions : if any error is detected during validation
  Caller     : Bio::EnsEMBL::Production::Pipeline::Flatfile::Validator::next_seq
  Status     : Stable

=cut

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
  throw "EMBL entry with no ID"
    unless $line =~ /^ID\s+\S+/;
 
  throw "Unrecognized format for EMBL ID header line:\n\n$line\n"
    unless $line =~ 
      m/^ID\s{3}(\w+);\s+SV (\d+); (\w+); ([^;]+); (\w{3}); (\w{3}); (\d+) BP.|^ID\s{3}(\S+)[^;]*;\s+(\S+)[^;]*;\s+(\S+)[^;]*;/;
  my ($name, $sv, $topology, $mol, $div) = ($1, $2, $3, $4, $6);
  # TODO
  # check the above attributes
 
  my $buffer = $self->_readline;

  local $_;

  my $end_of_entry = 0;

  until ( !defined $buffer ) {
    $_ = $buffer;

    m{^//} and do { $end_of_entry = 1; } and last;

    /^(AC|PR|D[TER]|KW|O[SCG]|R[NCPXGATL]|CC|A[HS]|F[HT]|XX|S[QV]|CO)/
      or throw "Unrecognized code in line: $_";

    if (/^SQ/) {
      /^SQ\s{3}Sequence\s+\d+\sBP;\s+\d+\s[ACGT];\s+\d+\s[ACGT];\s+\d+\s[ACGT];\s+\d+\s[ACGT];/
	or throw "Invalid format for sequence header: $_";

      while ( defined ($_ = $self->_readline) ) {
	m{^//} and do { $self->_pushback($_); } and last;
	# check the sequence
	/^\s{5}([ACGTN]{10}\s){6}\s*\d+?$|^\s{5}([ACGTN]+\s)+\s+\d+?$/ or
	  throw "Invalid sequence line:\n\n$_";
      }
    }

    /^FT\s{3}(\S+)\s+(\S+)|^FT\s{19}\S+/ or throw "Invalid feature line: $_"
      if /^FT/;

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
	  unless $date =~ /^\d+-[A-Z]{3}-\d{4}/;

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
