=head1 LICENSE

 Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 Copyright [2016-2022] EMBL-European Bioinformatics Institute

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::AlphaFold::MakeAlphaFoldDBProteinFeatures -

=head1 SYNOPSIS


=head1 DESCRIPTION

This module makes protein features based on the AFDB-UniProt mappings found in
the EMBL-EBI AFDB SIFTS data and the UniProt-ENSP mappings found in the GIFTS
database in order to make the link between AFDB and ENSP having a AFDB entry as
a protein feature for a given ENSP protein.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Production::Pipeline::AlphaFold::MakeAlphaFoldDBProteinFeatures;

use warnings;
use strict;

use parent ('Bio::EnsEMBL::Analysis::Runnable');
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw info);
use Bio::EnsEMBL::GIFTS::DB qw(fetch_latest_uniprot_enst_perfect_matches);
use Bio::EnsEMBL::ProteinFeature;
use JSON;

use open qw( :std :encoding(UTF-8) );

sub new {
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);

    my ($core_dba,$alpha_path,$species,$cs_version,$rest_server) = rearrange([qw(core_dba alpha_path species cs_version rest_server)],@args);

    $self->{'core_dba'} = $core_dba;
    $self->{'alpha_path'} = $alpha_path;
    $self->{'species'} = $species;
    $self->{'cs_version'} = $cs_version;
    $self->{'rest_server'} = $rest_server;

    $self->{'pdb_info'} = undef;
    $self->{'perfect_matches'} = undef;

    return $self;
}


############################################################
#
# Analysis methods
#
############################################################

=head2 run

 Arg [1]    : None
 Description: Parse the AFDB file, fetch the perfect matches between Ensembl ENST transcripts and UniProt proteins from the GIFTS database and make the corresponding protein features which link them.
 Returntype : Integer, 1
 Exceptions : None

=cut

sub run {
    my ($self) = @_;

    info(sprintf("Parsing the afdb_file for species %s\n", $self->{'species'}));
    $self->{'afdb_info'} = $self->parse_afdb_file();
    unless (ref($self->{'afdb_info'}) eq 'ARRAY') {
        die "Missing info from AFDB file. Path: " . $self->{'alpha_path'} . ". Species: " . $self->{'species'} . "\n";
    }

    info(sprintf("Calling GIFTS endpoint for species %s\n", $self->{'species'}));
    $self->{'perfect_matches'} = eval{fetch_latest_uniprot_enst_perfect_matches($self->{'rest_server'}, $self->{'cs_version'})};
    info(sprintf("Done with GIFTS for species %s\n", $self->{'species'}));

    unless (scalar(keys %{$self->{'perfect_matches'}}) > 0) {
        info(sprintf("No data found for species %s in GIFTS DB using endpoint %s and assembly %s. Message:\n%s", $self->{'species'}, $self->{'rest_server'}, $self->{'cs_version'}, $@));
        $self->{'perfect_matches'} = $self->fetch_uniprot_ensembl_matches();
    }

    unless (scalar(keys %{$self->{'perfect_matches'}}) > 0) {
        die(sprintf("No matches for species %s found in core DB %s\n", $self->{'species'}, $self->{'core_dba'}->dbc->dbname()));
    }

    info(sprintf("Making protein features for species %s\n", $self->{'species'}));
    $self->make_protein_features();

    return 1;
}

=head2 fetch_uniprot_ensembl_matches();

 Arg [1]    : None
 Description: Retrieve Ensembl/UniProt matches from the core database
 Returntype : Hash for UniProt/Ensembl matches
 Exceptions : None

=cut

sub fetch_uniprot_ensembl_matches {
  my ($self) = @_;

  my %perfect_matches;
  my $dbentry_adaptor = $self->{'core_dba'}->get_DBEntryAdaptor();
  my $transcript_adaptor = $self->{'core_dba'}->get_TranscriptAdaptor();
  my $source = "UniProt%";
  my $uniprots = $dbentry_adaptor->fetch_all_by_source($source);
  my %uniprot_accessions; # there are some duplicated entries in the xref table, ignore
  foreach my $uniprot (@$uniprots) {
    next unless $uniprot->info_type eq 'DEPENDENT'; # For arabidopsis, dependent UniProt xrefs are mapped through UniParc checksum guaranteeing 100% identity
    next if defined $uniprot_accessions{$uniprot->primary_id};
    my $transcripts = $transcript_adaptor->fetch_all_by_external_name($uniprot->primary_id, $source);
    foreach my $transcript (@$transcripts) {
      push(@{$perfect_matches{$uniprot->primary_id}}, $transcript->stable_id);
    }
    $uniprot_accessions{$uniprot->primary_id} = 1;
  }

  return \%perfect_matches;
}


=head2 parse_pdb_file

 Arg [1]    : None
 Description: Parse the CSV AFDB file containing the following 9 columns:
                AFDB XXXX CHAIN RES_BEG RES_END UNP SP_PRIMARY SP_DESC PDB_BEG PDB_END
              It skips the entry if the start of the protein is greater than the end as we cannot display it correctly.
 Returntype : Arrayref of hashref, SP_PRIMARY, AFDB, CHAIN, RES_BEG, RES_END, SP_BEG, SP_END and SIFTS_RELEASE_DATE as keys
 Exceptions : Throws if it cannot open the file
              Throws if it cannot close the AFDB file

=cut

sub parse_afdb_file {
  my $self = shift;

  my $alpha_data;
  {
      open(my $fh, '<', $self->{'alpha_path'}) || throw('Cannot open: '.$self->{'alpha_path'});
      local $/ = undef;
      $alpha_data = <$fh>;
      close $fh;
  }
  my $afdb_info = decode_json($alpha_data);

  return $afdb_info;
}


=head2 make_protein_features

 Arg [1]    : None
 Description: Create the protein features by linking the ENSP proteins and the PDB entries
              from 'perfect_matches' and 'afdb_info'. It stores an hash: key is translation
              id and value is the Bio::EnsEMBL::ProteinFeature object, into $self->output
 Returntype : None
 Exceptions : None

=cut

sub make_protein_features() {
  my $self= shift;

  my @pfs = ();

  # loop through all afdb lines and find the corresponding ENSTs (if any)
  # in the perfect matches hash,
  # fetch their proteins and add their protein features
  my $ta = $self->{'core_dba'}->get_TranscriptAdaptor();
  my $analysis = $self->analysis;

  foreach my $afdb_line (@{$self->{'afdb_info'}}) {
    my $afdb_uniprot = $$afdb_line{'SP_PRIMARY'};

    if (defined($self->{'perfect_matches'}{$afdb_uniprot})) {
      my @ensts = @{$self->{'perfect_matches'}{$afdb_uniprot}};
      #if (scalar(@ensts) > 0) {
      foreach my $enst (@ensts) {

        my %pf_translation;
        my $t = $ta->fetch_by_stable_id($enst);

        if ($t and $t->translation and $t->translation->length >= $$afdb_line{SP_END}) {
          my $translation = $t->translation();
          my $translation_sid = $translation->stable_id();

          $$afdb_line{'SIFTS_RELEASE_DATE'} //= '';

          my $pf = Bio::EnsEMBL::ProteinFeature->new(
                  -start    => $$afdb_line{'SP_BEG'},
                  -end      => $$afdb_line{'SP_END'},
                  -hseqname => $$afdb_line{'AFDB'}.".".$$afdb_line{'CHAIN'},
                  -hstart   => $$afdb_line{'RES_BEG'},
                  -hend     => $$afdb_line{'RES_END'},
                  -analysis => $analysis,
                  -hdescription => "Via SIFTS (".$$afdb_line{'SIFTS_RELEASE_DATE'}.
                                   ") UniProt protein ".$$afdb_line{'SP_PRIMARY'}.
                                   " isoform exact match to Ensembl protein $translation_sid"
               );
            $pf_translation{$translation->dbID()} = $pf;
            push(@pfs,\%pf_translation);
        } # if t
      } # foreach my enst
      #} # if scalar
    } # if ensts
  } # foreach my afdb_line

  $self->output(\@pfs);
}

1;
