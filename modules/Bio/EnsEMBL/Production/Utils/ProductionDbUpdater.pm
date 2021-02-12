=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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
                      
  $updater->update_controlled_tables($dbc, $tables);

=head1 DESCRIPTION

  Utility for updating a database from the Ensembl production database

=cut

package Bio::EnsEMBL::Production::Utils::ProductionDbUpdater;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  ( $self->{prod_dba}, $self->{insert},
    $self->{update},   $self->{delete} )
    = rearrange( [ 'PRODUCTION_DBA', 'INSERT', 'UPDATE', 'DELETE' ],
                 @args );
  if ( !defined $self->{prod_dba} ) {
    die "-PRODUCTION_DBA not specified";
  }
  $self->{insert} ||= 1;
  $self->{update} ||= 1;
  $self->{delete} ||= 1;
  return $self;
}

# definition of supported tables
my $tables = {
  attrib_type => {
    cols     => [qw/attrib_type_id code name description/],
    all_cols => [qw/attrib_type_id code name description/],
    row_id   => 'attrib_type_id' },

  attrib => {
    cols     => [qw/attrib_id attrib_type_id value/],
    all_cols => [qw/attrib_id attrib_type_id value/],
    row_id   => 'attrib_id' },

  attrib_set => {
    cols     => [qw/attrib_set_id attrib_id/],
    all_cols => [qw/attrib_set_id attrib_id/],
    row_id   => 'attrib_set_id' },

  biotype => {
    cols     => [qw/biotype_id name object_type db_type attrib_type_id description biotype_group so_acc so_term/],
    all_cols => [qw/biotype_id name object_type db_type attrib_type_id description biotype_group so_acc so_term/],
    row_id   => 'biotype_id' },

  external_db => {
    cols  => [
      qw/external_db_id db_name status priority db_display_name type secondary_db_name secondary_db_table description/
    ],
    all_cols => [
      qw/db_release external_db_id db_name status priority db_display_name type secondary_db_name secondary_db_table description/
    ],
    row_id => 'external_db_id' },

  misc_set => {
    cols     => [qw/misc_set_id code name description max_length/],
    all_cols => [qw/misc_set_id code name description max_length/],
    row_id   => 'misc_set_id' },

  unmapped_reason => {
    cols     => [qw/unmapped_reason_id summary_description full_description/],
    all_cols => [qw/unmapped_reason_id summary_description full_description/],
    row_id   => 'unmapped_reason_id' }
};

sub update_controlled_tables {
  my ( $self, $dbc, $tables ) = @_;

  for my $table (@$tables) {
    $self->update_controlled_table( $dbc, $table );
  }
}

sub update_controlled_table {
  my ( $self, $dbc, $table ) = @_;

  if ( defined $tables->{$table} ) {
    my $helper = $dbc->sql_helper();

    my $mdata = $self->get_production_table($table);
    my $data =
      $self->get_data_from_table( $dbc, get_select($table),
                                  $tables->{$table}{row_id} );

    if ( $self->{insert} == 1 ) {
      foreach my $row_id ( keys %$mdata ) {
        if ( !exists $data->{$row_id} ) {
          $helper->execute_update(
              -SQL    => get_insert($table),
              -PARAMS => [
                map { $mdata->{$row_id}{$_} } @{ $tables->{$table}{all_cols} }
              ] );
        }
      }
    }

    if ( $self->{update} == 1 ) {
      foreach my $row_id ( keys %$mdata ) {
        if ( exists $data->{$row_id} ) {
          # Only update if the data is not already the same.
          if (
              join(
                '',
                map { defined $mdata->{$row_id}{$_} ? $mdata->{$row_id}{$_} : 'undef' } @{ $tables->{$table}{cols} }
              )
              ne
              join(
                '',
                map { defined $data->{$row_id}{$_} ? $data->{$row_id}{$_} : 'undef' } @{ $tables->{$table}{cols} }
              )
            )
          {
            $helper->execute_update(
                -SQL    => get_update($table),
                -PARAMS => [
                  (map { $mdata->{$row_id}{$_} } @{ $tables->{$table}{cols} } ), $row_id
                ] );
          }
        }
      }
    }

    if ( $self->{delete} == 1 ) {
      foreach my $row_id ( keys %$data ) {
        if ( !exists $mdata->{$row_id} ) {
          $helper->execute_update( -SQL    => get_delete($table),
                                   -PARAMS => [$row_id] );
        }
      }
    }
  } else {
    die "Do not know how to update table $table";
  }
}

sub update_analysis_description {
  my ( $self, $dbc ) = @_;

  my $prod_select_sql = qq/
    SELECT
      ad.logic_name, ad.description, ad.display_label, ad.displayable, wd.data as web_data
    FROM
      analysis_description ad LEFT OUTER JOIN
      web_data wd USING (web_data_id)
  /;
  my $core_select_sql = qq/
    SELECT logic_name FROM analysis
  /;
  my $core_delete_sql = qq/
    DELETE FROM analysis_description
  /;
  my $core_insert_sql = qq/
    INSERT INTO analysis_description
      (analysis_id, description, display_label, displayable, web_data)
    SELECT analysis_id, ?, ?, ?, ?
    FROM analysis
    WHERE logic_name = ?
  /;

  my $analyses = $self->get_data_from_table(
    $self->{prod_dba}->dbc(), $prod_select_sql, 'logic_name' );

  my $logic_names =
    $dbc->sql_helper()->execute_simple( -SQL => $core_select_sql );

  $dbc->sql_helper()->execute_update( -SQL => $core_delete_sql );

  foreach my $logic_name (@$logic_names) {
    if ( exists $analyses->{$logic_name} ) {
      my $analysis = $analyses->{$logic_name};
      $dbc->sql_helper()->execute_update(
        -SQL => $core_insert_sql,
        -PARAMS => [ $analysis->{description}, $analysis->{display_label},
                     $analysis->{displayable}, $analysis->{web_data},
                     $logic_name ] );
    }
  }
}

sub get_production_table {
  my ( $self, $table ) = @_;
  if ( !defined $self->{$table} ) {
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
