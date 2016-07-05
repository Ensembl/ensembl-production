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

Bio::EnsEMBL::Production::Pipeline::Flatfile::GenbankValidator

=head1 DESCRIPTION

Implements a validator for Genbank files.
Code is inspired by the BioPerl Genbank parser, see Bio::SeqIO::genbank 
from the BioPerl distribution.

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Flatfile::GenbankValidator;

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
  throw "Genbank entry with no ID"
    unless $line =~ /^LOCUS\s+\S+/;
 
  # very simple check of LOCUS line
  #
  # TODO
  # Check validity of various tokens
  #
  throw "Unrecognized format for Genbank LOCUS header line:\n\n$line\n"
    unless $line =~ m/^LOCUS\s{7}[\w.]+\s+(\S+)/;

  my $buffer = $self->_readline;

  local $_;

  my $end_of_entry = 0;

  until ( !defined $buffer ) {
    $_ = $buffer;

    m{^//} and do { $end_of_entry = 1; } and last;

    # definition|accession|keyword|comment entry
    if (/^(DEFINITION)|^(ACCESSION)|^(KEYWORDS)|^(COMMENT)/) {
      my $code = $1;
      /^DEFINITION\s{2}\S.*?|^ACCESSION\s{3}\S+|^KEYWORDS\s{4}\S+|^COMMENT\s{5}\S+/ or
	throw "Invalid line: $_";

      while ( defined ($_ = $self->_readline) ) {
	/^\S+/ and do { $self->_pushback($_); } and last;
	/^\s{12}\S+/ or throw "Invalid $code line: $_";
      }
    } elsif (/^PID/) { # PID
      /^PID\s{9}\S+/ or throw "Invalid version line: $_"
    } elsif (/^VERSION/) { # version number
      /^VERSION\s{5}\S+/ or throw "Invalid version line: $_";
    } elsif (/^SOURCE/) { # organism name(s) and phylogenetic information
      /^SOURCE\s{6}\S+/ or throw "Invalid source line: $_";
      
      while ( defined ($_ = $self->_readline) ) {
	/^\S+/ and do { $self->_pushback($_); } and last;
	/^\s{12}\S+|^\s{2}(?:CLASSIFICATION|ORGANISM)\s+\S+/ 
	  or throw "Invalid SOURCE line: $_";
      }
    } elsif (/^REFERENCE/) { # reference entry
      /^REFERENCE\s{3}\d+\s+\S/ or throw "Invalid reference line: $_";

      while ( defined ($_ = $self->_readline) ) {
	/^\S+/ and do { $self->_pushback($_); } and last;
	/^\s{12}\S+|^\s{2}(?:AUTHORS|CONSRTM|TITLE|JOURNAL|REMARK|MEDLINE|PUBMED)\s+\S+/ 
	  or throw "Invalid reference line: $_";
      }
    } elsif (/^PROJECT/) { # project entry
      /^PROJECT\s{5}\S+/ or throw "Invalid project line: $_"
    } elsif (/^DB/) { # DB xrefs
      /^DB(?:SOURCE|LINK)\s+\S.+/ or throw "Invalid xref line: $_";

      # advance until next entry
      while ( defined ($_ = $self->_readline) ) {
	/^\S+/ and do { $self->_pushback($_); } and last;
      }
    } elsif (/^FEATURES/) { # features
      /^FEATURES\s+\S+/ or throw "Invalid feature line: $_";
      
      while ( defined ($_ = $self->_readline) ) {
	/^\S+/ and do { $self->_pushback($_); } and last;
	/^(\s{5}\S+\s+)\S+|^(\s{21})\S+/ 
	  or throw "Invalid feature line: $_";
	# defined $1 and length($1) == 21 or throw sprintf "Invalid feature line: %s ** %s **", $_, $1;
      } 
    } elsif (/^BASE/) { # sequence
      /^BASE COUNT\s+\d+\s[acgt]\s+\d+\s[acgt]\s+\d+\s[acgt]\s+\d+\s[acgt]/ or
	throw "Invalid base count line: $_";

      $_ = $self->_readline;
      /^ORIGIN$/ or throw "No sequence header after base count: $_";

      while ( defined ($_ = $self->_readline) ) {
	m{^//} and do { $self->_pushback($_); } and last;
	# check the sequence
	#
	# WARNING
	# this would also match when we have less characters in a complete
	# line (6 groups of letters) as the second option would match
	#
	# TODO
	# find out how to exclude this case
	#
	/^\s*?\d+\s([ACGTN]{10}\s){6}\s*?$|^\s*?\d+\s([ACGTN]+\s)+\s*$/i or
	# /^\s*?\d+\s([ACGTN]{10}\s){0,6}([ACGTN]+\s)*\s*?$/i or
	  throw "Invalid sequence line:\n\n$_";
      }
    } else {
      throw "Unrecognised code in line: $_";
    }
    #
    # TODO
    # check for CONTIG|WGS
    #

    $buffer = $self->_readline;
  }
 

  throw "Missing end-of-entry code"
    unless $end_of_entry;

  return 1;
}


1;
