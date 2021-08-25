=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

# Parse RefSeq GPFF files to create xrefs.

package Bio::EnsEMBL::Production::Pipeline::Xrefs::Parser::RefSeqGPFFParser;

use strict;
use warnings;
use Carp;
use File::Basename;

use base qw( Bio::EnsEMBL::Production::Pipeline::Xrefs::Parser::BaseParser);

sub run {

  my ($self, $ref_arg) = @_;
  my $source_id    = $ref_arg->{source_id};
  my $file         = $ref_arg->{file};
  my $release_file = $ref_arg->{rel_file};
  my $dbi          = $ref_arg->{dbi};

  my $xrefs = $self->create_xrefs($file, $dbi, $release_file);
  if ( !defined( $xrefs ) ) {
    return 1;    #error
  }
  $self->upload_xref_object_graphs( $xrefs, $dbi );

}

# --------------------------------------------------------------------------------
# Parse file into array of xref objects
# There are 2 types of RefSeq files that we are interested in:
# - protein sequence files *.protein.gpff
# - mRNA sequence files *.rna.gbff
# Slightly different formats

sub create_xrefs {
  my ($self, $file, $dbi, $release_file) = @_;

  my $peptide_source_id =
    $self->get_source_id_for_source_name('RefSeq_peptide', undef, $dbi);
  my $mrna_source_id =
    $self->get_source_id_for_source_name('RefSeq_mRNA','refseq', $dbi);
  my $ncrna_source_id =
    $self->get_source_id_for_source_name('RefSeq_ncRNA', undef, $dbi);

  my $pred_peptide_source_id =
    $self->get_source_id_for_source_name('RefSeq_peptide_predicted', undef, $dbi);
  my $pred_mrna_source_id =
    $self->get_source_id_for_source_name('RefSeq_mRNA_predicted','refseq', $dbi);
  my $pred_ncrna_source_id =
    $self->get_source_id_for_source_name('RefSeq_ncRNA_predicted', undef, $dbi);

  my $ncbi_source_id = $self->get_source_id_for_source_name('EntrezGene', undef, $dbi);
  my $wiki_source_id = $self->get_source_id_for_source_name('WikiGene', undef, $dbi);

  # Extract version from release file
  if ( defined $release_file ) {
    # Parse and set release info.
    my $release_io = $self->get_filehandle($release_file);
    local $/ = "\n*";
    my $release = $release_io->getline();
    $release_io->close();

    $release =~ s/\s{2,}/ /g;
    $release =~ s/.*(NCBI Reference Sequence.*) Distribution.*/$1/s;
    # Put a comma after the release number to make it more readable.
    $release =~ s/Release (\d+)/Release $1,/;

    $self->set_release( $peptide_source_id,      $release, $dbi );
    $self->set_release( $mrna_source_id,         $release, $dbi );
    $self->set_release( $ncrna_source_id,        $release, $dbi );
    $self->set_release( $pred_mrna_source_id,    $release, $dbi );
    $self->set_release( $pred_ncrna_source_id,   $release, $dbi );
    $self->set_release( $pred_peptide_source_id, $release, $dbi );
  }

  my $refseq_io = $self->get_filehandle($file);

  if ( !defined $refseq_io ) {
    print STDERR "ERROR: Can't open RefSeqGPFF file $file\n";
    return;
  }

  my @xrefs;

  local $/ = "\/\/\n";

  my $type = $self->type_from_file($file);
  return unless $type;

  while ( my $entry = $refseq_io->getline() ) {

    my $xref = $self->xref_from_record(
      $entry, $type,
      $pred_mrna_source_id, $pred_ncrna_source_id,
      $mrna_source_id, $ncrna_source_id,
      $pred_peptide_source_id, $peptide_source_id,
      $ncbi_source_id, $wiki_source_id,
     );

      push @xrefs, $xref if $xref;

  } # while <REFSEQ>

  $refseq_io->close();

  return \@xrefs;

}
sub type_from_file {
  my ($self, $file) = @_;
  return 'peptide' if $file =~ /RefSeq_protein/;
  return 'dna' if $file =~ /rna/;
  return 'peptide' if $file =~ /protein/;
  print STDERR "Could not work out sequence type for $file\n";
  return;
}


sub xref_from_record {
  my ( $self, $entry, $type,
      $pred_mrna_source_id, $pred_ncrna_source_id,
      $mrna_source_id, $ncrna_source_id,
      $pred_peptide_source_id, $peptide_source_id,
      $ncbi_source_id, $wiki_source_id,
  ) = @_;
  chomp $entry;

  my $xref = {};
  my ($acc) = $entry =~ /ACCESSION\s+(\S+)/;
  my ($ver) = $entry =~ /VERSION\s+(\S+)/;
  my ($species_id) = $entry =~ /db_xref=.taxon:(\d+)/;

  # get the right source ID based on $type and whether this is predicted (X*) or not
  my $source_id;
  if ($type =~ /dna/) {
    if ($acc =~ /^XM_/ ){
      $source_id = $pred_mrna_source_id;
    } elsif( $acc =~ /^XR/) {
      $source_id = $pred_ncrna_source_id;
    } elsif( $acc =~ /^NM/) {
      $source_id = $mrna_source_id;
    } elsif( $acc =~ /^NR/) {
      $source_id = $ncrna_source_id;
    }
  } elsif ($type =~ /peptide/) {
    if ($acc =~ /^XP_/) {
      $source_id = $pred_peptide_source_id;
    } else {
      $source_id = $peptide_source_id;
    }
  }

  ( my $acc_no_ver, $ver ) = split( /\./, $ver );

  $xref->{ACCESSION} = $acc;
  if($acc eq $acc_no_ver){
    $xref->{VERSION} = $ver;
  }

  # Description - may be multi-line
  my ($description) = $entry =~ /DEFINITION\s+([^[]+)/s;
  print $entry if (length($description) == 0);
  $description =~ s/\nACCESSION.*//s;
  $description =~ s/\n//g;
  $description =~ s/\s+/ /g;
  $description = substr($description, 0, 255) if (length($description) > 255);

  # Extract sequence
  my ($seq) = $entry =~ /^\s*ORIGIN\s+(.+)/ms; # /s allows . to match newline
  my @seq_lines = split /\n/, $seq;
  my $parsed_seq = "";
  foreach my $x (@seq_lines) {
    my ($seq_only) = $x =~ /^\s*\d+\s+(.*)$/;
    next if (!defined $seq_only);
    $parsed_seq .= $seq_only;
  }
  $parsed_seq =~ s#//##g;    # remove trailing end-of-record character
  $parsed_seq =~ s#\s##g;    # remove whitespace

  # Extract related pair to current RefSeq accession
  # For rna file, the pair is the protein_id
  # For peptide file, the pair is in DBSOURCE REFSEQ accession
  my ($refseq_pair) = $entry =~ /DBSOURCE\s+REFSEQ: accession (\S+)/;
  my @protein_id = $entry =~ /\/protein_id=.(\S+_\d+)/g;
  if (!defined $refseq_pair) {
    foreach my $pi (@protein_id){
      $xref->{PAIR} = $pi;
    }
  } else {
    $xref->{PAIR} = $refseq_pair;
  }

  $xref->{LABEL} = $acc . "\." . $ver;
  $xref->{DESCRIPTION} = $description;
  $xref->{SOURCE_ID} = $source_id;
  $xref->{SEQUENCE} = $parsed_seq;
  $xref->{SEQUENCE_TYPE} = $type;
  $xref->{SPECIES_ID} = $species_id;
  $xref->{INFO_TYPE} = "SEQUENCE_MATCH";

  # Extrat NCBIGene ids
  my @NCBIGeneIDline = $entry =~ /db_xref=.GeneID:(\d+)/g;
  foreach my $ll (@NCBIGeneIDline) {
    my %dep;
    $dep{SOURCE_ID} = $ncbi_source_id;
    $dep{LINKAGE_SOURCE_ID} = $source_id;
    $dep{ACCESSION} = $ll;
    push @{$xref->{DEPENDENT_XREFS}}, \%dep;

    my %dep2;
    $dep2{SOURCE_ID} = $wiki_source_id;
    $dep2{LINKAGE_SOURCE_ID} = $source_id;
    $dep2{ACCESSION} = $ll;
    push @{$xref->{DEPENDENT_XREFS}}, \%dep2;
  }
  return $xref;
}

# --------------------------------------------------------------------------------

1;
