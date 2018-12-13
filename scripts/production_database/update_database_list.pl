#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;

use Getopt::Long qw( :config no_ignore_case );
use DBI qw( :sql_types );

sub usage {
  my $padding = ' ' x length($0);

  print <<USAGE_END;
Usage:
  $0 --release NN --mhost master-server --mport master-port --mdbname master-database-name\\
  $padding --host server1 --host server2 [...] \\
  $padding --port 3306 --user user --pass passwd \\
  $padding --muser user-master-server --mpass pass-master-server
  $padding --nointeraction

or
  $0 --help

or
  $0 --about

where

  --release/-r  The current release (required).

  --mhost/-mh   The master server where the production database lives
                (optional, default is 'ens-staging1').

  --mport/-mP   The port on the master serve to connect to
                (optional, default is '3306').

  --mdbname/-md  The production database name on the master server that you want to conenct to
                (optional, default is 'ensembl_production').

  --host/-h   A database server (optional, may occur several times,
                default is 'ens-staging1', and 'ens-staging2').

  --port/-P   The port to connect to (optional, default is '3306').

  --user/-u   The (read only) user to connect as (optional,
                default is 'ensro').

  --pass/-p   The password to connect with as the above user
                (optional, no default).

  --muser/-mu The master server user (with write permissions) to connect as
                (optional, default is 'ensadmin').

  --mpass/-mp The master server password to connect with as the above user
                (optional, no default).

  --help/-h     Displays this help text.

  --about/-a    Displays a text about this program (what it does etc.).

  --nointeraction/-nI  Disable user input to allow the script to run as part of a cronjob

USAGE_END
} ## end sub usage

sub about {
  print <<ABOUT_END;
About:

  Run the program with --help to get information about available command
  line switches.

  Given at least a release number, this program will discover new
  databases on the staging servers and add them to the list of databases
  in the production database on the master server.

  The default options are set to minimize hassle for the Ensembl release
  coordinator who needs to run this script during the Ensembl production
  cycle.  The minimal invocation that will actually write things into
  the production database is

    $0 -r NN --dbwpass=password

  where NN is the current release and "password" is the password for the
  standard user with write permission.
  
  If DBs have dissapeared from a release then manual intervention from 
  the user is required to confirm deletion.

ABOUT_END
}

my $release;
my @hosts;
my $mhost = 'ens-staging1';
my $mport  = '3306';
my $mdbname = 'ensembl_production';

my $port = '3306';
my ( $muser, $mpass ) = ( 'ensadmin', undef );
my ( $user,  $pass )  = ( 'ensro',    undef );

my $opt_help  = 0;
my $opt_about = 0;
my $opt_nointeraction = 0;

if ( !GetOptions( 'release|r=i'  => \$release,
                  'mhost|mh=s'   => \$mhost,
                  'mport|mP=i'   => \$mport,
                  'mdbname|md=s' => \$mdbname,
                  'host|s=s@'  => \@hosts,
                  'user|u=s'   => \$user,
                  'pass|p=s'   => \$pass,
                  'port|P=s'   => \$port,
                  'muser|mu=s' => \$muser,
                  'mpass|mp=s' => \$mpass,
                  'help|h!'      => \$opt_help,
                  'about!'       => \$opt_about,
                  'nointeraction|nI!' => \$opt_nointeraction
                   )
     || $opt_help )
{
  usage();
  exit();
} elsif ($opt_about) {
  about();
  exit();
} elsif ( !defined($release) ) {
  print("ERROR: Release was not specified! (use -r or --release)\n");
  usage();
  exit();
}

if ( !@hosts ) {
  @hosts = ( 'ens-staging1', 'ens-staging2' );
}

my %species;
my %databases;

my %existing_databases;
my %found_databases;

{
  my $dsn = sprintf( 'DBI:mysql:host=%s;port=%d;database=%s',
                     $mhost, $mport, $mdbname );
  my $dbh = DBI->connect( $dsn, $muser, $mpass,
                          { 'PrintError' => 1, 'RaiseError' => 1 } );

  {
    my $statement =
        'SELECT species_id, web_name, db_name '
      . 'FROM species '
      . 'WHERE is_current = 1';

    my $sth = $dbh->prepare($statement);
    $sth->execute();

    my ( $species_id, $web_name, $db_name );
    $sth->bind_columns( \( $species_id, $web_name, $db_name ) );

    while ( $sth->fetch() ) {
      $species{$db_name} = { 'species_id' => $species_id,
                             'db_name'    => $db_name,
                             'web_name'   => $web_name };
    }
  }

  {
    my $statement =
        'SELECT full_db_name, db_release '
      . 'FROM db_list JOIN db USING (db_id) '
      . 'WHERE db.is_current = 1';

    my $sth = $dbh->prepare($statement);
    $sth->execute();

    my ($database, $db_release);
    $sth->bind_col( 1, \$database );
    $sth->bind_col( 2, \$db_release );

    while ( $sth->fetch() ) {
      $existing_databases{$database} = $db_release;
    }
  }

  $dbh->disconnect();
}

foreach my $host (@hosts) {
  my $dsn = sprintf( 'DBI:mysql:host=%s;port=%d', $host, $port );
  my $dbh = DBI->connect( $dsn, $user, $pass,
                          { 'PrintError' => 1, 'RaiseError' => 0 } );

  my $statement = 'SHOW DATABASES LIKE ?';

  my $sth = $dbh->prepare($statement);

  foreach my $species ( sort keys(%species) ) {
    $sth->bind_param( 1,
                      sprintf( '%s\_%%\_%s\_%%', $species, $release ),
                      SQL_VARCHAR );
    $sth->execute();

    my $database;
    $sth->bind_col( 1, \$database );

    while ( $sth->fetch() ) {
      if ( exists( $existing_databases{$database} ) ) {
        printf( "Skipping '%s'\n", $database );
        $found_databases{$database} = 1;
        next;
      }

      my ( $species_name, $db_type, $db_assembly, $db_suffix ) =
        ( $database =~
/^([0-9a-z]+_){2,3}([0-9a-z]+)_(?:[0-9]+_)?[0-9]+_([0-9a-z]+?)([a-z]?)$/ );

      if (    !defined($db_type)
           || !defined($db_assembly)
           || !defined($db_suffix) )
      {
        die(
           sprintf( "Failed to parse database name '%s'", $database ) );
      } else {
        printf( "--> Found '%s'\n"
                  . "\tspecies  = '%s'\n"
                  . "\ttype     = '%s'\n"
                  . "\tassembly = '%s'\n"
                  . "\tsuffix   = '%s'\n",
                $database,    $species, $db_type,
                $db_assembly, $db_suffix );
      }

      $databases{$database} = {
                       'species_id' => $species{$species}{'species_id'},
                       'db_type'    => $db_type,
                       'db_assembly' => $db_assembly,
                       'db_suffix'   => $db_suffix,
                       'db_host'     => $host};
    } ## end while ( $sth->fetch() )
  } ## end foreach my $species ( keys(...))

  $dbh->disconnect();
} ## end foreach my $host (@hosts)

my $dsn = sprintf( 'DBI:mysql:host=%s;port=%d;database=%s',
                     $mhost, $mport, $mdbname );
my $dbh = DBI->connect( $dsn, $muser, $mpass,
                        { 'PrintError' => 1, 'RaiseError' => 1 } );

if ( scalar( keys(%databases) ) == 0 ) {
  printf( "Did not find any new databases for release %s\n", $release );
} 
else {
  my $division_species =
      'INSERT IGNORE INTO division_species '
    . '(division_id, species_id) '
    . 'VALUES (?, ?)';
  my $division_species_query = $dbh->prepare($division_species);
  my $statement =
      'INSERT INTO db '
    . '(species_id, is_current, db_type, '
    . 'db_release, db_assembly, db_suffix, db_host) '
    . 'VALUES (?, 1, ?, ?, ?, ?, ?)';
  my $sth = $dbh->prepare($statement);
  my $update_sth = $dbh->prepare(<<'SQL');
update db set is_current =?, db_assembly=?, db_suffix =?, db_host =? 
where species_id =? and db_type =? and db_release =?
SQL

  foreach my $database ( sort keys(%databases) ) {
    my $db_hash = $databases{$database};
    
    my @already_recorded = $dbh->selectrow_array('select count(1) from db where species_id =? and db_type =? and db_release =?', 
      {}, $db_hash->{species_id}, $db_hash->{db_type}, $release);

      
    if($already_recorded[0]) {
      my @name = $dbh->selectrow_array('select common_name from species where species_id =?', {}, $db_hash->{species_id});
      printf("Species '%s' has a database '%s' recorded for this release. Updating\n", $name[0], $database);
      
      $update_sth->bind_param( 1, 1,                          SQL_INTEGER );
      $update_sth->bind_param( 2, $db_hash->{'db_assembly'},  SQL_VARCHAR );
      $update_sth->bind_param( 3, $db_hash->{'db_suffix'},    SQL_VARCHAR );
      $update_sth->bind_param( 4, $db_hash->{'db_host'},      SQL_VARCHAR );
      $update_sth->bind_param( 5, $db_hash->{'species_id'},   SQL_INTEGER );
      $update_sth->bind_param( 6, $db_hash->{'db_type'},      SQL_VARCHAR );
      $update_sth->bind_param( 7, $release,                   SQL_INTEGER );
      $update_sth->execute();


    }
    else {
      printf( "Inserting database '%s' into "
                . "the production database\n",
              $database );
  
      $sth->bind_param( 1, $db_hash->{'species_id'},  SQL_INTEGER );
      $sth->bind_param( 2, $db_hash->{'db_type'},     SQL_VARCHAR );
      $sth->bind_param( 3, $release,                  SQL_INTEGER );
      $sth->bind_param( 4, $db_hash->{'db_assembly'}, SQL_VARCHAR );
      $sth->bind_param( 5, $db_hash->{'db_suffix'},   SQL_VARCHAR );
      $sth->bind_param( 6, $db_hash->{'db_host'},     SQL_VARCHAR );
  
      $sth->execute();

          printf( "Inserting database '%s' into "
                . "the production database division_species table if it doesn't exist\n",
              $database );
      $division_species_query->bind_param( 1, 1,  SQL_INTEGER );
      $division_species_query->bind_param( 2, $db_hash->{'species_id'},  SQL_INTEGER );
      $division_species_query->execute();
    }
  }
  $sth->finish();
  $update_sth->finish();

  $dbh->do(
         sprintf( 'UPDATE db SET is_current = 0 WHERE db_release != %s',
                  $dbh->quote( $release, SQL_INTEGER ) ) );

} ## end else [ if ( scalar( keys(%databases...)))]

if ( scalar( keys(%existing_databases) ) !=
     scalar( keys(%found_databases) ) )
{
  local $| = 1;

  print("The following databases seem to have disappeared:\n");
  foreach my $db_name ( sort keys(%existing_databases) ) {
    my $db_release = $existing_databases{$db_name};
    if ( !exists( $found_databases{$db_name} ) ) {
      if($db_release != $release) {
        next; #if db release not same as the current one then skip
      }
      my $yesno;
      if ($opt_nointeraction) {
        printf( "\t%s. Removing this database: ", $db_name );
        $yesno='y';
      }
      else{
        printf( "\t%s. Remove this database? (y/N): ", $db_name );
        $yesno = <STDIN>;
        chomp($yesno);
      }
      if ( lc($yesno) =~ /^y(?:es)?$/ ) {
        my @dbid = $dbh->selectrow_array('select db_id from db_list where full_db_name =?', {}, $db_name);
        my $sth = $dbh->prepare('delete from db where db_id =?');
        $sth->execute($dbid[0]);
        $sth->finish();
      }
    }
  }
  print("\n");
}

$dbh->disconnect();
