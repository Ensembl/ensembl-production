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

# Parse UniProt (SwissProt & SPTrEMBL) files to create xrefs.
#
# Files actually contain both types of xref, distinguished by ID line;
#
# ID   CYC_PIG                 Reviewed;         104 AA.  Swissprot
# ID   Q3ASY8_CHLCH            Unreviewed;     36805 AA.  SPTrEMBL



package Bio::EnsEMBL::Production::Pipeline::Xrefs::Parser::UniProtParser;

use strict;
use warnings;
use Carp;
use POSIX qw(strftime);
use File::Basename;

use base qw (Bio::EnsEMBL::Production::Pipeline::Xrefs::Parser::BaseParser);;



sub run {

  my ($self, $ref_arg) = @_;
  my $source_id    = $ref_arg->{source_id};
  my $file         = $ref_arg->{file};
  my $release_file = $ref_arg->{rel_file};
  my $dbi          = $ref_arg->{dbi};

  $self->create_xrefs( $file, $dbi, $release_file);

  return 0; # successfull
}


# --------------------------------------------------------------------------------
# Parse file into array of xref objects

sub create_xrefs {
  my ($self, $file, $dbi, $release_file) = @_;

  my $sp_source_id =
    $self->get_source_id_for_source_name('Uniprot/SWISSPROT','sequence_mapped', $dbi);
  my $sptr_source_id =
    $self->get_source_id_for_source_name('Uniprot/SPTREMBL', 'sequence_mapped', $dbi);

  my $sptr_non_display_source_id =
    $self->get_source_id_for_source_name('Uniprot/SPTREMBL', 'protein_evidence_gt_2', $dbi);

  my $sp_direct_source_id = $self->get_source_id_for_source_name('Uniprot/SWISSPROT', 'direct', $dbi);
  my $sptr_direct_source_id = $self->get_source_id_for_source_name('Uniprot/SPTREMBL', 'direct', $dbi);

  my $isoform_source_id = $self->get_source_id_for_source_name('Uniprot_isoform', undef, $dbi);

  if ( defined $release_file ) {
    my ($sp_release, $sptr_release);
    # Parse Swiss-Prot and SpTrEMBL release info from
    # $release_file.
    my $release_io = $self->get_filehandle($release_file);
    while ( defined( my $line = $release_io->getline() ) ) {
      if ( $line =~ m#(UniProtKB/Swiss-Prot Release .*)# ) {
        $sp_release = $1;
      } elsif ( $line =~ m#(UniProtKB/TrEMBL Release .*)# ) {
        $sptr_release = $1;
      }
    }
    $release_io->close();

    # Set releases
    $self->set_release( $sp_source_id,        $sp_release, $dbi );
    $self->set_release( $sptr_source_id,      $sptr_release, $dbi );
    $self->set_release( $sptr_non_display_source_id, $sptr_release, $dbi );
    $self->set_release( $sp_direct_source_id, $sp_release, $dbi );
    $self->set_release( $sptr_direct_source_id,$sptr_release, $dbi );
  }

  my %dependent_sources = $self->get_xref_sources($dbi);

  my $uniprot_io = $self->get_filehandle($file);
  if ( !defined $uniprot_io ) { 
    print STDERR "ERROR: Can't open UniProt file $file\n";
    return;
  }

  my @xrefs;

  local $/ = "//\n";

  # Counter to process file in batches
  my $count = 0;

  while ( $_ = $uniprot_io->getline() ) {

    my $xref;
    my ($species_id) = $_ =~ /OX\s+[a-zA-Z_]+=([0-9 ,]+).*;/;

    # set accession (and synonyms if more than one)
    # AC line may have primary accession and possibly several ; separated synonyms
    # May also be more than one AC line
    my ($acc) = $_ =~ /(\nAC\s+.+)/s; # will match first AC line and everything else

    my @all_lines = split /\n/, $acc;

    # Check for CC (caution) lines containing certain text
    # If sequence is from Ensembl, do not use
    my $ensembl_derived_protein = 0;
    if ($_ =~ /CAUTION: The sequence shown here is derived from an Ensembl/) {
      $ensembl_derived_protein = 1;
    }

    # extract ^AC lines only & build list of accessions
    my @accessions;
    foreach my $line (@all_lines) {
      my ($accessions_only) = $line =~ /^AC\s+(.+)/;
      push(@accessions, (split /;\s*/, $accessions_only)) if ($accessions_only);

    }

    if(lc($accessions[0]) eq "unreviewed"){
      print "WARNING: entries with accession of $acc not allowed will be skipped\n";
      next;
    }
    $xref->{INFO_TYPE} = "SEQUENCE_MATCH";
    $xref->{ACCESSION} = $accessions[0];
    for (my $a=1; $a <= $#accessions; $a++) {
      push(@{$xref->{"SYNONYMS"} }, $accessions[$a]);
    }

    my ($label, $sp_type) = $_ =~ /ID\s+(\w+)\s+(\w+)/;
    my ($protein_evidence_code) = $_ =~ /PE\s+(\d+)/; 
    # Capture line with entry version
    # Example: DT   22-APR-2020, entry version 1.
    my ($version) = $_ =~ /DT\s+\d+-\w+-\d+, entry version (\d+)/;

    # SwissProt/SPTrEMBL are differentiated by having STANDARD/PRELIMINARY here
    if ($sp_type =~ /^Reviewed/i) {
      $xref->{SOURCE_ID} = $sp_source_id;
    } elsif ($sp_type =~ /Unreviewed/i) {

    #Use normal source only if it is PE levels 1 & 2
      if (defined($protein_evidence_code) && $protein_evidence_code < 3) {
          $xref->{SOURCE_ID} = $sptr_source_id;
      } else {
          $xref->{SOURCE_ID} = $sptr_non_display_source_id;
      }
    } else {
      next; # ignore if it's neither one nor t'other
    }

    # some straightforward fields
    # the previous $label flag of type BRCA2_HUMAN is not used in Uniprot any more, use accession instead
    $xref->{LABEL} = $accessions[0] ."." . $version;
    $xref->{VERSION} = $version;
    $xref->{SPECIES_ID} = $species_id;
    $xref->{SEQUENCE_TYPE} = 'peptide';
    $xref->{STATUS} = 'experimental';
    print "Created xref for species $species_id with " . $xref->{ACCESSION} . "\n";

    # May have multi-line descriptions
    my ($description_and_rest) = $_ =~ /(DE\s+.*)/s;
    @all_lines = split /\n/, $description_and_rest;

    # extract ^DE lines only & build cumulative description string
    my $description = "";
    my $name        = "";
    my $sub_description = "";

    foreach my $line (@all_lines) {

      next if(!($line =~ /^DE/));

      # get the data
      if($line =~ /^DE   RecName: Full=(.*);/){
        $name .= '; ' if $name ne q{}; #separate multiple sub-names with a '; '
        $name .= $1;
      }
      elsif($line =~ /RecName: Full=(.*);/){
        $description .= ' ' if $description ne q{}; #separate the description bit with just a space
        $description .= $1;
      }
      elsif($line =~ /SubName: Full=(.*);/){
        $name .= '; ' if $name ne q{}; #separate multiple sub-names with a '; '
        $name .= $1;
      }


      $description =~ s/^\s*//g;
      $description =~ s/\s*$//g;

      
      my $desc = $name.' '.$description;
      if(!length($desc)){
        $desc = $sub_description;
      }
      
      $desc =~ s/\s*\{ECO:.*?\}//g;
      $xref->{DESCRIPTION} = $desc;

      # Parse the EC_NUMBER line, only for S.cerevisiae for now
      
      if (($line =~ /EC=/) && ($species_id == 4932)) {

          $line =~ /^DE\s+EC=([^;]+);/;
          # Get the EC Number and make it an xref for S.cer if any
          my $EC = $1;
          
          my %depe;
          $depe{LABEL} = $EC;
          $depe{ACCESSION} = $EC;
          $depe{SOURCE_NAME} = "EC_NUMBER";
          $depe{SOURCE_ID} = $dependent_sources{"EC_NUMBER"};
          $depe{LINKAGE_SOURCE_ID} = $xref->{SOURCE_ID};
          push @{$xref->{DEPENDENT_XREFS}}, \%depe;
      }
    }

    # extract sequence
    my ($seq) = $_ =~ /SQ\s+(.+)/s; # /s allows . to match newline
      my @seq_lines = split /\n/, $seq;
    my $parsed_seq = "";
    foreach my $x (@seq_lines) {
      $parsed_seq .= $x;
    }
    $parsed_seq =~ s/\/\///g;   # remove trailing end-of-record character
    $parsed_seq =~ s/\s//g;     # remove whitespace
    $parsed_seq =~ s/^.*;//g;   # remove everything before last ;
    $xref->{SEQUENCE} = $parsed_seq;

    my ($gns) = $_ =~ /(GN\s+.+)/s;
    my @gn_lines = ();
    if ( defined $gns ) { @gn_lines = split /;/, $gns }
  
    # Do not allow the addition of UniProt Gene Name dependent Xrefs
    # if the protein was imported from Ensembl. Otherwise we will
    # re-import previously set symbols
    if(! $ensembl_derived_protein) {
      my %depe;
      foreach my $gn (@gn_lines){
        # Make sure these are still lines with Name or Synonyms
        if (($gn !~ /^GN/ || $gn !~ /Name=/) && $gn !~ /Synonyms=/) { last; }

        if ($gn =~ / Name=([A-Za-z0-9_\-\.\s]+)/s) { #/s for multi-line entries ; is the delimiter
          # Example line 
          # GN   Name=ctrc {ECO:0000313|Xenbase:XB-GENE-5790348};
          my $name = $1;
          $name =~ s/\s+$//g; # Remove white spaces that are left over at the end if there was an evidence code
          $depe{LABEL} = $name; # leave name as is, upper/lower case is relevant in gene names
          $depe{ACCESSION} = $xref->{ACCESSION};

          $depe{SOURCE_NAME} = "Uniprot_gn";
          $depe{SOURCE_ID} = $dependent_sources{"Uniprot_gn"};
          $depe{LINKAGE_SOURCE_ID} = $xref->{SOURCE_ID};
          push @{$xref->{DEPENDENT_XREFS}}, \%depe;
        }
        my @syn;
        if($gn =~ /Synonyms=(.*)/s){ # use of /s as synonyms can be across more than one line
          # Example line
          # GN   Synonyms=cela2a {ECO:0000313|Ensembl:ENSXETP00000014934},
          # GN   MGC79767 {ECO:0000313|EMBL:AAH80976.1}
          my $syn = $1;
          $syn =~ s/{.*}//g;  # Remove any potential evidence codes
          $syn =~ s/\n//g;    # Remove return carriages, as entry can span several lines
          $syn =~ s/\s+$//g;  # Remove white spaces that are left over at the end if there was an evidence code
          #$syn =~ s/^\s+//g;  # Remove white spaces that are left over at the beginning if there was an evidence code
          $syn =~ s/\s+,/,/g;  # Remove white spaces that are left over before the comma if there was an evidence code
          @syn = split(/, /,$syn);
          push (@{$depe{"SYNONYMS"}}, @syn);
        }
      }
    }

    # dependent xrefs - only store those that are from sources listed in the source table
    my ($deps) = $_ =~ /(DR\s+.+)/s; # /s allows . to match newline

    my @dep_lines = ();
    if ( defined $deps ) { @dep_lines = split /\n/, $deps }

    my %seen=();  # per record basis

    foreach my $dep (@dep_lines) {
      #Skipp external sources obtained through other files
      if ($dep =~ /GO/ || $dep =~ /UniGene/ || $dep =~ /RGD/ || $dep =~ /CCDS/ || $dep =~ /IPI/ || $dep =~ /UCSC/ ||
              $dep =~ /SGD/ || $dep =~ /HGNC/ || $dep =~ /MGI/ || $dep =~ /VGNC/ || $dep =~ /Orphanet/ || $dep =~ /ArrayExpress/ ||
              $dep =~ /GenomeRNAi/ || $dep =~ /EPD/ || $dep =~ /Xenbase/ || $dep =~ /Reactome/ || $dep =~ /MIM/) { next; }
      if ($dep =~ /^DR\s+(.+)/) {
        my ($source, $acc, @extra) = split /;\s*/, $1;
        # If mapped to Ensembl, add as direct xref
        if ($source eq "Ensembl") {
          # Example line:
          # DR   Ensembl; ENST00000380152; ENSP00000369497; ENSG00000139618.
          # DR   Ensembl; ENST00000372839; ENSP00000361930; ENSG00000166913. [P31946-1]
          # $source is Ensembl, $acc is ENST00000380152 and @extra is the rest of the line
          # If the UniProt accession is repeated here, it links to a specific isoform
          my %direct;
          my $isoform;
          $direct{STABLE_ID} = $extra[0];
          $direct{ENSEMBL_TYPE} = 'Translation';
          $direct{LINKAGE_TYPE} = 'DIRECT';
          if ($xref->{SOURCE_ID} == $sp_source_id) {
            $direct{SOURCE_ID} = $sp_direct_source_id;
          } else {
            $direct{SOURCE_ID} = $sptr_direct_source_id;
          }
          push @{$xref->{DIRECT_XREFS}}, \%direct;

          my $uniprot_acc = $accessions[0];
          if ($extra[1] =~ /($accessions[0]-[0-9]+)/) {
            $isoform = $1;
            $self->add_to_direct_xrefs({
              stable_id  => $extra[0],
              type       => 'translation',
              acc        => $isoform,
              label      => $isoform,
              dbi        => $dbi,
              source_id  => $isoform_source_id,
              linkage    => 'DIRECT',
              species_id => $species_id
            });
          }
        }
        if (exists $dependent_sources{$source} ) {
          # create dependent xref structure & store it
          my %dep;
          $dep{SOURCE_NAME} = $source;
          $dep{LINKAGE_SOURCE_ID} = $xref->{SOURCE_ID};
          $dep{SOURCE_ID} = $dependent_sources{$source};
          $dep{ACCESSION} = $acc;
          if(!defined($seen{$dep{SOURCE_NAME}.":".$dep{ACCESSION}})){
            push @{$xref->{DEPENDENT_XREFS}}, \%dep; # array of hashrefs
            $seen{$dep{SOURCE_NAME}.":".$dep{ACCESSION}} =1;
          }
          if($dep =~ /EMBL/ && !($dep =~ /ChEMBL/)){
            my ($protein_id) = $extra[0];
            if(($protein_id ne "-") and (!defined($seen{$source.":".$protein_id}))){
              my %dep2;
              $dep2{SOURCE_NAME} = $source;
              $dep2{SOURCE_ID} = $dependent_sources{"protein_id"};
              $dep2{LINKAGE_SOURCE_ID} = $xref->{SOURCE_ID};
              # store accession unversioned
              $dep2{LABEL} = $protein_id;
              my ($prot_acc, $prot_version) = $protein_id =~ /([^.]+)\.([^.]+)/;
              $dep2{ACCESSION} = $prot_acc;
              $seen{$source.":".$protein_id} = 1;
              push @{$xref->{DEPENDENT_XREFS}}, \%dep2; # array of hashrefs
            }
          }
        }
      }
    }

    push @xrefs, $xref;
    $count++;

    if ($count > 1000) {
      $self->upload_xref_object_graphs(\@xrefs, $dbi);
      $count = 0;
      undef @xrefs;
    }

  }

  $self->upload_xref_object_graphs(\@xrefs, $dbi) if scalar(@xrefs) > 0;

  $uniprot_io->close();

}

1;
