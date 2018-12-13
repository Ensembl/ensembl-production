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

use DBI qw( :sql_types );
use Getopt::Long qw( :config no_ignore_case );

use Data::Dumper;

#-----------------------------------------------------------------------

sub usage {
  print("Usage:\n");
  printf( "\t%s\t-h dbhost [-P dbport] \\\n"
            . "\t%s\t-u dbuser [-p dbpass] \\\n"
            . "\t%2\$s\t-d dbname\n",
          $0, ' ' x length($0) );
  print("\n");
  printf( "\t%s\t-?\n", $0 );
  print("\n");
  print("Arguments:\n");
  print("\t-h/--host dbhost\tDatabase server host name\n");
  print("\t-P/--port dbport\tDatabase server port (optional)\n");
  print("\t-u/--user dbuser\tDatabase user name\n");
  print("\t-p/--pass dbpass\tUser password (optional)\n");
  print("\t-d/--name dbname\tDatabase name\n");
  print("\t-?/--help\t\tDisplays this information\n");
}

#-----------------------------------------------------------------------

my ( $dbhost, $dbport );
my ( $dbuser, $dbpass );
my $dbname;

$dbport = '3306';

if ( !GetOptions( 'dbhost|host|h=s' => \$dbhost,
                  'dbport|port|P=i' => \$dbport,
                  'dbuser|user|u=s' => \$dbuser,
                  'dbpass|pass|p=s' => \$dbpass,
                  'dbname|name|d=s' => \$dbname,
                  'help|?'          => sub { usage(); exit } )
     || !defined($dbhost)
     || !defined($dbuser)
     || !defined($dbname) )
{
  usage();
  exit;
}

my $dsn = sprintf( "DBI:mysql:database=%s;host=%s;port=%s",
                   $dbname, $dbhost, $dbport );

my $dbh = DBI->connect( $dsn, $dbuser, $dbpass,
                        { 'RaiseError' => 0, 'PrintError' => 0 } );

# Associate all subsets in the ontology database with their respective
# ontology.

my %subsets;

my $statement = q(
SELECT DISTINCT
        ontology.name,
        subset.name
FROM    ontology,
        term,
        subset
WHERE   ontology.ontology_id = term.ontology_id
  AND   is_obsolete = 0
  AND   FIND_IN_SET(subset.name, term.subsets) > 0
);

my $table_template = q(
CREATE TABLE %s (
  term_id           INT UNSIGNED NOT NULL,
  subset_term_id    INT UNSIGNED NOT NULL,
  distance          TINYINT UNSIGNED NOT NULL,
  UNIQUE INDEX map_idx (term_id, subset_term_id)
)
SELECT  child_term.term_id AS term_id,
        parent_term.term_id AS subset_term_id,
        MIN(distance) AS distance
FROM    ontology
  JOIN  term parent_term
    ON  (parent_term.ontology_id = ontology.ontology_id)
  JOIN  closure
    ON  (closure.parent_term_id = parent_term.term_id)
  JOIN  term child_term
    ON  (child_term.term_id = closure.child_term_id)
WHERE   ontology.name = %s
  AND   FIND_IN_SET(%s, parent_term.subsets) > 0
  AND   parent_term.ontology_id = closure.ontology_id
  AND   child_term.ontology_id = closure.ontology_id
  AND   parent_term.is_obsolete = 0
  AND   child_term.is_obsolete = 0
GROUP BY child_term.term_id, parent_term.term_id
);

my $sth = $dbh->prepare($statement);

$sth->execute();

my ( $ontology_name, $subset_name );

$sth->bind_columns( \( $ontology_name, $subset_name ) );

while ( $sth->fetch() ) {

  my $aux_table_name = $dbh->quote_identifier(
             sprintf( "aux_%s_%s_map", $ontology_name, $subset_name ) );

  printf( "Creating and populating %s...\n", $aux_table_name );

  $dbh->do( sprintf( $table_template,
                     $aux_table_name, $dbh->quote($ontology_name),
                     $dbh->quote($subset_name) ) );

  if ( $dbh->err() ) {
    printf( "MySQL error, \"%s\", skipping...\n", $dbh->errstr() );
    next;
  }

}

# $Id$
