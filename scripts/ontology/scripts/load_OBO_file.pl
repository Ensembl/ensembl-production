#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
#TODO Do we need this?
use FindBin;
use lib "$FindBin::Bin/../../../../ONTO-PERL-1.31/lib";

use DBI qw( :sql_types );
use Getopt::Long qw( :config no_ignore_case );
use OBO::Core::Ontology;
use OBO::Core::Term;
use OBO::Core::Relationship;
use OBO::Core::RelationshipType;
use OBO::Core::SynonymTypeDef;
use OBO::Parser::OBOParser;
use OBO::Util::TermSet;
use POSIX qw/strftime/;

#-----------------------------------------------------------------------

sub usage {
  my $pro = $0;
  my $off = q{ } x length($pro);
  print <<USAGE;
Usage:
  $pro  -h dbhost [-P dbport]
  $off  -u dbuser [-p dbpass]
  $off  -d dbname
  $off  -f file
  $off  -o ontology
  $off  [-?]

Arguments:
  -h/--host dbhost  Database server host name
  -P/--port dbport  Database server port (optional)
  -u/--user dbuser  Database user name
  -p/--pass dbpass  User password (optional)
  -d/--name dbname  Database name
  -f/--file file    The OBO file to parse
  -o/--ontology     Ontology name
  -?/--help         Displays this information
USAGE
}

#-----------------------------------------------------------------------

sub write_ontology {
  my ($dbh, $namespaces) = @_;

  print("Writing to 'ontology' table...\n");

  my $statement = "INSERT INTO ontology (name, namespace) VALUES (?,?)";

  my $sth = $dbh->prepare($statement);

  my $id;
  my $count = 0;

  local $SIG{ALRM} = sub {
    printf("\t%d entries, %d to go...\n", $count, scalar(keys(%{$namespaces})) - $count);
    alarm(10);
  };
  alarm(10);

  foreach my $namespace (sort(keys(%{$namespaces}))) {
    my $ontology = $namespaces->{$namespace};

    $sth->bind_param(1, $ontology,  SQL_VARCHAR);
    $sth->bind_param(2, $namespace, SQL_VARCHAR);

    $sth->execute();

    if (!defined($id)) {
      $id = $dbh->last_insert_id(undef, undef, 'ontology', 'ontology_id');
    }
    else {
      ++$id;
    }

    $namespaces->{$namespace} = {'id' => $id, 'name' => $ontology};

    ++$count;
  }
  alarm(0);

  #if unknown ontology not found, store it
  my ($unknown_onto_id) = $dbh->selectrow_array("SELECT ontology_id from ontology WHERE name = 'UNKNOWN'");

  if (!defined($unknown_onto_id)) {

    my $statement = "INSERT INTO ontology (name, namespace) VALUES ('UNKNOWN','unknown ontology')";
    my $sth       = $dbh->prepare($statement);
    $sth->execute();
    $unknown_onto_id = $dbh->last_insert_id(undef, undef, 'ontology', 'ontology_id');

  }
  $dbh->do("OPTIMIZE TABLE ontology");

  printf("\tWrote %d entries\n", $count);

  return $unknown_onto_id;
} ## end sub write_ontology

#-----------------------------------------------------------------------

sub write_subset {
  my ($dbh, $subsets) = @_;

  print("Writing to 'subset' table...\n");

  $dbh->do("LOCK TABLE subset WRITE");

  my $statement = q{INSERT IGNORE INTO subset (name, definition) VALUES (?,?)};
  my $lookup_sql = 'select subset_id from subset where name =?';

  my $sth = $dbh->prepare($statement);
  my $lookup_sth = $dbh->prepare($lookup_sql);

  my $count = 0;

  local $SIG{ALRM} = sub {
    printf("\t%d entries, %d to go...\n", $count, scalar(keys(%{$subsets})) - $count);
    alarm(10);
  };
  alarm(10);

  foreach my $subset_name (sort(keys(%{$subsets}))) {
    my $subset = $subsets->{$subset_name};
    $subset->{'name'} =~ s/:/_/g;

    if (!(defined($subset->{'name'}) && defined($subset->{'definition'}))) {
      print "Null value encountered: subset name " . $subset->{'name'} . " subset definition " . $subset->{'definition'} . "\n";
      exit;
    }

    $sth->bind_param(1, $subset->{'name'},       SQL_VARCHAR);
    $sth->bind_param(2, $subset->{'definition'}, SQL_VARCHAR);

    $sth->execute();
    
    my $id = $dbh->last_insert_id(undef, undef, 'subset', 'subset_id');
    if(! $id) {
      $lookup_sth->bind_param(1, $subset->{name}, SQL_VARCHAR);
      $lookup_sth->execute();
      ($id) = $lookup_sth->fetchrow_array();
      printf("CLASH: SUBSET '%s' already exists in this database. Reusing ID %d\n", $subset->{name}, $id);
    } 
    
    $subset->{'id'} = $id;

    ++$count;
  }
  alarm(0);
  
  $lookup_sth->finish();
  $sth->finish();

  $dbh->do("OPTIMIZE TABLE term");
  $dbh->do("UNLOCK TABLES");

  printf("\tWrote %d entries\n", $count);
} ## end sub write_subset

#-----------------------------------------------------------------------

sub write_term {
  my ($dbh, $terms, $subsets, $namespaces, $unknown_onto_id) = @_;

  print("Writing to 'term', 'synonym' and 'alt_id' tables...\n");

  $dbh->do("LOCK TABLES term WRITE, synonym WRITE, alt_id WRITE");

  my $statement = "INSERT IGNORE INTO term (ontology_id, subsets, accession, name, definition, is_root, is_obsolete) VALUES (?,?,?,?,?,?,?)";

  my $syn_stmt = "INSERT INTO synonym (term_id, name, type) VALUES (?,?,?)";

  my $alt_stmt = "INSERT INTO alt_id (term_id, accession) VALUES (?,?)";

  my $existing_term_st = "SELECT term_id, ontology_id FROM term WHERE accession = ?";

  my $update_stmt = "UPDATE term SET ontology_id = ?, subsets = ?, name = ?, definition = ?, is_root = ? WHERE term_id = ?";

  my $sth               = $dbh->prepare($statement);
  my $update_sth        = $dbh->prepare($update_stmt);
  my $syn_sth           = $dbh->prepare($syn_stmt);
  my $alt_sth           = $dbh->prepare($alt_stmt);
  my $existing_term_sth = $dbh->prepare($existing_term_st);

  my $count         = 0;
  my $updated_count = 0;
  my $syn_count     = 0;

  local $SIG{ALRM} = sub {
    printf("\t%d entries, %d to go...\n", $count, scalar(keys(%{$terms})) - $count);
    alarm(10);
  };
  alarm(10);

  foreach my $accession (sort(keys(%{$terms}))) {
    my $term = $terms->{$accession};

    my $term_subsets;
    my $reuse = 0;

    if (exists($term->{'subsets'})) {
      $term_subsets = join(',', map { $subsets->{$_}{'name'} } @{$term->{'subsets'}});
      $term_subsets =~ s/:/_/g;
    }

    if (!defined($term->{'name'})) {

      #check if we have this term in the db already
      $existing_term_sth->execute($term->{'accession'});
      my ($existing_term_id, $ontology_id) = $existing_term_sth->fetchrow_array;
      if (defined($existing_term_id)) {
        $term->{'id'} = $existing_term_id;
      }
      else {
        #if not link it to Unknown ontology
        $sth->bind_param(1, $unknown_onto_id,        SQL_INTEGER);
        $sth->bind_param(2, $term_subsets,           SQL_VARCHAR);
        $sth->bind_param(3, $term->{'accession'},    SQL_VARCHAR);
        $sth->bind_param(4, 'UNKNOWN NAME',          SQL_VARCHAR);
        $sth->bind_param(5, 'UNKNOWN DEFINITION',    SQL_VARCHAR);
        $sth->bind_param(6, $term->{'is_root'},      SQL_INTEGER);
        $sth->bind_param(7, $term->{'is_obsolete'},  SQL_INTEGER);
        $sth->execute();
        my $id = $dbh->last_insert_id(undef, undef, 'term', 'term_id');
        $term->{'id'} = $id;
        ++$count;
      }

    }
    else {

      #we have the term name, check if the term is linked to unknown ontology in the ontology db
      #if so, update it
      $existing_term_sth->execute($term->{'accession'});
      my ($existing_term_id, $ontology_id) = $existing_term_sth->fetchrow_array;
      if (defined($existing_term_id) && $ontology_id == $unknown_onto_id) {

        $update_sth->bind_param(1, $namespaces->{$term->{'namespace'}}{'id'}, SQL_INTEGER);
        $update_sth->bind_param(2, $term_subsets,                             SQL_VARCHAR);
        $update_sth->bind_param(3, $term->{'name'},                           SQL_VARCHAR);
        $update_sth->bind_param(4, $term->{'definition'},                     SQL_VARCHAR);
        $update_sth->bind_param(5, $existing_term_id,                         SQL_INTEGER);
        $update_sth->bind_param(6, $term->{'is_root'},                        SQL_INTEGER);
        $update_sth->bind_param(7, $term->{'is_obsolete'},                    SQL_INTEGER);

        $update_sth->execute();

        $term->{'id'} = $existing_term_id;
        ++$updated_count;
      }
      else {

        $sth->bind_param(1, $namespaces->{$term->{'namespace'}}{'id'}, SQL_INTEGER);
        $sth->bind_param(2, $term_subsets,                             SQL_VARCHAR);
        $sth->bind_param(3, $term->{'accession'},                      SQL_VARCHAR);
        $sth->bind_param(4, $term->{'name'},                           SQL_VARCHAR);
        $sth->bind_param(5, $term->{'definition'},                     SQL_VARCHAR);
        $sth->bind_param(6, $term->{'is_root'},                        SQL_INTEGER);
        $sth->bind_param(7, $term->{'is_obsolete'},                    SQL_INTEGER);

        $sth->execute();
        my $id = $dbh->last_insert_id(undef, undef, 'term', 'term_id');
        if(! $id) {
          $existing_term_sth->execute($term->{'accession'});
          my ($existing_term_id, $ontology_id) = $existing_term_sth->fetchrow_array;
          $id = $existing_term_id;
          printf("DUPLICATION: TERM '%s' already exists in this database. Reusing ID %d\n", $term->{accession}, $existing_term_id);
          $reuse = 1;
        }
        $term->{'id'} = $id;

        ++$count;
      }
      
      if($term->{synonyms} && @{$term->{synonyms}}) {
        if($reuse) {
          print "REUSE: SKIPPING SYNONYM writing as term already exists in this database\n";
        }
        else {
          foreach my $syn (@{$term->{'synonyms'}}) {
            $syn_sth->bind_param(1, $term->{id},  SQL_INTEGER);
            $syn_sth->bind_param(2, $syn->def_as_string(), SQL_VARCHAR);
	    $syn_sth->bind_param(3, $syn->scope());

            $syn_sth->execute();
    
            ++$syn_count;
          }
        }
      }

      if(!$term->{alt_id}->is_empty) {
        if($reuse) {
          print "REUSE: SKIPPING ALT_ID writing as term already exists in this database\n";
        }
        else {
          foreach my $acc ($term->{'alt_id'}->get_set()) {
            $alt_sth->bind_param(1, $term->{id},  SQL_INTEGER);
            $alt_sth->bind_param(2, $acc, SQL_VARCHAR);

            $alt_sth->execute();

            ++$syn_count;
          }
        }
      }

    }
  } ## end foreach my $accession ( sort...)
  alarm(0);

  $dbh->do("OPTIMIZE TABLE term");
  $dbh->do("OPTIMIZE TABLE synonym");
  $dbh->do("OPTIMIZE TABLE alt_id");
  $dbh->do("UNLOCK TABLES");

  printf("\tWrote %d entries into 'term', updated %d entries in 'term' and wrote %d entries into 'synonym'\n", $count, $updated_count, $syn_count);
} ## end sub write_term

#-----------------------------------------------------------------------

sub write_relation_type {
  my ($dbh, $relation_types) = @_;

  print("Writing to 'relation_type' table...\n");

  my $select_stmt = "SELECT relation_type_id FROM relation_type WHERE name = ?";
  my $select_sth  = $dbh->prepare($select_stmt);

  my $insert_stmt = "INSERT INTO relation_type (name) VALUES (?)";
  my $insert_sth  = $dbh->prepare($insert_stmt);

  my $count = 0;

  local $SIG{ALRM} = sub {
    printf("\t%d entries, %d to go...\n", $count, scalar(keys(%{$relation_types})) - $count);
    alarm(10);
  };
  alarm(10);

  foreach my $relation_type (sort(keys(%{$relation_types}))) {
    $select_sth->bind_param(1, $relation_type, SQL_VARCHAR);
    $select_sth->execute();

    my $id;
    my $found = 0;

    $select_sth->bind_columns(\$id);

    while ($select_sth->fetch()) {
      $relation_types->{$relation_type} = {'id' => $id};
      $found = 1;
    }

    if (!$found) {
      $insert_sth->bind_param(1, $relation_type, SQL_VARCHAR);
      $insert_sth->execute();
      $relation_types->{$relation_type} = {'id' => $dbh->last_insert_id(undef, undef, 'relation_type', 'relation_type_id')};
      ++$count;
    }
  } ## end foreach my $relation_type (...)
  alarm(0);

  $dbh->do("OPTIMIZE TABLE relation_type");

  printf("\tWrote %d entries\n", $count);
} ## end sub write_relation_type

#-----------------------------------------------------------------------

sub write_relation {
  my ($dbh, $terms, $relation_types, $ontology, $namespaces) = @_;

  print("Writing to 'relation' table...\n");

  $dbh->do("LOCK TABLE relation WRITE");

  my $statement = "INSERT IGNORE INTO relation " . "(child_term_id, parent_term_id, relation_type_id, intersection_of, ontology_id) " . "VALUES (?,?,?,?,?)";

  my $sth = $dbh->prepare($statement);

  my $count = 0;
  my $ontology_id;

  local $SIG{ALRM} = sub {
    printf("\t%d entries, %d to go...\n", $count, scalar(keys(%{$terms})) - $count);
    alarm(10);
  };
  alarm(10);

  foreach my $child_term (sort { $a->{'id'} <=> $b->{'id'} } values(%{$terms})) {
    foreach my $relation_type (sort(keys(%{$child_term->{'parents'}}))) {
      foreach my $parent_acc (sort(@{$child_term->{'parents'}{$relation_type}})) {
        if ($namespaces->{$child_term->{'namespace'}}{'name'} eq $ontology) {
          $ontology_id = $namespaces->{$child_term->{'namespace'}}{'id'};
        } else {
          $ontology_id = $namespaces->{$ontology}{'id'}
        }

        if (!defined($terms->{$parent_acc})) {
          printf("WARNING: Parent accession '%s' does not exist!\n", $parent_acc);
        }
        else {

          if (!(defined($child_term->{'id'}) && defined($terms->{$parent_acc}{'id'}) && defined($relation_types->{$relation_type}{'id'}))) {
            print "Null value encountered: child term id " . $child_term->{'id'} . " parent term id " . $terms->{$parent_acc}{'id'} . " relationship type " . $relation_types->{$relation_type}{'id'} . "\n";
            exit;
          }

          $sth->bind_param(1, $child_term->{'id'},                             SQL_INTEGER);
          $sth->bind_param(2, $terms->{$parent_acc}{'id'},                     SQL_INTEGER);
          $sth->bind_param(3, $relation_types->{$relation_type}{'id'},         SQL_INTEGER);
          $sth->bind_param(4, 0,                                               SQL_INTEGER);
          $sth->bind_param(5, $ontology_id,                                    SQL_INTEGER);
          $sth->execute();
          
          if(! $dbh->last_insert_id(undef, undef, 'relation', 'relation_id')) {
            printf "DUPLICATION: RELATION %s (child) %s %s (parent) has been repeated. Ignoring this insert for ontology %s\n", $child_term->{accession}, $relation_type, $parent_acc, $ontology_id;
          }
        }
      }
    }
    foreach my $relation_type (sort(keys(%{$child_term->{'intersection_of_parents'}}))) {
      foreach my $parent_acc (sort(@{$child_term->{'intersection_of_parents'}{$relation_type}})) {
        if ($namespaces->{$child_term->{'namespace'}}{'name'} eq $ontology) {
          $ontology_id = $namespaces->{$child_term->{'namespace'}}{'id'};
        } else {
          $ontology_id = $namespaces->{$ontology}{'id'}
        }

        if (!defined($terms->{$parent_acc})) {
          printf("WARNING: Parent accession '%s' does not exist!\n", $parent_acc);
        }
        else {

          if (!(defined($child_term->{'id'}) && defined($terms->{$parent_acc}{'id'}) && defined($relation_types->{$relation_type}{'id'}))) {
            print "Null value encountered: child term id " . $child_term->{'id'} . " parent term id " . $terms->{$parent_acc}{'id'} . " relationship type " . $relation_types->{$relation_type}{'id'} . "\n";
            exit;
          }

          $sth->bind_param(1, $child_term->{'id'},                             SQL_INTEGER);
          $sth->bind_param(2, $terms->{$parent_acc}{'id'},                     SQL_INTEGER);
          $sth->bind_param(3, $relation_types->{$relation_type}{'id'},         SQL_INTEGER);
          $sth->bind_param(4, 1,                                               SQL_INTEGER);
          $sth->bind_param(5, $ontology_id,                                    SQL_INTEGER);
          $sth->execute();
          if(! $dbh->last_insert_id(undef, undef, 'relation', 'relation_id')) {
            printf "DUPLICATION: RELATION %s (child) %s %s (parent) has been repeated for ontology %s. Ignoring this insert\n", $child_term->{accession}, $relation_type, $parent_acc, $ontology_id;
          }
        }
      }
    }
    ++$count;
  } ## end foreach my $child_term ( sort...)

  alarm(0);

  $dbh->do("OPTIMIZE TABLE relation");
  $dbh->do("UNLOCK TABLES");

  printf("\tWrote %d entries\n", $count);
} ## end sub write_relation

#-----------------------------------------------------------------------

my ($dbhost, $dbport);
my ($dbuser, $dbpass);
my ($dbname, $obo_file_name);
my $ontology_name;
my $delete_unknown;

$dbport = '3306';

GetOptions(
  'dbhost|host|h=s' => \$dbhost,
  'dbport|port|P=i' => \$dbport,
  'dbuser|user|u=s' => \$dbuser,
  'dbpass|pass|p=s' => \$dbpass,
  'dbname|name|d=s' => \$dbname,
  'file|f=s'        => \$obo_file_name,
  'ontology|o=s'    => \$ontology_name,
  'delete_unknown'  => \$delete_unknown,
  'help|?'          => sub { usage(); exit }
);

if (!defined($dbhost) || !defined($dbuser) || !defined($dbname)) {
  usage();
  exit;
}

if (!$delete_unknown && (!defined($obo_file_name) || !defined($ontology_name))) {
  usage();
  exit;
}

my $dsn = sprintf('dbi:mysql:database=%s;host=%s;port=%s', $dbname, $dbhost, $dbport);

my $dbh = DBI->connect($dsn, $dbuser, $dbpass, {'RaiseError' => 1, 'PrintError' => 2});

#delete the 'UNKNOWN' ontology and exit
if ($delete_unknown) {

  my ($unknown_onto_id) = $dbh->selectrow_array("SELECT ontology_id from ontology WHERE name = 'UNKNOWN'");

  if (!defined($unknown_onto_id)) {
    print "'UNKNOWN' ontology doesn\'t exist - nothing to delete.\n";
  }
  else {
    my ($unknown_term_count) = $dbh->selectrow_array("select count(1) from term t join ontology o using(ontology_id) where o.name = 'UNKNOWN'");

    if ($unknown_term_count > 0) {
      print("Cannot delete ontology 'UNKNOWN' as $unknown_term_count terms are linked to this ontology.\n");

    }
    else {

      my $delete_unknown_sth = $dbh->prepare("delete from ontology where ontology_id = $unknown_onto_id");
      $delete_unknown_sth->execute();
      $delete_unknown_sth->finish();
      print("0 terms linked to 'UNKNOWN' ontology - ontology deleted.\n");
    }

  }

  $dbh->disconnect();
  exit;
}

#if parsing an EFO obo file delete xref lines - not compatible with OBO:Parser
#requires correct default-namespace defined
my $efo_default_namespace;
my @returncode = `grep -i "default-namespace: efo" $obo_file_name`;
@returncode = `grep 'property_value: "hasDefaultNamespace" "EFO"' $obo_file_name` if scalar(@returncode) == 0;
my $returncode = @returncode;
if ($returncode > 0) {
  printf "Detected an EFO file; performing post-processing\n";
  my $new_obo_file_name = "${obo_file_name}.new";
  open my $obo_fh, '<', $obo_file_name or die "Cannot open the file ${obo_file_name}: $!";
  open my $new_obo_fh, '>', $new_obo_file_name or die "Cannot open target file ${new_obo_file_name}: $!";
  my $current_state = q{};
  while(my $line = <$obo_fh>) {
    chomp($line);
    my $skip = 0;
    
    if($line =~/^\[( (?:Term|Typedef|Instance) )\]$/xms) {
      $current_state = $1;
    }
    
    if($current_state eq q{} && $line =~ /^property_value/) {
      $skip = 1;
      if($line =~/"hasDefaultNamespace" "(EFO)"/) {
        $efo_default_namespace = $1;
      }
    }
    
    #Original skip by mk8
    if($line =~ /^xref/) {
      $skip = 1;
    }
    
    #1.4 term type
    if($current_state eq 'Term' && $line =~ /^equivalent_to/) {
      $skip = 1;
    }
    
    if($current_state eq 'Typedef' && $line =~ /^is_ (?:inverse_)? functional/xms) {
      $skip = 1;
    }
    
    #1.2 does not allow this in a typedef field
    if($current_state eq 'Typedef' && $line =~ /^property_value/) {
      $skip = 1;
    }
    
    print $new_obo_fh $line, "\n" if ! $skip;
  }
  close($obo_fh);
  close($new_obo_fh);
  
  printf "Switching to loading the file %s which is a post-processed file\n", $new_obo_file_name;
  $obo_file_name = $new_obo_file_name;
}

my $my_parser = OBO::Parser::OBOParser->new;

printf("Reading OBO file '%s'...\n", $obo_file_name);

my $ontology = $my_parser->work($obo_file_name) or die;

#Reset default namespace if it was EFO and they encoded it as a property
$ontology->default_namespace($efo_default_namespace) if $efo_default_namespace && ! $ontology->default_namespace();

#Set date to today if one was not present
if(! $ontology->date()) {
  print "No date found; generating one\n";
  my $date = strftime('%d:%m:%Y %H:%M', localtime());
  $ontology->date($date);
}

my $statement = "SELECT name from ontology where name = ? group by name";

my $select_sth = $dbh->prepare($statement);

$select_sth->bind_param(1, $ontology_name, SQL_VARCHAR);
$select_sth->execute();

if ($select_sth->fetch()) {
  print("This ontology name already exists in the database.\nPlease run the program again with a new name.\n");
  $select_sth->finish();
  $dbh->disconnect();
  exit;
}

$statement = "SELECT meta_value FROM meta WHERE meta_key = 'OBO_file_date'";

my $stored_obo_file_date = $dbh->selectall_arrayref($statement)->[0][0];

my $obo_file_date = $ontology->date();

$obo_file_date = sprintf("%s/%s", $obo_file_name, $obo_file_date);

if (defined($stored_obo_file_date)) {
  if ($stored_obo_file_date eq $obo_file_date) {
    print("This OBO file has already been processed.\n");
    $dbh->disconnect();
    exit;
  }
  elsif (index($stored_obo_file_date, $obo_file_name) != -1) {
    print <<EOT;
==> Trying to load a newer (?) OBO file that has already
==> been loaded.  Please clean the database manually of
==> data associated with this file and try again...
EOT
    $dbh->disconnect();
    exit;
  }
}

my (%terms, %namespaces, %relation_types, %subsets);

my $default_namespace = $ontology->default_namespace();
my @subsets;
if ($OBO::Core::Ontology::VERSION <= 1.31) {
  my $set = $ontology->subset_def_set();
  @subsets = $set->get_set();
}
else {
  @subsets = $ontology->subset_def_map()->values();
}

foreach my $subs (@subsets) {
  $subsets{$subs->name()}{'name'}       = $subs->name();
  $subsets{$subs->name()}{'definition'} = $subs->description();
}

# get all non obsolete terms
foreach my $t (@{$ontology->get_terms()}) {

    my %term;
    my $is_root = 1;

    my @t_namespace     = $t->namespace();
    my $t_namespace_elm = @t_namespace;
    if ($t_namespace_elm > 0) {
      $term{'namespace'} = $t_namespace[0];
    }
    else {
      $term{'namespace'} = $default_namespace;
    }
    $namespaces{$term{'namespace'}} = $ontology_name;

    $term{'accession'}   = $t->id();
    $term{'name'}        = $t->name();
    $term{'definition'}  = $t->def_as_string();

    $term{'is_obsolete'} = $t->is_obsolete();

    if ($t->idspace() ne $ontology_name) {
      $is_root = 0;
    } else {
      if (scalar(@{ $ontology->get_parent_terms($t) }) > 0) {
        $is_root = 0;
      } else {
        if ($t->is_obsolete()) {
          $is_root = 0;
        }
      }
    }
    $term{'is_root'} = $is_root;

    my $rels = $ontology->get_relationships_by_source_term($t);
    foreach my $r (@{$rels}) {

      #get parent term
      my $pterm = $r->head();
      push(@{$term{'parents'}{$r->type()}}, $pterm->id());
    }

    my @intersection_of = $t->intersection_of();
    foreach my $r (@intersection_of) {

      if ($r->isa('OBO::Core::Relationship')) {

        #get parent term for relationship
        my $pterm = $r->head();
        my $type  = $r->type();
        if (!defined($type) || $type eq 'nil') {
          $type = 'is_a';
        }
        push(@{$term{'intersection_of_parents'}{$type}}, $pterm->id());
      }
      else {

        #this is a term
        push(@{$term{'intersection_of_parents'}{'is_a'}}, $r->id());
      }

    }

    my @term_subsets = $t->subset();
    foreach my $term_subset (@term_subsets) {
      push(@{$term{'subsets'}}, $term_subset);
    }
    my @t_synonyms = $t->synonym_set();
    foreach my $t_synonym (@t_synonyms) {
      push(@{$term{'synonyms'}}, $t_synonym);
    }

    $term{'alt_id'} = $t->alt_id();

    $terms{$term{'accession'}} = {%term};

}

#get all relationship types
foreach my $rel_type (@{$ontology->get_relationship_types()}) {
  my $rel_type_name = $rel_type->id();
  if (!exists($relation_types{$rel_type_name})) {
    $relation_types{$rel_type_name} = 1;
  }
}

print("Finished reading OBO file, now writing to database...\n");

my $unknown_onto_id = write_ontology($dbh, \%namespaces);
write_subset($dbh, \%subsets);
write_term($dbh, \%terms, \%subsets, \%namespaces, $unknown_onto_id);
write_relation_type($dbh, \%relation_types);
write_relation($dbh, \%terms, \%relation_types, $ontology_name, \%namespaces);

print("Updating meta table...\n");

my $sth = $dbh->prepare("DELETE FROM meta " . "WHERE meta_key = 'OBO_file_date' " . "AND meta_value LIKE ?");
$sth->bind_param(1, sprintf("%s/%%", $obo_file_name), SQL_VARCHAR);
$sth->execute();
$sth->finish();

$sth = $dbh->prepare("INSERT INTO meta (meta_key, meta_value)" . "VALUES ('OBO_file_date', ?)");
$sth->bind_param(1, $obo_file_date, SQL_VARCHAR);
$sth->execute();
$sth->finish();

my $obo_load_date = sprintf("%s/%s", $obo_file_name, scalar(localtime()));

$sth = $dbh->prepare("DELETE FROM meta " . "WHERE meta_key = 'OBO_load_date' " . "AND meta_value LIKE ?");
$sth->bind_param(1, sprintf("%s/%%", $obo_file_name), SQL_VARCHAR);
$sth->execute();
$sth->finish();

$sth = $dbh->prepare("INSERT INTO meta (meta_key, meta_value)" . "VALUES ('OBO_load_date', ?)");
$sth->bind_param(1, $obo_load_date, SQL_VARCHAR);
$sth->execute();
$sth->finish();

$dbh->disconnect();

print("Done.\n");

# $Id$
