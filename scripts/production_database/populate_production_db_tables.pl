#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
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

use DBI qw( :sql_types );
use Getopt::Long qw( :config no_ignore_case );
use POSIX;

my $timestamp = strftime( "%Y%m%d-%H%M%S", localtime() );

my %master_tables = ( 'attrib_type'     => 1,
                      'external_db'     => 1,
                      'misc_set'        => 1,
                      'unmapped_reason' => 1 );

my %variation_master_tables = ( 'attrib_type'     => 1,
                                'attrib'          => 1,
                                'attrib_set'      => 1);

my @tables;

# Master database location:
my ( $mhost, $mport ) = ( 'ens-staging1', '3306' );
my ( $muser, $mpass ) = ( 'ensro',        undef );
my $mdbname = 'ensembl_production';

# User database location (default values):
my ( $host, $port ) = ( undef, '3306' );
my ( $user, $pass );
my $dbname;
my $dbpattern;

my $core     = 0;
my $verbose  = 0;
my $dropbaks = 0;
my $variation = 0;
my $dumppath;

# Do command line parsing.
if ( !GetOptions( 'mhost|mh=s'     => \$mhost,
                  'mport|mP=i'     => \$mport,
                  'muser|mu=s'     => \$muser,
                  'mpass|mp=s'     => \$mpass,
                  'mdatabase|md=s' => \$mdbname,
                  'host|h=s'       => \$host,
                  'port|P=i'       => \$port,
                  'user|u=s'       => \$user,
                  'pass|p=s'       => \$pass,
                  'database|d=s'   => \$dbname,
                  'pattern=s'      => \$dbpattern,
                  'table|t=s'      => \@tables,
                  'verbose|v!'     => \$verbose,
                  'core=i'         => \$core,
                  'variation!'     => \$variation,
                  'dropbaks|dB!'   => \$dropbaks,
                  'dumppath|dp=s'  => \$dumppath )
     ||
     !( defined($host) &&
        defined($user) &&
        defined($pass) &&
        ( defined($dbname) || defined($dbpattern) || defined($core) ) &&
        defined($mhost) &&
        defined($muser) ) ||
     ( $dropbaks && !defined($dumppath) ) )
{
  my $indent = ' ' x length($0);
  print <<USAGE_END;
This script copies master tables from the production database 
into a user-defined database.

Usage:

  $0 -h host [-P port] \\
  $indent -u user [-p password]
  $indent -d database | --pattern pattern \\
  $indent [-dp dumppath] [-dB] \\
  $indent [-mh host] [-mP port] \\
  $indent [-mu user] [-mp password] [-md database] \\
  $indent [-t table] [-t table] [-t ...] \\
  $indent [-v]

  -h / --host       User database server host.
  -P / --port       User database server port (optional, default is 3306).

  -u / --user       User username (must have write-access).
  -p / --pass       User password.

  -d / --database   User database name or SQL pattern,
                    e.g. --database="homo_sapiens_rnaseq_62_37g"
                    or   --database="%core_62%".

  -dp / --dumppath  Dump path.
                    Back-up tables into the specified directory path. If you are
                    using --dropbaks you must specify this option

  --pattern         User database by Perl regular expression,
                    e.g. --pattern="^homo.*(rnaseq|vega)_62".

                    (-d/--database and --pattern are mutually exclusive)

  --core=NN         Preset pattern for Core-like databases in relase NN.
                    Specifying --core=62 is equivalent to using
                    --pattern="(cdna|core|otherfeatures|rnaseq|vega)_62".

  --variation       Flag to use variation master tables rather than core-like ones

  -mh / --mhost     Production database server host
                    (optional, default is 'ens-staging1').
  -mP / --mport     Production database server port
                    (optional, default is 3306).

  -mu / --muser     Production database username (no write-access required)
                    (optional, default is 'ensro').
  -mp / --mpass     Production database password
                    (optional, default is undefined).

  -md / --mdatabase Production database name
                    (optional, default is 'ensembl_production').

  -t / --table      A specific table to update, may occur several times,
                    must be one of the tables attrib_type, external_db,
                    misc_set, or unmapped_reason.

  -dB / --dropbaks  Drop backups.
                    Forces the dropping of the _bak tables created as
                    part of this script's run.  Normally we would suggest
                    you keep this option off unless you know you do not
                    want these.  You must run this option with --dumppath
                    to avoid unintentional data loss.

  -v / --verbose    Be verbose, display every SQL statement as they
                    are executed (on standard error).


USAGE_END

  die( "Need the following options: " .
       "-h -u -p and -d (or --pattern, or --core)\n" );

} ## end if ( !GetOptions( 'mhost|mh=s'...))

if ( defined($dumppath) && !-d $dumppath ) {
  die("Dump path '$dumppath' does not exist or is not a directory");
}

if (@tables) {
  foreach my $table (@tables) {
    if ( !exists( $master_tables{$table} ) ) {
      die( sprintf( "Invalid table specified: '%s'\n", $table ) );
    }
  }
} elsif ($variation) {
  @tables = keys(%variation_master_tables);
} else {
  @tables = keys(%master_tables);
}

if ($core) {
  $dbpattern = sprintf( '(cdna|core|otherfeatures|rnaseq|vega)_%d', $core );
}

if ( defined($dbname) && defined($dbpattern) ) {
  die("-d/--database and --pattern/--core are mutually exclusive\n");
}

if ($core && $variation) {
  die("--core and --variation are mutually exclude\n");
}

# Fetch all data from the master database.
my %data;
{
  my $dsn = sprintf( 'DBI:mysql:host=%s;port=%d;database=%s',$mhost, $mport, $mdbname );
  my $dbh = DBI->connect( $dsn, $muser, $mpass,{ 'PrintError' => 1, 'RaiseError' => 1 } );

  foreach my $table (@tables) {
    my $sth = $dbh->prepare(sprintf( 'SELECT * FROM %s',$dbh->quote_identifier( undef, $mdbname, $table ) ));
    $sth->execute();

    while ( my $row = $sth->fetchrow_arrayref() ) {
      push( @{ $data{$table} }, [ @{$row} ] );
    }
  }

  $dbh->disconnect();
}

# Put all data into the specified database.
{
  my $dsn = sprintf( 'DBI:mysql:host=%s;port=%d', $host, $port );
  my $dbh = DBI->connect( $dsn, $user, $pass, { 'PrintError' => 1, 'RaiseError' => 1 } );

  my $sth;
  if ( defined($dbname) ) {
    $sth = $dbh->prepare('SHOW DATABASES LIKE ?');
    $sth->bind_param( 1, $dbname, SQL_VARCHAR );
  } else {
    $sth = $dbh->prepare('SHOW DATABASES');
  }

  $sth->execute();
  $sth->bind_col( 1, \$dbname );
# iterate over all DBs
  while ( $sth->fetch() ) {
    if ( defined($dbpattern) && $dbname !~ /$dbpattern/ ) { next }

    print( '=' x 80, "\n" );
    printf( "\t%s\n", $dbname );
    print( '=' x 80, "\n" );

    my @backup_tables;
    my @updates;

    foreach my $table ( keys(%data) ) {
      printf( "==> %s: ", $table );

      my $full_table_name = $dbh->quote_identifier( undef, $dbname, $table );
      my $full_table_name_bak = $dbh->quote_identifier( undef, $dbname, $table . '_bak' );
      my $key_name = $table . '_id';

      if ( defined($dumppath) ) {
        backup_table($dumppath,$dbname,$table,$timestamp);
      }
      
      $dbh->do(sprintf( 'DROP TABLE IF EXISTS %s', $full_table_name_bak ) );
      # Make a backup of any existing data.
      $dbh->do( sprintf( 'CREATE TABLE %s LIKE %s',$full_table_name_bak, $full_table_name ) );
      $dbh->do( sprintf( 'INSERT INTO %s SELECT * FROM %s',$full_table_name_bak, $full_table_name ) );
      push( @backup_tables, $full_table_name_bak );

      if ($table eq 'external_db') {
        my @stuff = update_external_db($dbh, $full_table_name, \%data);
        push @updates, @stuff;
      } else {
        # Truncate (empty) the table before inserting new data into it.
        $dbh->do( sprintf( 'TRUNCATE TABLE %s', $full_table_name ) );

        # Get column information.
        my $colinfo_sth = $dbh->column_info( undef, $dbname, $table, '%' );
        my $colinfo = $colinfo_sth->fetchall_hashref( ['ORDINAL_POSITION'] );
        my $numcols = scalar( keys( %{$colinfo} ) );

        # INSERT a copy of each row read from the master table,
        foreach my $row ( @{ $data{$table} } ) {
          my $insert_statement = sprintf('INSERT INTO %s (%s) VALUES (%s)',
            $full_table_name,
            join( ', ', map { $colinfo->{$_}{'COLUMN_NAME'} } 1 .. $numcols ),
            join( ', ', map { $dbh->quote( $row->[ $_ - 1 ], $colinfo->{$_}{'DATA_TYPE'} ) } ( 1 .. $numcols ) ) 
          );
          printf( STDERR "EXECUTING: %s\n", $insert_statement ) if ($verbose);
          
          $dbh->do($insert_statement);
        }
      }

      print("<inserted data>");
      diff_tables($dbh, $table, $key_name, $full_table_name, $full_table_name_bak);

      print("<updated data>");
      diff_tables($dbh, $table, $key_name, $full_table_name_bak, $full_table_name);
      
      {
        if (@updates) {
          print("\n");
          print("Data updated:\n");
          printf( "SELECT * FROM %s WHERE %s_id IN (%s);\n",
                  $table, $table, join( ',', @updates ) );
          print("\n");
        }
        print("\n");
      }

    } ## end foreach my $table ( keys(%data...))
    continue {
      print("\n");
    }

    if ($dropbaks) {
      foreach my $backup_table (@backup_tables) {
        printf( "Dropping the backup table %s\n", $backup_table );
        $dbh->do("DROP TABLE $backup_table");
      }
    }

    print("\n");

  } ## end while ( $sth->fetch() )

  $dbh->disconnect();
}

if ( defined($dumppath) ) {
  print <<MSG1_END
To restore a table from a table dump, use either "source {dumpfile}" or
"\. {dumpfile}" from the MySQL command shell.
MSG1_END
}
if ( !$dropbaks ) {
  print <<MSG2_END
Each table has also been backed up to a table with "_bak" appended to its name.
MSG2_END
}

sub diff_tables {
  my ($dbh,$table,$key,$table1,$table2) = @_;
  my $statement = sprintf( 'SELECT %s FROM %s ' .
                             'LEFT JOIN %s t USING (%s) ' .
                             'WHERE t.%s IS NULL ' .
                             'ORDER BY %s',
                           $key,
                           $table1,
                           $table2,
                           $key,
                           $key,
                           $key );

  printf( STDERR "EXECUTING: %s\n", $statement ) if $verbose;
  my $sth = $dbh->prepare($statement);
  $sth->execute();
  $sth->bind_col( 1, \$key);
  my @keys;
  while ($sth->fetch()) { push( @keys, $key ) };

  if (@keys) {
    print("\n");
    print("Data found in $table1 that is not in $table2\n");
    printf( "SELECT * FROM %s WHERE %s_id IN (%s);\n",$table1, $table, join( ',', @keys ) );
    print("\n");
  }
}

sub backup_table {
  my ($dumppath,$dbname,$table,$timestamp) = @_;
  my $filename = sprintf( "%s/%s.%s.%s.sql",$dumppath,$dbname,$table,$timestamp );

  if ( -e $filename ) {
    die( sprintf( "File '%s' already exists.", $filename ) );
  }

    printf( "Backing up table %s on file.\n", $table );
    printf( "--> %s\n",                       $filename );

    if (system( "mysqldump","--host=$host","--port=$port","--user=$user", 
                (defined($pass) ? "--password=$pass" : "--skip-opt"), "--result-file=$filename", 
                "--skip-opt","$dbname","$table" ) ) {
      die("mysqldump failed: $?");
    }
}

sub update_external_db {
  my ($dbh,$full_table_name,$original) = @_;
  my %external_db;
  my $sth = $dbh->prepare( sprintf('SELECT * FROM %s', $full_table_name) );
  $sth->execute();

  while ( my $row = $sth->fetchrow_arrayref() ) {
    my $external_db_id = $row->[0];
    push @{ $external_db{$external_db_id} }, @{$row} ;
  }
  my @updates;

  foreach my $master_row ( @{ $original->{'external_db'} } ) {
    my $colinfo = $dbh->column_info( undef, $dbname, 'external_db', '%' )->fetchall_hashref( ['ORDINAL_POSITION'] );
    # $colinfo is 1-based
    my $numcols = scalar keys %{$colinfo};
    my $master_external_db_id = $master_row->[0];
    if (! exists $external_db{$master_external_db_id}) {
      my $insert_statement = sprintf('INSERT INTO %s (%s) VALUES (%s)',
        $full_table_name,
        join( ', ', map { $colinfo->{$_}{'COLUMN_NAME'} } 1 .. $numcols ),
        join( ', ', map { $dbh->quote( $master_row->[ $_ - 1 ], $colinfo->{$_}{'DATA_TYPE'} ) } ( 1 .. $numcols ) ) );
      
      printf( STDERR "EXECUTING: %s\n", $insert_statement ) if ($verbose);
      $dbh->do($insert_statement);
    } else {
      my @target_db_content = @{ $external_db{$master_external_db_id} };
      for (my $i = 1; $i < $numcols; $i++) {
        # omit implictly identical db_id column by starting at 1
        next if ($colinfo->{$i+1}{'COLUMN_NAME'} eq 'db_release'); # don't touch species-specific releases of data sources
        if (defined $master_row->[$i] && ($target_db_content[$i] ne $master_row->[$i]) ) {
          push (@updates, $master_external_db_id);
          my $update_statement = sprintf("UPDATE %s SET %s = '%s' WHERE external_db_id = %s",
            $full_table_name, $colinfo->{$i+1}{'COLUMN_NAME'}, $master_row->[$i], $master_external_db_id);

          printf( STDERR "EXECUTING: %s\n", $update_statement ) if ($verbose);
          $dbh->do($update_statement);
        }
      }
    }
    delete $external_db{$master_external_db_id};
  }
  # delete any remaining keys that are not found in the master table
  foreach my $k (keys %external_db) {
    my $delete_statement = sprintf("DELETE FROM %s WHERE external_db_id = %s", $full_table_name, $k);
    if ($verbose) {
      printf( STDERR "EXECUTING: %s\n", $delete_statement );
    }
    $dbh->do($delete_statement);
  }
  return @updates;
}
