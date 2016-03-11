use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::OntologyXref;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBSQL::OntologyDBAdaptor;
use Getopt::Long;
use Bio::EnsEMBL::Utils::IO qw/gz_work_with_file work_with_file/;

my $user = 'ensro';
my $pass = '';
my $port = 3306;
my $file;
my $version = '82';

&GetOptions(
  'dbuser:s'   => \$user,
  'dbpass:s'   => \$pass,
  'dbport:n'   => \$port,
  'file:s'     => \$file
);

my $registry = "Bio::EnsEMBL::Registry";

$registry->load_registry_from_multiple_dbs(
  {
    -host => 'ens-staging1',
    -user => $user,
    -pass => $pass,
    -port => $port,
    -db_version => $version
  },
  {
    -host => 'ens-staging2',
    -user => $user,
    -pass => $pass,
    -port => $port,
    -db_version => $version
  },
  {
    -host => 'mysql-eg-publicsql.ebi.ac.uk',
    -user => $user,
    -pass => $pass,
    -port => '4157',
    -db_version => $version
  },
);

open ( GPAD, $file ) || die " cant read $file \n" ;


my $tl_adaptor;
my $dbe_adaptor;
my $t_adaptor;
my %adaptor_hash;
my %dbe_adaptor_hash;
my %t_adaptor_hash;
my $translation;
my $translations;
my %translation_hash;
my %species_missed;
my %species_added;
my %species_added_via_xref;
my %species_added_via_tgt;
my %ontology_definition;

my $odba = $registry->get_adaptor('multi', 'ontology', 'OntologyTerm');
my $gos = $odba->fetch_all();

foreach my $go (@$gos) {
  $ontology_definition{$go->accession} = $go->name();
}

while (my $line = <GPAD> ) {

# Skip header
  if ($line=~/^!/){
        next;
  }

  my ( $db, $db_object_id, $qualifier, $go_id, $go_ref, $eco, $with, $taxon_id, $date, $assigned_by, $annotation_extension, $annotation_properties) = split /\t/,$line ;

  # Parse annotation information
  # $go_evidence and $tgt_species should always be populated
  # The remaining fields might or might not, but they should alwyays be available in that order
  my ($go_evidence, $tgt_species, $tgt_gene, $tgt_feature, $src_species, $src_gene, $src_protein) = split /\|/, $annotation_properties;
  my ($tgt_protein, $tgt_transcript);
  $tgt_gene =~ s/tgt_gene=\w+:// if $tgt_gene;
  $tgt_species =~ s/tgt_species=// if $tgt_species;
  $go_evidence =~ s/go_evidence=// if $go_evidence;
  # If the tgt_feature field is populated, it could be tgt_protein or tgt_transcript
  if (defined $tgt_feature) {
    if ($tgt_feature =~ /tgt_protein/) {
      $tgt_feature =~ s/tgt_protein=\w+://;
      $tgt_protein = $tgt_feature;
    } elsif ($tgt_feature =~ /tgt_transcript/) {
      $tgt_feature =~ s/tgt_transcript=//;
      $tgt_transcript = $tgt_feature;
    } else {
      print STDERR "Error parsing $annotation_properties, no match for $tgt_feature\n";
    }
  }
  if ($adaptor_hash{$tgt_species}) {
    # If the file lists a species not in the current registry, skip it
    if ($adaptor_hash{$tgt_species} eq 'undefined') {
      print STDERR "Could not find $tgt_species in registry\n";
      next;
    }
    $tl_adaptor = $adaptor_hash{$tgt_species};
    $dbe_adaptor = $dbe_adaptor_hash{$tgt_species};
    $t_adaptor = $t_adaptor_hash{$tgt_species};
  } else {
    if (!$registry->get_alias($tgt_species)) { 
      $adaptor_hash{$tgt_species} = 'undefined';
      next; 
    }
    $tl_adaptor = $registry->get_adaptor($tgt_species, 'core', 'Translation');
    $dbe_adaptor = $registry->get_adaptor($tgt_species, 'core', 'DBEntry');
    $t_adaptor = $registry->get_adaptor($tgt_species, 'core', 'Transcript');
    $adaptor_hash{$tgt_species} = $tl_adaptor;
    $dbe_adaptor_hash{$tgt_species} = $dbe_adaptor;
    $t_adaptor_hash{$tgt_species} = $t_adaptor;
  }
  my $info_type = 'DEPENDENT';
  if ($src_species) { $info_type = 'PROJECTION' ; }

  # Create new Xref
  my $go_xref = Bio::EnsEMBL::OntologyXref->new(
    -primary_id  => $go_id,
    -display_id  => $go_id,
    -info_text   => $go_ref,
    -info_type   => $info_type,
    -description => $ontology_definition{$go_id},
    -linkage_annotation => $go_evidence,
    -dbname      => 'GO'
  );

  # There could technically be more than one xref with the same display_label
  # In practice, we just want to add it as master_xref, so the first one is fine
  my $uniprot_xrefs = $dbe_adaptor->fetch_all_by_name($db_object_id);
  $go_xref->add_linkage_type($go_evidence, $uniprot_xrefs->[0]);

  # If GOA did not provide a tgt_feature, we have to guess the correct target based on our xrefs
  # This is slower, hence only used if nothing better is available
  if (!defined $tgt_feature) {
    $translations = $tl_adaptor->fetch_all_by_external_name($db_object_id);
    foreach my $translation (@$translations) {
      $dbe_adaptor->store($go_xref, $translation->dbID, 'Translation', 1, $uniprot_xrefs->[0]);
      $species_added_via_xref{$tgt_species}++;
    }
  # If GOA provide a tgt_protein, this is the direct mapping to Ensembl feature
  # This becomes our object for the new xref
  } elsif (defined $tgt_protein) {
    if ($translation_hash{$tgt_protein}) {
      $translation = $translation_hash{$tgt_protein};
    } else {
      $translation = $tl_adaptor->fetch_by_stable_id($tgt_protein);
      $translation_hash{$tgt_protein} = $translation;
    }
    if (defined $translation) {
      $dbe_adaptor->store($go_xref, $translation->dbID, 'Translation', 1, $uniprot_xrefs->[0]);
      $species_added_via_tgt{$tgt_species}++;
    } else {
      $species_missed{$tgt_species}++;
    }
  # If GOA provide a tgt_transcript, it could be a list of transcript mappings
  # We still need to fetch the translation as GOs are linked on protein level
  } elsif (defined $tgt_transcript) {
    my @tgt_transcripts = split(",", $tgt_transcript);
    foreach my $transcript (@tgt_transcripts) {
      if ($translation_hash{$transcript}) {
        $translation = $translation_hash{$transcript};
      } else {
        my $translation_transcript = $t_adaptor->fetch_by_stable_id($transcript);
        $translation = $tl_adaptor->fetch_by_Transcript($translation_transcript);
      }
      if (defined $translation) {
        $dbe_adaptor->store($go_xref, $translation->dbID, 'Translation', 1, $uniprot_xrefs->[0]);
        $species_added_via_tgt{$tgt_species}++;
      } else {
        $species_missed{$tgt_species}++;
      }
    }
  }
}

# Summary of data added
# If the data is up-to-date, nothing should be missed and via_xref additions should be low
foreach my $key (keys %adaptor_hash) {
  print "Stored " . $species_added_via_xref{$key} . " xref entries, " . $species_added_via_tgt{$key} . " tgt entries and missed " . $species_missed{$key} . " for $key\n";
}



