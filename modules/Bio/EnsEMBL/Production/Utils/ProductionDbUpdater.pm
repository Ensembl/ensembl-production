=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

  Bio::EnsEMBL::Production::Utils::ProductionDbUpdater;

=head1 SYNOPSIS

  my $updater = Bio::EnsEMBL::Production::Utils::ProductionDbUpdater->new(
                      -PRODUCTION_DBA => $prod_dba);
                      
  $updater->update_controlled_tables($dbc);

=head1 DESCRIPTION

  Utility for updating a database from the Ensembl production database
  Used by update_controlled_tables.pl

=cut

package Bio::EnsEMBL::Production::Utils::ProductionDbUpdater;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Log::Log4perl qw/get_logger/;
use Data::Dumper;

my $logger = get_logger();

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  ( $self->{prod_dba}, $self->{backup}, $self->{insert},
    $self->{update},   $self->{delete} )
    = rearrange( [ 'PRODUCTION_DBA', 'BACKUP', 'INSERT', 'UPDATE', 'DELETE' ],
                 @args );
  if ( !defined $self->{prod_dba} ) {
    throw "-PRODUCTION_DBA not specified";
  }
  $self->{backup} ||= 0;
  $self->{insert} ||= 1;
  $self->{update} ||= 1;
  $self->{delete} ||= 1;
  return $self;
}

# definition of supported tables
my $tables = {
  external_db => {
    label => 'db_name',
    cols  => [
      qw/external_db_id db_name status priority db_display_name type secondary_db_name secondary_db_table description/
    ],
    all_cols => [
      qw/db_release external_db_id db_name status priority db_display_name type secondary_db_name secondary_db_table description/
    ],
    row_id => 'external_db_id' },

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

sub update_controlled_tables {
  my ( $self, $dbc ) = @_;
  my @tables = ();
  if ( $dbc->dbname =~ m/_cdna|core|otherfeatures|rnaseq|vega_/ ) {
    @tables =
      qw/attrib_type biotype external_db misc_set unmapped_reason/;
  }
  elsif ( $dbc->dbname =~ m/_variation_/ ) {
    @tables = qw/attrib_type attrib attrib_set/;
  }
  elsif ( $dbc->dbname =~ m/_compara_/ ) {
    @tables = qw/external_db/;
  }
  else {
    $logger->warn( "Do not know how to process database " . $dbc->dbname );
  }
  for my $table (@tables) {
    $self->update_controlled_table( $dbc, $table );
  }
  return;
}

sub update_controlled_table {
  my ( $self, $dbc, $table ) = @_;
  $logger->info( "Updating $table for " . $dbc->dbname() );

  if ( defined $tables->{$table} ) {
    my $helper = $dbc->sql_helper();

    $self->backup_table( $dbc, $table );

    my $mdata = $self->get_production_table($table);
    my $data =
      $self->get_data_from_table( $dbc, get_select($table),
                                  $tables->{$table}{row_id} );

    if ( $self->{insert} == 1 ) {
      $logger->info("Inserting new rows");
      foreach my $row_id ( keys %$mdata ) {
        if ( !exists $data->{$row_id} ) {
          $helper->execute_update(
                -SQL    => get_insert($table),
                -PARAMS => [
                  map { $mdata->{$row_id}{$_} } @{ $tables->{$table}{all_cols} }
                ] );
          $logger->info( "Inserted data for row_id $row_id (" .
                         $mdata->{$row_id}{ $tables->{$table}{label} } . ")" );
        }
      }
    }

    if ( $self->{update} == 1 ) {
      $logger->info("Updating existing rows");
      foreach my $row_id ( keys %$mdata ) {
        if ( exists $data->{$row_id} ) {
          if (
             join( '', (
                     map { $mdata->{$row_id}{$_} || '' }
                       @{ $tables->{$table}{cols} } )
             ) ne join(
               '', (
                 map { $data->{$row_id}{$_} || '' } @{ $tables->{$table}{cols} }
               ) ) )
          {
            $helper->execute_update(
               -SQL    => get_update($table),
               -PARAMS => [
                 ( map { $mdata->{$row_id}{$_} } @{ $tables->{$table}{cols} } ),
                 $row_id ] );
            $logger->info( "Updated data for id $row_id (" .
                          $mdata->{$row_id}{ $tables->{$table}{label} } . ")" );
          }
        }
      }
    }

    if ( $self->{delete} == 1 ) {
      $logger->info("Deleting old rows");
      foreach my $row_id ( keys %$data ) {
        if ( !exists $mdata->{$row_id} ) {
          $helper->execute_update( -SQL    => get_delete($table),
                                   -PARAMS => [$row_id] );
          $logger->info( "Deleted data for id $row_id (" .
                         $data->{$row_id}{ $tables->{$table}{label} } . ")" );
        }
      }
    }

    $logger->info( "Completed updating $table for " . $dbc->dbname() );

    return;
  } ## end elsif ( defined $tables->... [ if ( $table eq 'analysis_description')])
  else {
    throw "Do not know how to update table $table";
  }
} ## end sub update_controlled_table

sub backup_table {
  my ( $self, $dbc, $table ) = @_;
  if ( $self->{backup} == 1 ) {
    $logger->info("Backing up $table");
    $dbc->sql_helper->execute_update(
                                  -SQL => "DROP TABLE IF EXISTS ${table}_bak" );
    $dbc->sql_helper->execute_update(
                  -SQL => "CREATE TABLE ${table}_bak AS SELECT * FROM $table" );
  }
  return;
}

sub get_production_table {
  my ( $self, $table ) = @_;
  if ( !defined $self->{$table} ) {
    $logger->info("Retrieving production $table");
    $self->{$table} =
      $self->get_data_from_table( $self->{prod_dba}->dbc(),
                                  get_select($table),
                                  $tables->{$table}{row_id} );
  }
  return $self->{$table};
}

sub get_data_from_table {
  my ( $self, $dbc, $sql, $row_id ) = @_;
  return {
    map { $_->{$row_id} => $_ } @{
      $dbc->sql_helper()->execute( -USE_HASHREFS => 1, -SQL => $sql );
    } };
}

sub get_select {
  my ($table) = @_;
  return 'SELECT ' . join( ',', @{ $tables->{$table}{cols} } ) . ' FROM ' .
    $table;
}

sub get_insert {
  my ($table) = @_;
  return 'INSERT INTO ' . $table . ' (' .
    join( ', ', @{ $tables->{$table}{all_cols} } ) . ') VALUES (' .
    join( ', ', ( map { "?" } @{ $tables->{$table}{all_cols} } ) ) . ')';
}

sub get_update {
  my ($table) = @_;
  return 'UPDATE ' . $table . ' SET ' .
    join( ', ', ( map { "$_ = ?" } @{ $tables->{$table}{cols} } ) ) .
    ' WHERE ' . $tables->{$table}{row_id} . ' = ?';
}

sub get_delete {
  my ($table) = @_;
  return ' DELETE FROM ' . $table . ' WHERE ' . $tables->{$table}{row_id} . ' = ?';
}

1;
