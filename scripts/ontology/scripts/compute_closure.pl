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

# Modified from "Relational Modeling of
# Biological Data: Trees and Graphs", page 2:
# http://www.oreillynet.com/pub/a/network/2002/11/27/bioconf.html?page=2

use strict;
use warnings;

use Data::Dumper;

use DBI;
use Getopt::Long qw( :config no_ignore_case );

#-----------------------------------------------------------------------

sub usage {
  print("Usage:\n");
  printf( "\t%s\t-h dbhost [-P dbport] \\\n"
        . "\t%s\t-u dbuser [-p dbpass] \\\n"
        . "\t%2\$s\t-d dbname [-c config]\n",
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
  print("\t-c/--config config_file\tConfiguration file\n");
  print("\t-?/--help\t\tDisplays this information\n");
}

#-----------------------------------------------------------------------

my ( $dbhost, $dbport );
my ( $dbuser, $dbpass );
my $dbname;
my $config_file = 'closure_config.ini';

$dbport = '3306';

if ( !GetOptions( 'dbhost|host|h=s' => \$dbhost,
                  'dbport|port|P=i' => \$dbport,
                  'dbuser|user|u=s' => \$dbuser,
                  'dbpass|pass|p=s' => \$dbpass,
                  'dbname|name|d=s' => \$dbname,
                  'config|c=s'      => \$config_file,
                  'help|?'          => sub { usage(); exit } )
     || !defined($dbhost)
     || !defined($dbuser)
     || !defined($dbname) )
{
  usage();
  exit;
}

# set up relations configuration
my $default_relations = [ 'is_a', 'part_of' ];
my $config;
my $test_eval = eval { require Config::Simple };

if (!$test_eval) {
  # The user does not have the 'Config::Simple' module.
  print( STDERR "No Config::Simple module found, "
          . "continuing without the ini-file.\n" );
  # If the configuration file *is* an ini-file, we can expect a
  # load of compilation errors from the next eval...
} else {
  # The user has the 'Config::Simple' module installed.  See
  # if this is an ini-file or not...
  $config = new Config::Simple($config_file)->vars();
}

my $dsn = sprintf( "DBI:mysql:database=%s;host=%s;port=%s",
                   $dbname, $dbhost, $dbport );

my $dbh = DBI->connect( $dsn, $dbuser, $dbpass,
                        { 'RaiseError' => 1, 'PrintError' => 1 } );

print "Clearing closure table\n";
$dbh->do('TRUNCATE TABLE closure');
$dbh->do('ALTER TABLE closure DISABLE KEYS');

print "Importing intra-ontology parent-child relations\n";
$dbh->do(
  q/
   INSERT INTO  closure
                (child_term_id, parent_term_id, distance, subparent_term_id, ontology_id)
        SELECT  term_id, term_id, 0, NULL, ontology_id
          FROM  term
         WHERE  is_obsolete = 0/ );

print "Importing inter-ontology parent-child relations\n";
my $rels_join_xaspect = join ',', map { "'$_'" } @$default_relations;
$dbh->do(
  qq/
  INSERT IGNORE INTO  closure
                       (child_term_id, parent_term_id, distance, subparent_term_id, ontology_id)
     SELECT DISTINCT
       r.child_term_id, r.parent_term_id, 0, NULL, r.ontology_id
     FROM
            term c
       JOIN ontology o ON (c.ontology_id=o.ontology_id)
       JOIN relation r ON (c.term_id=r.child_term_id)
       JOIN relation_type rt ON (r.relation_type_id=rt.relation_type_id)
       JOIN term p ON (r.parent_term_id=p.term_id)
     WHERE
           c.ontology_id!=p.ontology_id
       AND rt.name IN ($rels_join_xaspect)
       AND c.is_obsolete=0
       AND p.is_obsolete=0/ );

# hash using ontology_name-namespace with list of possible relations
print "Importing defined relations\n";
my $relations = {};
my $sth = $dbh->prepare(
  q/
   SELECT  distinct o.name, o.namespace
     FROM  ontology o
     JOIN  relation r using (ontology_id)/ );

$sth->execute();
my @row;
while ( @row = $sth->fetchrow_array ) {
  $relations->{ $row[0] }->{ $row[1] } = 1;
}
$sth->finish();

for my $ontology ( keys %{$relations} ) {
  for my $namespace ( keys %{ $relations->{$ontology} } ) {
    my $rels = $config->{ $ontology . '.' . $namespace };
    if ( !defined $rels ) {
      $rels = $default_relations;
    }
    if ( scalar(@$rels) > 0 ) {
      my $rels_join = join ',', map { "'$_'" } @$rels;
      print "Importing $ontology.$namespace $rels_join relations\n";
      $dbh->do(
        qq/
         INSERT IGNORE INTO  closure
                             (child_term_id, parent_term_id, distance, subparent_term_id, ontology_id)
            SELECT DISTINCT
             r.child_term_id, r.parent_term_id, 1, r.child_term_id, r.ontology_id
           FROM
                  term c
             JOIN ontology o ON (c.ontology_id=o.ontology_id)
             JOIN relation r ON (c.term_id=r.child_term_id)
             JOIN relation_type rt ON (r.relation_type_id=rt.relation_type_id)
             JOIN term p ON (r.parent_term_id=p.term_id)
           WHERE
                 c.ontology_id=p.ontology_id
             AND rt.name IN ($rels_join)
             AND c.is_obsolete=0
             AND p.is_obsolete=0
             AND  o.name='$ontology' AND o.namespace='$namespace'/ );
    }
  }
}

print "Computing closures\n";

my $select_sth = $dbh->prepare(
  q/
   SELECT DISTINCT
           child.child_term_id,
           parent.parent_term_id,
           child.distance + 1,
           parent.child_term_id,
           child.ontology_id
     FROM  closure child
     JOIN  closure parent
       ON  (parent.child_term_id = child.parent_term_id)
     JOIN  ontology co
       ON  (child.ontology_id=co.ontology_id)
     JOIN  ontology po
       ON  (parent.ontology_id=po.ontology_id)
    WHERE  child.distance  = ?
      AND  parent.distance = 1
      AND  co.name = po.name/
);

my $insert_sth = $dbh->prepare(
  q/
   REPLACE INTO  closure
                 (child_term_id, parent_term_id, distance, subparent_term_id, ontology_id)
         VALUES  (?, ?, ?, ?, ?)/ );

my ($oldsize) = $dbh->selectrow_array('SELECT COUNT(1) FROM closure');
my $newsize;
my $distance = 0;

local $SIG{ALRM} = sub {
  printf( "Distance = %d, Size = %d\n", $distance, $newsize );
  alarm(10);
};
alarm(10);

while ( !defined($newsize) || $newsize > $oldsize ) {
  $oldsize = $newsize || $oldsize;
  $newsize = $oldsize;

  $dbh->do('LOCK TABLES closure AS child READ, closure AS parent READ, ontology as co READ, ontology as po READ');

  $select_sth->execute( ++$distance );

  $dbh->do('LOCK TABLE closure WRITE');
  while ( my @data = $select_sth->fetchrow_array() ) {
    $insert_sth->execute(@data);
    $newsize++;
  }
  $dbh->do('UNLOCK TABLES');
}
alarm(0);

print "Computing closures complete - optimising tables\n";

$dbh->do('ALTER TABLE closure ENABLE KEYS');
$dbh->do('OPTIMIZE TABLE closure');

$dbh->disconnect();

# $Id$
