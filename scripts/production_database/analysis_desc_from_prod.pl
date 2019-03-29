#!/usr/bin/env/perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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
# limitations under the License

# Usage
# Update a new database with analysis descriptions from the production
# database.

# Default is to update all analyses
#perl analysis_desc_from_prod.pl \
#  $(mysql-devel-1-ensrw details script) \
#  $(mysql-pan-prod-ensrw details prefix_m) \
#  --dbname bombyx_mori_core_29_82_1
  
# A subset of analyses can be specfied by repeated use of the -logic_name parameter
#perl analysis_desc_from_prod.pl \
#  $(mysql-devel-1-ensrw details script) \
#  $(mysql-pan-prod-ensrw details prefix_m) \
#  --dbname bombyx_mori_core_29_82_1 \
#  --logic_name dust \
#  --logic_name trf

# https://www.ebi.ac.uk/seqdb/confluence/display/EnsGen/Defining+track+display

use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case);
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Log::Log4perl qw/:easy/;
use Data::Dumper;

Log::Log4perl->easy_init($DEBUG);

my $logger = get_logger();

my ($host, $port, $user, $pass, $dbname,
    $mhost, $mport, $muser, $mdbname,
    $species, $type, @logic_names);

GetOptions(
  "host=s", \$host,
  "P|port=i", \$port,
  "user=s", \$user,
  "p|pass=s", \$pass,
  "dbname=s", \$dbname,
  "mhost=s", \$mhost,
  "mP|mport=i", \$mport,
  "muser=s", \$muser,
  "mdbname=s", \$mdbname,
  "logic_name:s", \@logic_names,
);

die "--host required" unless $host;
die "--port required" unless $port;
die "--user required" unless $user;
die "--pass required" unless $pass;
die "--dbname required" unless $dbname;
die "--mhost required" unless $mhost;
die "--mport required" unless $mport;
die "--muser required" unless $muser;

$mdbname = "ensembl_production" unless $mdbname;

my $prod_dba = Bio::EnsEMBL::Production::DBSQL::DBAdaptor->new(
    -host   => $mhost,
    -port   => $mport,
    -user   => $muser,
    -dbname => $mdbname,
);

my $new_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host   => $host,
    -port   => $port,
    -user   => $user,
    -pass   => $pass,
    -dbname => $dbname,
);

my $dbc = $new_dba->dbc();

my ($insert, $update, $delete) = (1, 1, 1);
my $backup = 0;

#Log::Log4perl->easy_init($DEBUG);

my $controlled_tables = {
external_db => {
    label => 'db_name',
    cols  => [
        qw/external_db_id db_name status priority db_display_name type secondary_db_name secondary_db_table description/
    ],
    all_cols => [
        qw/db_release external_db_id db_name status priority db_display_name type secondary_db_name secondary_db_table description/
    ],
    row_id => 'external_db_id'
  },

  attrib_type => { label    => 'code',
                   cols     => [qw/attrib_type_id code name description/],
                   all_cols => [qw/attrib_type_id code name description/],
                   row_id   => 'attrib_type_id' },
  attrib => { label    => 'value',
              cols     => [qw/attrib_id attrib_type_id value/],
              all_cols => [qw/attrib_id attrib_type_id value/],
              row_id   => 'attrib_id' },

  attrib_set => { label    => 'attrib_set_id',
                  cols     => [qw/attrib_set_id attrib_id/],
                  all_cols => [qw/attrib_set_id attrib_id/],
                  row_id   => 'attrib_set_id' },

  biotype => { label    => 'name',
               cols     => [qw/biotype_id name object_type db_type attrib_type_id description biotype_group so_acc/],
               all_cols => [qw/biotype_id name object_type db_type attrib_type_id description biotype_group so_acc/],
               row_id   => 'biotype_id' },

  misc_set => { label    => 'code',
                cols     => [qw/misc_set_id code name description max_length/],
                all_cols => [qw/misc_set_id code name description max_length/],
                row_id   => 'misc_set_id' },

  unmapped_reason => {
      label    => 'summary_description',
      cols     => [qw/unmapped_reason_id summary_description full_description/],
      all_cols => [qw/unmapped_reason_id summary_description full_description/],
      row_id   => 'unmapped_reason_id' }

};

my @active_tables = ();
if ( $dbc->dbname =~ m/_cdna|core|otherfeatures|rnaseq|vega_/ ) {
  @active_tables =
    qw/attrib_type biotype external_db misc_set unmapped_reason analysis_description/;
}
elsif ( $dbc->dbname =~ m/_variation_/ ) {
  @active_tables = qw/attrib_type attrib attrib_set/;
}
elsif ( $dbc->dbname =~ m/_compara_/ ) {
  @active_tables = qw/external_db/;
}
else {
  $logger->warn( "Do not know how to process database " . $dbc->dbname );
}
for my $table (@active_tables) {
  update_controlled_table( $dbc, $table );
}

sub update_controlled_table {
  my ( $dbc, $table ) = @_;
  #$logger->info( "Updating $table for " . $dbc->dbname() );

  if ( $table eq 'analysis_description' ) {
    return update_analysis_description($dbc, \@logic_names);
  }
  elsif ( defined $controlled_tables->{$table} ) {
    my $helper = $dbc->sql_helper();

    backup_table( $dbc, $table );

    my $mdata = get_production_table($table);
    my $data =
      get_data_from_table( $dbc, get_select($table),
                                  $controlled_tables->{$table}{row_id} );

    if ( $insert == 1 ) {
      foreach my $row_id ( keys %$mdata ) {
        if ( !exists $data->{$row_id} ) {
          $helper->execute_update(
                -SQL    => get_insert($table),
                -PARAMS => [
                  map { $mdata->{$row_id}{$_} } @{ $controlled_tables->{$table}{all_cols} }
                ] );
          $logger->info( "Inserted data for row_id $row_id (" .
                         $mdata->{$row_id}{ $controlled_tables->{$table}{label} } . ")" );
        }
      }
    }

    if ( $update == 1 ) {
      foreach my $row_id ( keys %$mdata ) {
        if ( exists $data->{$row_id} ) {
          if (
             join( '', (
                     map { $mdata->{$row_id}{$_} || '' }
                       @{ $controlled_tables->{$table}{cols} } )
             ) ne join(
               '', (
                 map { $data->{$row_id}{$_} || '' } @{ $controlled_tables->{$table}{cols} }
               ) ) )
          {
            $helper->execute_update(
               -SQL    => get_update($table),
               -PARAMS => [
                 ( map { $mdata->{$row_id}{$_} } @{ $controlled_tables->{$table}{cols} } ),
                 $row_id ] );
            $logger->info( "Updated data for id $row_id (" .
                          $mdata->{$row_id}{ $controlled_tables->{$table}{label} } . ")" );
          }
        }
      }
    }

    if ( $delete == 1 ) {
      foreach my $row_id ( keys %$data ) {
        if ( !exists $mdata->{$row_id} ) {
          $helper->execute_update( -SQL    => get_delete($table),
                                   -PARAMS => [$row_id] );
          $logger->info( "Deleted data for id $row_id (" .
                         $data->{$row_id}{ $controlled_tables->{$table}{label} } . ")" );
        }
      }
    }

    $logger->info( "Completed updating $table for " . $dbc->dbname() );

    return;
  } ## end elsif ( defined $controlled_tables->... [ if ( $table eq 'analysis_description')])
  else {
    throw "Do not know how to update table $table";
  }
} ## end sub update_controlled_table

sub update_analysis_description {
  my ( $dbc, $logic_names ) = @_;

  #throw "type is required" if ( !$type );

  my $dbname = $dbc->dbname();

  my ( $species, $type ) = ( $dbname =~ m/^amonida_([^_]+_[^_]+)_([^_]+)/ );

  throw "Could not determine type from $dbname"
    unless ( $type );

  if ( !defined $logic_names || scalar(@$logic_names)==0 ) {
    $logic_names =
      $dbc->sql_helper()
      ->execute_simple( -SQL =>
'select logic_name from analysis join analysis_description using (analysis_id)'
      );
  }
  $logic_names = { map { $_ => 1 } @$logic_names };

  backup_table( $dbc, "analysis_description" );

  $logger->info("Retrieving analyses for $species/$type."
    . " Note species information is not used!");
    my $analysis_types = get_data_from_table(
    $prod_dba->dbc(), qq/
             SELECT ad.logic_name as logic_name, ad.description as description,
                    ad.display_label as display_label, wd.data as web_data,
                    ad.displayable as displayable
               FROM analysis_description ad, web_data wd
              WHERE ad.web_data_id = wd.web_data_id/, 'logic_name'
    );

  $logger->info("Retrieving generic analyses");
  my $generic_analyses = get_generic_analyses();
  while ( my ( $k, $v ) = each %{ $generic_analyses } ) {
    if ( !exists $analysis_types->{$k} ) {
      $analysis_types->{$k} = $v;
    }
  }
  $logger->info("Updating analyses");
  while ( my ( $logic_name, $analysis ) = each %{$analysis_types} ) {
    if ( scalar( keys %$logic_names ) == 0 ||
         exists $logic_names->{$logic_name} )
    {
      $logger->debug("Updating $logic_name");
      if(!defined $analysis->{web_data}) {
        $analysis->{web_data} = $generic_analyses->{$logic_name}{web_data};
      }
      if ( defined $analysis->{web_data} ) {
        $analysis->{web_data} = eval( $analysis->{web_data} );
        my $dumper = Data::Dumper->new( [ $analysis->{web_data} ] );
        $dumper->Indent(0);
        $dumper->Terse(1);
        $analysis->{web_data} = $dumper->Dump();

        $dbc->sql_helper->execute_update(
            -SQL =>
q/UPDATE analysis_description ad JOIN analysis a USING (analysis_id) 
      SET ad.description=?,ad.display_label=?,ad.web_data=?,ad.displayable=?
      WHERE logic_name=?/,
            -PARAMS => [
                $analysis->{description}, $analysis->{display_label},
                $analysis->{web_data},    $analysis->{displayable},
                $logic_name
            ]
        );
    } else {

      $dbc->sql_helper->execute_update(
          -SQL =>
q/UPDATE analysis_description ad JOIN analysis a USING (analysis_id) 
    SET ad.description=?,ad.display_label=?,ad.displayable=?
    WHERE logic_name=?/,
          -PARAMS => [
              $analysis->{description}, $analysis->{display_label},
              $analysis->{displayable}, $logic_name
          ]
      );
      }
    }
  }
  $logger->info( "Completed updating analysis_description for " . $dbname );
  return;
} ## end sub update_analysis_description

sub backup_table {
  my ( $dbc, $table ) = @_;
  if ( $backup == 1 ) {
    $logger->info("Backing up $table");
    $dbc->sql_helper->execute_update(
      -SQL => "DROP TABLE IF EXISTS ${table}_bak" );
    $dbc->sql_helper->execute_update(
      -SQL => "CREATE TABLE ${table}_bak AS SELECT * FROM $table" );
  }
  return;
}

sub get_production_table {
  my ( $table ) = @_;
  $logger->info("Retrieving production $table");
  $table =
    get_data_from_table( $prod_dba->dbc(), get_select($table),
      $controlled_tables->{$table}{row_id} );
  return $table;
}

sub get_data_from_table {
  my ( $dbc, $sql, $row_id ) = @_;
  return {
    map { $_->{$row_id} => $_ } @{
      $dbc->sql_helper()->execute( -USE_HASHREFS => 1, -SQL => $sql );
    } };
}

sub get_select {
  my ($table) = @_;
  return 'SELECT ' . join( ',', @{ $controlled_tables->{$table}{cols} } ) . ' FROM ' .
    $table;
}

sub get_insert {
  my ($table) = @_;
  return 'INSERT INTO ' . $table . ' (' .
    join( ', ', @{ $controlled_tables->{$table}{all_cols} } ) . ') VALUES (' .
    join( ', ', ( map { "?" } @{ $controlled_tables->{$table}{all_cols} } ) ) . ')';
}

sub get_update {
  my ($table) = @_;
  return 'UPDATE ' . $table . ' SET ' .
    join( ', ', ( map { "$_ = ?" } @{ $controlled_tables->{$table}{cols} } ) ) .
    ' WHERE ' . $controlled_tables->{$table}{row_id} . ' = ?';
}

sub get_delete {
  my ($table) = @_;
  return ' DELETE FROM ' . $table . ' WHERE ' . $controlled_tables->{$table}{row_id} . ' = ?';
}

sub get_generic_analyses {
  my $analyses;
  if ( !defined $analyses ) {
    $analyses = get_data_from_table(
      $prod_dba->dbc(),
q/SELECT ad.logic_name as logic_name, ad.description as description, 
  ad.display_label as display_label, wd.data as web_data, 1 as displayable
  FROM analysis_description ad 
  LEFT OUTER JOIN web_data wd ON ad.web_data_id = wd.web_data_id 
  WHERE ad.is_current = 1/, 'logic_name'
    );
  }
  return $analyses;
}
