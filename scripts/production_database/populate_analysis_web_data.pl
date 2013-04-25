#!/usr/local/ensembl/bin/perl -w

# POD documentation - main docs before the code

=pod

=head1 NAME

  populate_analysis_web_data.pl

=head1 SYNOPSIS

 script adds the missing analysis_web_data entries to the production database

=head1 DESCRIPTION

 The script loads the analyses found in the database
 and adds the corresponding entry in the analysis_web_data table in the production database.
 If no matching analysis_description is found in the production database,
 it tries to create it based on the species name.

 It will warn about analyses present in the database which don't have descriptions
 in the production database.

 To not update the production database, you need to pass the -noupdate option.

=head1 OPTIONS

     Database options

    -dbhost      User database host name
    -dbport      User database server port (optional, default is 3306)
    -dbname      User database name
    -dbuser      User name (can be read-only)
    -dbpass      User password
    -mhost       Production database host name
    -mport       Production database server port (optional, default is 3306)
    -mdbname     Production database name
    -muser       Production database user name (must have write-access)
    -mpass       Production database user password
    -species     Species for which to add the analyses
    -dbtype      Database type, eg. core|otherfeatures|vega ...
    -noupdate    Do not perform actual updates of analyses
    -user_id     User id used in the production database to identify who made the changes
    -help        print out documentation

=head1 EXAMPLES

 perl populate_analysis_web_data.pl -dbhost my_host -dbuser user -dbpass ***** -dbname my_db
 -mhost prod_host -muser user -mpass *** -mdbname prod_db
 -species homo_sapiens -dbtype core -user_id 1

=cut

use strict;
use Data::Dumper;
use Getopt::Long;
use DBI;

use Bio::EnsEMBL::Utils::Exception qw(warning throw);
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Gene;

$| = 1;

my ($dsn,$dbh);

my $dbhost;
my $dbport = 3306;
my $dbname;
my $dbuser;
my $dbpass;
my $mhost;
my $mport = 3306;
my $mdbname;
my $muser;
my $mpass;
my $species;
my $dbtype;
my $noupdate;
my $user_id;
my $help = 0;


&GetOptions (
  'host|dbhost=s'       => \$dbhost,
  'port|dbport=s'       => \$dbport,
  'dbname=s'            => \$dbname,
  'user|dbuser=s'       => \$dbuser,
  'pass|dbpass=s'       => \$dbpass,
  'mhost|mdbhost=s'     => \$mhost,
  'mport|mdbport=s'     => \$mport,
  'mdbname=s'           => \$mdbname,
  'muser|mdbuser=s'     => \$muser,
  'mpass|mdbpass=s'     => \$mpass,
  'species=s'           => \$species,
  'dbtype'              => \$dbtype,
  'user_id=s'           => \$user_id,
  'noupdate'            => \$noupdate,
  'h|help!'             => \$help
);

  if (!$dbhost) {
    print ("Need to pass a dbhost\n");
    $help = 1;
  }
  if (!$dbname) {
    $help = 1;
    throw("Need to enter a database name in -dbname\n");
  }
  if (!$user_id) {
    $user_id = 1;
    warn("No production user specified, using 1 as default");
  }
  if (!$species) {
    $dbname =~ /([a-z]*_[a-z]*)_(core|otherfeatures|vega|rnaseq|cdna|presite|sangervega)/;
    $species = $1;
    warn("No species defined, using $species inferred from database name");
  }
  if (!$dbtype) {
    $dbname =~ /([a-z]*_[a-z]*)_(core|otherfeatures|vega|rnaseq|cdna|presite|sangervega)/;
    $dbtype = $1;
    warn("No dbtype defined, using $dbtype inferred from database name");
  }


  if($help){
    usage();
  }



  my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor(
    -host    => $dbhost,
    -user    => $dbuser,
    -dbname  => $dbname,
    -pass    => $dbpass,
    -port    => $dbport
  );

  my $mdb = new Bio::EnsEMBL::DBSQL::DBAdaptor(
    -host    => $mhost,
    -user    => $muser,
    -dbname  => $mdbname,
    -pass    => $mpass,
    -port    => $mport,
    -species => 'multi',
    -group   => 'production'
  );

  my ($ad_id, $wd_id, $display, $description, $display_label, $db_version);
  my $helper = $mdb->dbc->sql_helper();

  my $species_id = get_species_id($helper, $species);

  # Pre-fetch all analyses in the database
  my $aa = $db->get_AnalysisAdaptor();
  my $analyses = $aa->fetch_all();

  # Loop through all analyses
  foreach my $analysis(@$analyses){

    my $logic_name = lc($analysis->logic_name());
    printf( "\nProcessing %s to analysis_web_data\n", $logic_name);

    # Check if there already is an analysis description for that logic name
    my $result = get_analysis_description($helper, $logic_name);

    # If not, see if we can add a new one copying a similar entry
    if (!$result) {
      printf( "%s has no entry in analysis_description, trying to use default\n", $logic_name);
      $logic_name =~ /^([a-z]*)_([a-z0-9_]*)/;
      my $prefix = ucfirst($1);

      my $suffix = $2;
      my $default_logic_name = "species_" . $suffix;
      
      my $ad = get_analysis_description($helper, $default_logic_name);
      if ($ad) {
        ($ad_id, $description, $display_label, $db_version, $wd_id, $display) = @$ad;
        $description =~ s/Species/$prefix/;
        $display_label =~ s/Species/$prefix/;
        printf( "Adding analysis_description for %s using %s\n", $logic_name, $default_logic_name);
      } else {
        throw("No analysis description added for $default_logic_name, exiting now");
      }

      if (!$noupdate) {
        $ad_id = add_analysis_description($helper, $logic_name, $description, $display_label, $db_version, $user_id, $wd_id, $display);
      }

    } else {
      ($ad_id, $description, $display_label, $db_version, $wd_id, $display) = @{ $result };
    }

    # Check if there already is an analysis web data entry for that logic name and species
    my $exists = get_aw($helper, $ad_id, $species_id);

    # If not, add it
    if (!$exists) {
      if (!$noupdate) {
        add_analysis_web_data($helper, $ad_id, $wd_id, $species_id, $dbtype, $display, $user_id);
      }
      printf( "Adding entry in analysis_web_data for species %s, logic name %s and database type %s\n", $species, $logic_name, $dbtype );
    } else {
      printf( "Entry already exists for %s and %s\n", $species, $logic_name);
    }
  }

sub get_species_id {
  my ($helper, $species) = @_;
  my $sql = "SELECT species_id FROM species WHERE db_name = ?";
  my $species_id = $helper->execute_simple(-SQL => $sql, -PARAMS => [$species])->[0];
  if (!$species_id) {
    throw("$species could not be found in the production database");
  }
  return $species_id;
}

sub get_analysis_description {
  my ($helper, $logic_name) = @_;
  my $sql = "SELECT analysis_description_id, description, display_label, db_version, default_web_data_id, default_displayable FROM analysis_description WHERE logic_name = ?";
  my $result = $helper->execute(-SQL => $sql, -PARAMS => [$logic_name])->[0];
  if (!$result) {
    printf( "No entry in analysis_description for %s\n", $logic_name );
  }
  return $result;
}

sub add_analysis_description {
  my ($helper, $logic_name, $description, $display_label, $db_version, $user_id, $wd_id, $display) = @_;
  my $sql = "INSERT INTO analysis_description (logic_name, description, display_label, db_version, is_current, created_by, created_at, default_web_data_id, default_displayable)
             VALUES (?, ?, ?, ?, 0, ?, now(), ?, ?)";
  my $mdbname = $helper->db_connection()->dbname();
  $helper->execute_update(-SQL => $sql, -PARAMS => [$logic_name, $description, $display_label, $db_version, $user_id, $wd_id, $display]);
  my $ad_id = $mdb->dbc()->db_handle()->last_insert_id(undef, $mdbname, 'analysis_description', 'analysis_description_id');
  return $ad_id;
}

sub get_aw {
  my ($helper, $ad_id, $species_id) = @_;
  my $sql = "SELECT analysis_web_data_id FROM analysis_web_data WHERE analysis_description_id = ? AND species_id = ?";
  return $helper->execute_simple(-SQL => $sql, -PARAMS => [$ad_id, $species_id])->[0];
}

sub add_analysis_web_data {
  my ($helper, $ad_id, $wd_id, $species_id, $dbtype, $display, $user_id) = @_;
  my $sql = "INSERT INTO analysis_web_data(analysis_description_id, web_data_id, species_id, db_type, displayable, created_by, created_at)
             VALUES (?, ?, ?, ?, ?, ?, now())";
  my $mdbname = $helper->db_connection()->dbname();
  $helper->execute_update(-SQL => $sql, -PARAMS => [$ad_id, $wd_id, $species_id, $dbtype, $display, $user_id]);
  my $aw_id = $mdb->dbc()->db_handle()->last_insert_id(undef, $mdbname, 'analysis_web_data', 'analysis_web_data_id');
  return $aw_id;
}

sub usage{
  exec('perldoc', $0);
  exit;
}
