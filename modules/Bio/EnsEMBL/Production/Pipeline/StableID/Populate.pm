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
Bio::EnsEMBL::Production::Pipeline::StableID::Populate

=head1 DESCRIPTION
Add stable IDs from a core or otherfeatures database to the
ensembl_stable_ids database.

=cut

package Bio::EnsEMBL::Production::Pipeline::StableID::Populate;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Bio::EnsEMBL::Utils::URI qw/parse_uri/;

sub param_defaults {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::param_defaults},

    archive_id_objects => {
      core => [ qw/ Gene Transcript Translation / ]
    },

    stable_id_objects => {
      core => [ qw/ Exon Gene Transcript Translation Operon RNAProduct / ],
      otherfeatures => [ qw/ Gene Transcript Translation / ]
    },
  };
}

sub pre_cleanup {
  my ($self) = @_;

  $self->process_db('delete');
}

sub run {
  my ($self) = @_;

  $self->process_db('load');
}

sub process_db {
  my ($self, $action) = @_;

  my $db_url  = $self->param_required('db_url');
  my $species = $self->param_required('species');
  my $group   = $self->param_required('group');

  my $uri = parse_uri($db_url);
  my $stable_ids_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host   => $uri->host,
    -port   => $uri->port,
    -user   => $uri->user,
    -pass   => $uri->pass,
    -dbname => $uri->db_params->{dbname},
  );
  my $dba = $self->get_DBAdaptor($group);

  if ($dba->is_multispecies) {
    my $original_dba = $dba;

    my $sql = qq/
      SELECT meta_value, species_id FROM meta
      WHERE meta_key = 'species.db_name'
    /;
    my $helper = $original_dba->dbc->sql_helper;
    my %species_ids = %{ $helper->execute_into_hash(-SQL => $sql) };

    foreach $species (@{$original_dba->all_species}) {
      $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -dbconn          => $original_dba->dbc,
        -multispecies_db => 1,
        -species         => $species,
        -species_id      => $species_ids{$species},
      );

      $self->load_stable_ids($stable_ids_dba, $species, $group, $dba, $action);

      $dba->dbc->disconnect_if_idle();
    }
  } else {
    $self->load_stable_ids($stable_ids_dba, $species, $group, $dba, $action);

    $dba->dbc->disconnect_if_idle();
  }

  $stable_ids_dba->dbc->disconnect_if_idle();
}

sub load_stable_ids {
  my ($self, $stable_ids_dba, $species, $group, $dba, $action) = @_;

  my $incremental = $self->param_required('incremental');

  # Note that the "species_id" here is the auto-increment field in the
  # stable ID database's "species" table, not to be confused with the
  # core database's "species_id" in "meta" and "coord_system" tables.
  my $species_id = $self->fetch_species_id($stable_ids_dba, $species);
  if (! defined $species_id) {
    my $mca = $dba->get_adaptor('MetaContainer');
    my $tax_id = $mca->get_taxonomy_id();
    $species_id = $self->insert_species($stable_ids_dba, $species, $tax_id);
  }

  if ($action eq 'delete' || $incremental) {
    if ($group eq 'core') {
      $self->delete_lookup($stable_ids_dba, $species_id, $group, 'archive_id_lookup');
    }
    $self->delete_lookup($stable_ids_dba, $species_id, $group, 'stable_id_lookup');
  }

  if ($action eq 'load') {
    if ($group eq 'core') {
      $self->insert_archive_ids($stable_ids_dba, $species_id, $dba, $group);
    }
    $self->insert_stable_ids($stable_ids_dba, $species_id, $dba, $group);
  }
}

sub fetch_species_id {
  my ($self, $stable_ids_dba, $species) = @_;

  my $sql = 'SELECT species_id FROM species WHERE name = ?';
  my $species_id = $stable_ids_dba->dbc->sql_helper->execute_single_result(
    -SQL => $sql,
    -PARAMS => [$species],
    -NO_ERROR => 1
  );

  return $species_id;
}

sub insert_species {
  my ($self, $stable_ids_dba, $species, $tax_id) = @_;

  my $sql = qq/
    INSERT INTO species (name, taxonomy_id)
    VALUES (?, ?)
  /;
  $stable_ids_dba->dbc->sql_helper->execute_update(
    -SQL    => $sql,
    -PARAMS => [$species, $tax_id]
  );

  return $self->fetch_species_id($stable_ids_dba, $species);
}

sub delete_lookup {
  my ($self, $stable_ids_dba, $species_id, $group, $table) = @_;

  my $delete_sql = qq/
    DELETE FROM $table
    WHERE species_id = ? AND db_type = ?
  /;
  $stable_ids_dba->dbc->sql_helper->execute_update(
    -SQL    => $delete_sql,
    -PARAMS => [$species_id, $group]
  );
}

sub insert_archive_ids {
  my ($self, $stable_ids_dba, $species_id, $dba, $group) = @_;

  my $archive_id_objects = $self->param_required('archive_id_objects');
  my $objects = $$archive_id_objects{$group};

  my $insert_sql = qq/
    INSERT INTO archive_id_lookup
      (archive_id, species_id, db_type, object_type)
    VALUES 
  /;
  
  foreach my $object_name (@$objects) {
    my $object = lc($object_name);

    my $select_sql = qq/
      SELECT DISTINCT
        old_stable_id, $species_id, '$group', type
      FROM
        stable_id_event
      WHERE
        old_stable_id IS NOT NULL AND
        type = '$object' AND
        old_stable_id NOT IN (SELECT stable_id FROM $object)
    /;

    $self->batch_insert($dba, $select_sql, $stable_ids_dba, $insert_sql);
  }
}

sub insert_stable_ids {
  my ($self, $stable_ids_dba, $species_id, $dba, $group) = @_;

  my $cs_species_id = $dba->species_id();

  my $stable_id_objects = $self->param_required('stable_id_objects');
  my $objects = $$stable_id_objects{$group};

  my $insert_sql = qq/
    INSERT INTO stable_id_lookup
      (stable_id, species_id, db_type, object_type)
    VALUES 
  /;

  foreach my $object_name (@$objects) {
    my $table = lc($object_name);

    my $sql = "SELECT COUNT(*) FROM $table";
    my $count = $dba->dbc->sql_helper->execute_single_result(-SQL => $sql);
    if ($count) {
      my $transcript_table = '';
      my $analysis_table = '';
      my $analysis_where = '';
      
      if ($object_name eq 'RNAProduct' || $object_name eq 'Translation') {
        $transcript_table = 'transcript USING (transcript_id) INNER JOIN';
      }
      if ($group eq 'otherfeatures') {
        $analysis_table = 'analysis USING (analysis_id) INNER JOIN';
        $analysis_where = 'AND logic_name LIKE "refseq_%" OR logic_name LIKE "ccds_%"';
      }

      my $select_sql = qq/
        SELECT DISTINCT
          t.stable_id, $species_id, '$group', '$object_name'
        FROM
          $table t INNER JOIN
          $transcript_table
          $analysis_table
          seq_region USING (seq_region_id) INNER JOIN
          coord_system USING (coord_system_id)
        WHERE
          t.stable_id IS NOT NULL AND
          coord_system.species_id = $cs_species_id
          $analysis_where
      /;

      $self->batch_insert($dba, $select_sql, $stable_ids_dba, $insert_sql);
    }
  }
}

sub batch_insert {
  my ($self, $dba, $select_sql, $stable_ids_dba, $insert_sql) = @_;

  my $batch_size = 100000;

  my $dbh = $dba->dbc->db_handle;
  my $sth = $dbh->prepare($select_sql);

  $sth->execute;

  my @insert_values = ();
  while (my $row = $sth->fetchrow_arrayref) {
    my $insert_values = '(' . join( ",", map { $dbh->quote($_) } @$row ) . ')';
    push @insert_values, $insert_values;

    if (scalar(@insert_values) >= $batch_size) {
      my $insert_sql_with_values = $insert_sql . join(',', @insert_values);

      $stable_ids_dba->dbc->sql_helper->execute_update(
        -SQL => $insert_sql_with_values
      );

      @insert_values = ();
    }
  }

  if (scalar(@insert_values)) {
    my $insert_sql_with_values = $insert_sql . join(',', @insert_values);

    $stable_ids_dba->dbc->sql_helper->execute_update(
      -SQL => $insert_sql_with_values
    );
  }
}

1;
