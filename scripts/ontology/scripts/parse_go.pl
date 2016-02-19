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
my %adaptor_hash;
my %dbe_adaptor_hash;
my $translation;
my %translation_hash;
my %species_missed;
my %species_added;
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
  my ($tgt_species, $tgt_gene, $tgt_protein, $src_species, $src_gene, $src_protein) = split /\|/, $annotation_properties;
  $tgt_gene =~ s/tgt_gene=\w+:// if $tgt_gene;
  $tgt_protein =~ s/tgt_protein=\w+:// if $tgt_protein;
  $tgt_species =~ s/tgt_species=//;
  if ($tgt_species ne 'bos_taurus') { next; }
  if ($adaptor_hash{$tgt_species}) {
    if ($adaptor_hash{$tgt_species} eq 'undefined') { next; }
    $tl_adaptor = $adaptor_hash{$tgt_species};
  } else {
    if (!$registry->get_alias($tgt_species)) { 
      $adaptor_hash{$tgt_species} = 'undefined';
      next; 
    }
    $tl_adaptor = $registry->get_adaptor($tgt_species, 'core', 'Translation');
    $dbe_adaptor = $registry->get_adaptor($tgt_species, 'core', 'DBEntry');
    $adaptor_hash{$tgt_species} = $tl_adaptor;
    $dbe_adaptor_hash{$tgt_species} = $dbe_adaptor;
  }

  if ($translation_hash{$tgt_protein}) {
    $translation = $translation_hash{$tgt_protein};
  } else {
    $translation = $tl_adaptor->fetch_by_stable_id($tgt_protein);
    $translation_hash{$tgt_protein} = $translation
  }

  my $go_xref = Bio::EnsEMBL::OntologyXref->new(
    -primary_id  => $go_id,
    -display_id  => $go_id,
    -info_text   => $go_ref,
    -info_type   => 'DEPENDENT',
    -description => $ontology_definition{$go_id},
    -linkage_annotation => $eco,
    -dbname      => 'GO'
  );

  my $uniprot_xrefs = $dbe_adaptor->fetch_all_by_name($db_object_id);
  $go_xref->add_linkage_type($eco, $uniprot_xrefs->[0]);
  if (defined $translation) {
    $dbe_adaptor->store($go_xref, $translation->dbID, 'Translation', 1, $uniprot_xrefs->[0]);
    $species_added{$tgt_species}++;
  } else {
    $species_missed{$tgt_species}++;
  }

}

foreach my $key (keys %adaptor_hash) {
  print "Stored " . $species_added{$key} . " entries and missed " . $species_missed{$key} . " for $key\n";
}



