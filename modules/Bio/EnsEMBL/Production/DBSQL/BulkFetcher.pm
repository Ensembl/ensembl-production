=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

  Bio::EnsEMBL::Production::DBSQL::BulkFetcher - library of functions for grabbing big chunks of database

=head1 SYNOPSIS


=head1 DESCRIPTION

  Data-fetching methods for grabbing big chunks of Ensembl for dumping.
  More time-efficient than the normal API. The output is never Ensembl objects.

=cut

package Bio::EnsEMBL::Production::DBSQL::BulkFetcher;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  ( $self->{biotypes}, $self->{level}, $self->{load_xrefs} ) =
    rearrange( [ 'BIOTYPES', 'LEVEL', 'LOAD_XREFS' ], @args );
  $self->{load_xrefs} ||= 0;
  $self->{level}      ||= 'gene';
  return $self;
}

sub export_genes {
  my ( $self, $dba, $biotypes, $level, $load_xrefs ) = @_;

  $biotypes = $self->{biotypes} unless defined $biotypes;
  $level = $self->{level} unless defined $level;
  $load_xrefs = $self->{load_xrefs} unless defined $load_xrefs;

  # query for all genes, hash by ID
  my $genes = $self->get_genes( $dba, $biotypes, $level, $load_xrefs );
  return [ values %$genes ];
}

# Optional third argument lets you specify another table alias for the biotype match
sub _append_biotype_sql {
  my ($self,$sql,$biotypes,$table) = @_;
  $table ||= 'f';
  if ( defined $biotypes && scalar(@$biotypes) > 0 ) {
    $sql .= " AND $table.biotype IN (" .join( ',', map { "'$_'" } @$biotypes ) . ')';
  }
  return $sql;
}

sub get_genes {
  my ( $self, $dba, $biotypes, $level, $load_xrefs ) = @_;

  my @genes;
  my $sql = qq/
  select f.stable_id as id, x.display_label as name, f.description, f.biotype,
  f.seq_region_start as start, f.seq_region_end as end, f.seq_region_strand as strand,
  s.name as seq_region_name
  from gene f
  left join xref x on (f.display_xref_id = x.xref_id)
  join seq_region s using (seq_region_id)
  join coord_system c using (coord_system_id)
  where c.species_id = ? 
  /;
  $sql = $self->_append_biotype_sql($sql,$biotypes);

  my $result = $dba->dbc()->sql_helper()->execute(
    -SQL          => $sql,
    -PARAMS       => [ $dba->species_id() ],
    -USE_HASHREFS => 1, );

  @genes = @$result;

  my $genes_hash = { map { $_->{id} => $_ } @genes };
  # query for all synonyms, hash by gene ID
  my $synonyms = $self->get_synonyms( $dba, $biotypes );
  while ( my ( $gene_id, $synonym ) = each %$synonyms ) {
    $genes_hash->{$gene_id}->{synonyms} = $synonym;
  }
  # add seq_region synonyms
  my $seq_region_synonyms = $self->get_seq_region_synonyms( $dba, 'gene', $biotypes );
  while ( my ( $gene_id, $synonym ) = each %$seq_region_synonyms ) {
    $genes_hash->{$gene_id}->{seq_region_synonyms} = $synonym;
  }
  # add coord_system info
  my $coord_systems = $self->get_coord_systems($dba, 'gene', $biotypes);
  while ( my ( $gene_id, $coord_system ) = each %$coord_systems ) {
    $genes_hash->{$gene_id}->{coord_system} = $coord_system;
  }
  
  if ( $load_xrefs == 1 ) {
    # query for all xrefs, hash by gene ID
    my $xrefs = $self->get_xrefs( $dba, 'gene', $biotypes );
    while ( my ( $gene_id, $xref ) = each %$xrefs ) {
      $genes_hash->{$gene_id}->{xrefs} = $xref;
    }
  }
  if ( $level eq 'transcript' ||
       $level eq 'translation' ||
       $level eq 'protein_feature' )
  {
  # query for transcripts, hash by gene ID
    my $transcripts = $self->get_transcripts( $dba, $biotypes, $level, $load_xrefs );
    while ( my ( $gene_id, $transcript ) = each %$transcripts ) {
      $genes_hash->{$gene_id}->{transcripts} = $transcript;
    }
  }
  return $genes_hash;
}

sub get_transcripts {
  my ( $self, $dba, $biotypes, $level, $load_xrefs ) = @_;

  my $sql = q/
    select g.stable_id as gene_id,
    t.stable_id as id,
    x.display_label as name,
    t.description, 
    t.biotype,
    t.seq_region_start as start, 
    t.seq_region_end as end, 
    t.seq_region_strand as strand,
    s.name as seq_region_name
    FROM 
    gene g
    join transcript t using (gene_id)
    left join xref x on (t.display_xref_id = x.xref_id)
    join seq_region s on (s.seq_region_id = g.seq_region_id)
    join coord_system c using (coord_system_id)
    where c.species_id = ? 
    /;
  $sql = $self->_append_biotype_sql($sql,$biotypes,'t');
  my $xrefs = {};
  if ( $load_xrefs == 1 ) {
    $xrefs = $self->get_xrefs( $dba, 'transcript', $biotypes );
  }

  my $translations = {};
  if ( $level eq 'translation' || $level eq 'protein_feature' ) {
    $translations = $self->get_translations( $dba, $biotypes, $level, $load_xrefs );
  }

  my $seq_region_synonyms = $self->get_seq_region_synonyms( $dba, 'transcript', $biotypes );
  
  my $coord_systems = $self->get_coord_systems($dba, 'transcript', $biotypes);

  my @transcripts = @{
    $dba->dbc()->sql_helper()->execute(
      -SQL => $sql,
      -PARAMS       => [ $dba->species_id() ],
      -USE_HASHREFS => 1,
      -CALLBACK     => sub {
        my ($row) = @_;
        $row->{xrefs}        = $xrefs->{ $row->{id} };
        $row->{translations} = $translations->{ $row->{id} };
        $row->{seq_region_synonyms} = $seq_region_synonyms->{ $row->{id} };
        $row->{coord_system} = $coord_systems->{ $row->{id} };
        return $row;
      } 
    ) 
  };

  my $exon_sql = q/
  SELECT
  t.stable_id AS trans_id,
  e.stable_id AS id,
  s.name as seq_region_name,
  e.seq_region_start as start, 
  e.seq_region_end as end,
  e.seq_region_strand as strand,
  et.rank as rank
  FROM transcript t
  JOIN exon_transcript et ON t.transcript_id = et.`transcript_id`
  JOIN exon e ON et.exon_id = e.`exon_id`
  JOIN seq_region s ON e.seq_region_id = s.seq_region_id
  JOIN coord_system c ON c.coord_system_id = s.coord_system_id
  WHERE c.species_id = ?
  ORDER BY `id`
  /;
  my %exons; # key them off their transcript ID
 
  $dba->dbc->sql_helper->execute(
    -SQL => $exon_sql,
    -PARAMS => [ $dba->species_id ],
    -USE_HASHREFS => 1,
    -CALLBACK => sub{
      my ($row) = @_;
      $row->{coord_system} = $coord_systems->{ $row->{trans_id} }; # borrow coordinate system from relevant transcript

      push @{ $exons{ $row->{trans_id} } }, $row;
    }
  );


  my $transcript_hash = {};
  for my $transcript (@transcripts) {
    push @{ $transcript->{exons} }, @{ $exons{$transcript->{id}} };
    push @{ $transcript_hash->{ $transcript->{gene_id} } }, $transcript;
    delete $transcript_hash->{gene_id};
  }
  return $transcript_hash;
}

sub get_translations {
  my ( $self, $dba, $biotypes, $level, $load_xrefs ) = @_;

  my $sql = q/
    select t.stable_id as transcript_id,
    tl.stable_id as id
    from transcript t
    join translation tl using (transcript_id)
    join seq_region s using (seq_region_id)
    join coord_system c using (coord_system_id)
    where c.species_id = ? 
  /;
  $sql = $self->_append_biotype_sql($sql,$biotypes,'t');
  my $xrefs = {};
  if ( $load_xrefs == 1 ) {
    $xrefs = $self->get_xrefs( $dba, 'translation', $biotypes );
  }

  # add protein features
  my $protein_features = {};
  if ( $level eq 'protein_feature' ) {
    $protein_features = $self->get_protein_features( $dba, $biotypes );
  }

  my @translations = @{
  $dba->dbc()->sql_helper()->execute(
    -SQL          => $sql,
    -PARAMS       => [ $dba->species_id() ],
    -USE_HASHREFS => 1,
    -CALLBACK     => sub {
      my ($row) = @_;
      $row->{xrefs}            = $xrefs->{ $row->{id} };
      $row->{protein_features} = $protein_features->{ $row->{id} };
      return $row;
    } ) };

  my $translation_hash = {};
  for my $translation (@translations) {
    push @{ $translation_hash->{ $translation->{transcript_id} } }, $translation;
    delete $translation_hash->{transcript_id};
  }
  return $translation_hash;
}


sub get_protein_features {
  my ( $self, $dba, $biotypes ) = @_;

  my $sql = q/
    select
    tl.stable_id as translation_id,
    pf.hit_name as name,
    pf.hit_description as description,
    pf.seq_start as start,
    pf.seq_end as end,
    a.db as dbname,
    i.interpro_ac
    from transcript t
    join translation tl using (transcript_id)
    join protein_feature pf using (translation_id)
    join analysis a on (a.analysis_id = pf.analysis_id)
    left join interpro i on (pf.hit_name = i.id)
    join seq_region s using (seq_region_id)
    join coord_system c using (coord_system_id)
    where c.species_id = ? 
  /;
  $self->_append_biotype_sql($sql,$biotypes,'t');

  my @protein_features = @{
  $dba->dbc()->sql_helper()->execute(
    -SQL => $sql,
    -PARAMS       => [ $dba->species_id() ],
    -USE_HASHREFS => 1 ) };

  my $pf_hash = {};
  for my $protein_feature (@protein_features) {
    push @{ $pf_hash->{ $protein_feature->{translation_id} } }, $protein_feature;
    delete $pf_hash->{translation_id};
  }
  return $pf_hash;
}

sub _generate_xref_sql {
  my ($self,$table_name)= @_;
  my $Table_name = ucfirst($table_name);
  my $other_table_name = $table_name; # for translation joins on object_xref, otherwise invisible
  my $table_alias = 'f';
  my $translation_join = '';
  if ($table_name eq 'translation') {
    $table_alias = 'tl';
    $table_name = 'transcript';
    $translation_join = 'JOIN translation tl USING (transcript_id)'
  }
  my $sql = qq/
      SELECT ${table_alias}.stable_id AS id, x.dbprimary_acc, x.display_label, e.db_name, x.description, x.info_type, x.info_text
      FROM ${table_name} f
      ${translation_join}
      JOIN object_xref ox         ON (${table_alias}.${other_table_name}_id = ox.ensembl_id AND ox.ensembl_object_type = '${Table_name}')
      JOIN xref x                 USING (xref_id)
      JOIN external_db e          USING (external_db_id)
      JOIN seq_region s           USING (seq_region_id)
      JOIN coord_system c         USING (coord_system_id)
      LEFT JOIN ontology_xref oox USING (object_xref_id)
      WHERE c.species_id = ? AND oox.object_xref_id is null 
    /;
  return $sql;
}

sub _generate_object_xref_sql {
  my ($self,$table_name)= @_;
  my $other_table_name = $table_name; # for translation case
  my $Table_name = ucfirst($table_name);
  my $table_alias = 'f';
  my $select_alias = $table_alias;
  my $translation_join = '';
  if ($table_name eq 'translation') {
    $table_name = 'transcript';
    $select_alias = 'tl';
    $translation_join = 'JOIN translation tl USING (transcript_id)';
  }
  my $sql = qq/ 
    SELECT ox.object_xref_id, ${select_alias}.stable_id AS id, x.dbprimary_acc, x.display_label, e.db_name, x.description, 
           oox.linkage_type, sx.dbprimary_acc, sx.display_label, sx.description, se.db_name
      FROM ${table_name} ${table_alias}
      ${translation_join}
      JOIN object_xref ox      ON (${select_alias}.${other_table_name}_id=ox.ensembl_id AND ox.ensembl_object_type='${Table_name}')
      JOIN xref x              USING (xref_id)
      JOIN external_db e       USING (external_db_id)
      JOIN seq_region s        USING (seq_region_id)
      JOIN coord_system c      USING (coord_system_id)
      JOIN ontology_xref oox   USING (object_xref_id)
      LEFT JOIN xref sx        ON (oox.source_xref_id = sx.xref_id)
      LEFT JOIN external_db se ON (se.external_db_id = sx.external_db_id)
      WHERE c.species_id = ? 
  /;
  return $sql;
}

sub _generate_associated_xref_sql {
  my ($self,$table_name) = @_;
  my $Table_name = ucfirst($table_name);
  my $table_alias = 'f';
  my $root_table_name = $table_name;
  my $translation_join = '';
  if ($table_name eq 'translation') {
    $table_alias = 'tl';
    $root_table_name = 'transcript';
    $translation_join = 'JOIN translation tl USING (transcript_id)';
  }

  my $sql = qq/
    SELECT ax.object_xref_id, ax.rank, ax.condition_type, x.dbprimary_acc, x.display_label, xe.db_name, x.description, 
           sx.dbprimary_acc, sx.display_label, se.db_name, sx.description, ax.associated_group_id 
      FROM ${root_table_name} f
      ${translation_join}
      JOIN object_xref ox     ON (${table_alias}.${table_name}_id = ox.ensembl_id AND ox.ensembl_object_type = '${Table_name}')
      JOIN associated_xref ax USING (object_xref_id) 
      JOIN xref x             ON (x.xref_id = ax.xref_id) 
      JOIN external_db xe     ON (x.external_db_id = xe.external_db_id) 
      JOIN xref sx            ON (sx.xref_id = ax.source_xref_id) 
      JOIN external_db se     ON (se.external_db_id = sx.external_db_id) 
      JOIN seq_region s       USING (seq_region_id)
      JOIN coord_system c     USING (coord_system_id)
      WHERE c.species_id=? 
  /;
  return $sql;
}


# Creates:
# $xrefs->{ stable_id => [ { primary_id => xref accession, display_id => display_label, dbname => , description =>  }, ... ] }
# $oox->{ object_xref_id => { obj_id => stable_id, primary_id => xref accession, display_id => display_label, dbname => , description => 
#                             linkage_types => [ { evidence => linkage_type, source => { primary_id , display_id, dbname , description}} ... ],
#                             associated_xrefs => { associated_group_id => { condition_type => { rank , dbprimary_acc , display_label , dbname, description, source => { dbprimary_acc , display_id, dbname, description } }
#                                                                         }
#                                                }
#                           }
#       }

sub get_xrefs {
  my ( $self, $dba, $type, $biotypes ) = @_;

  my $sql = $self->_generate_xref_sql($type);
  $sql = $self->_append_biotype_sql($sql,$biotypes,$type);
  my $oox_sql = $self->_generate_object_xref_sql($type);
  $oox_sql = $self->_append_biotype_sql($oox_sql,$biotypes,$type);
  my $ax_sql = $self->_generate_associated_xref_sql($type);
  $ax_sql = $self->_append_biotype_sql($ax_sql,$biotypes,$type);
  
  my $xrefs = {};
  $dba->dbc()->sql_helper()->execute_no_return(
    -SQL      => $sql,
    -PARAMS   => [ $dba->species_id() ],
    -CALLBACK => sub {
      my ($row) = @_;
      my ($stable_id, $dbprimary_acc, $display_label, $db_name, $description, $info_type, $info_text) = @$row;
      push @{ $xrefs->{ $stable_id } }, {
        primary_id => $dbprimary_acc,
        display_id => $display_label,
        dbname     => $db_name,
        description=> $description,
        info_type => $info_type,
        info_text => $info_text
      };
      return;
    } 
  );
  # now handle oox
  my $oox_xrefs = {};
  $dba->dbc()->sql_helper()->execute_no_return(
    -SQL      => $oox_sql,
    -PARAMS   => [ $dba->species_id() ],
    -CALLBACK => sub {
      my ($row) = @_;
      my ($ox_id,$stable_id,$dbprimary_acc,$display_label,$db_name,$description,$linkage_type,$other_dbprimary_acc,$other_display_label,$other_description,$other_dbname) = @$row;
      my $xref = $oox_xrefs->{ $ox_id };
      if ( !defined $xref ) {
        $xref = { obj_id      => $stable_id,
                  primary_id  => $dbprimary_acc,
                  display_id  => $display_label,
                  dbname      => $db_name,
                  description => $description,
                };
        $oox_xrefs->{ $ox_id } = $xref;
      }
      # add linkage type to $xref
      push @{ $xref->{linkage_types} }, {
        evidence => $linkage_type,
        source   => {
          primary_id  => $other_dbprimary_acc,
          display_id  => $other_display_label,
          dbname      => $other_dbname,
          description => $other_description,
        }
      };
      return;
    } 
  );

  # add associated_xrefs to $oox_xrefs
  $dba->dbc()->sql_helper()->execute_no_return(
    -SQL      => $ax_sql,
    -PARAMS   => [ $dba->species_id() ],
    -CALLBACK => sub {
      my ($row) = @_;
      my ($associated_ox_id,$associated_rank,$associated_condition,$dbprimary_acc,$display_label,$db_name,$description,$other_dbprimary_acc,$other_display_label,$other_db_name,$other_description,$associated_group_id) = @$row;
      my $xref = $oox_xrefs->{ $associated_ox_id };
      # add linkage type to $xref
      $xref->{associated_xrefs}->{ $associated_group_id }->{ $associated_condition } = {
        rank       => $associated_rank,
        primary_id => $dbprimary_acc,
        display_id => $display_label,
        dbname     => $db_name,
        description=> $description,
        source     => {
          primary_id  => $other_dbprimary_acc,
          display_id  => $other_display_label,
          dbname      => $other_db_name,
          description => $other_description,
        } 
      };
      return;
    } 
  );

  # collate everything, remove some uninteresting keys,
  for my $xref ( values %{$oox_xrefs} ) {
    $xref->{associated_xrefs} = [values %{ $xref->{associated_xrefs} }];
    push @{ $xrefs->{ $xref->{obj_id} } }, $xref;
    delete $xref->{obj_id};
  }

  return $xrefs;

}


sub get_coord_systems {
  my ( $self, $dba, $type, $biotypes ) = @_;
  my $sql = qq/
    select g.stable_id as id, c.name, c.version
    from $type g
    join seq_region s using (seq_region_id)
    join coord_system c using (coord_system_id)
    where c.species_id = ? 
  /;
  $sql = $self->_append_biotype_sql($sql,$biotypes);

  my $coord_systems = {};

  $dba->dbc()->sql_helper()->execute_no_return(
  -SQL      => $sql,
  -PARAMS   => [ $dba->species_id() ],
  -CALLBACK => sub {
    my ($row) = @_;
    $coord_systems->{ $row->[0] } = {name=>$row->[1], version=>$row->[2]};
    return;
  } );
  return $coord_systems;
}

sub get_synonyms {
  my ( $self, $dba, $biotypes ) = @_;
  my $sql = q/
    select g.stable_id as id, e.synonym
    from gene g
    join external_synonym e on (g.display_xref_id = e.xref_id)
    join seq_region s using (seq_region_id)
    join coord_system c using (coord_system_id)
    where c.species_id = ? 
  /;
  $sql = $self->_append_biotype_sql($sql,$biotypes);
  my $synonyms = {};
  $dba->dbc()->sql_helper()->execute_no_return(
  -SQL => $sql,
  -PARAMS   => [ $dba->species_id() ],
  -CALLBACK => sub {
    my ($row) = @_;
    push @{ $synonyms->{ $row->[0] } }, $row->[1];
    return;
  } );
  return $synonyms;
}

sub get_seq_region_synonyms {
  my ( $self, $dba, $type, $biotypes ) = @_;
  my $sql = qq/
    select g.stable_id as id, sr.synonym as synonym, e.db_name as db 
    from $type g
    join seq_region_synonym sr using (seq_region_id)
    join seq_region s using (seq_region_id)
    join coord_system c using (coord_system_id)
    left join external_db e using (external_db_id)
    where c.species_id = ? 
  /;
  $sql = $self->_append_biotype_sql($sql,$biotypes);
  my $synonyms = {};
  $dba->dbc()->sql_helper()->execute_no_return(
  -SQL => $sql,
  -PARAMS   => [ $dba->species_id() ],
  -CALLBACK => sub {
    my ($row) = @_;
    push @{ $synonyms->{ $row->[0] } }, {id=>$row->[1], db=>$row->[2]};
    return;
  } );
  return $synonyms;
} 

sub add_compara {
  my ( $self, $species, $genes, $compara_dba ) = @_;
  my $homologues = {};
  print "Querying Compara\n";
  $compara_dba->dbc()->sql_helper()->execute_no_return(
  -SQL => q/
SELECT gm1.stable_id, gm2.stable_id, g2.name, h.description
FROM homology_member hm1
 INNER JOIN homology_member hm2 ON (hm1.homology_id = hm2.homology_id)
 INNER JOIN homology h ON (hm1.homology_id = h.homology_id)
 INNER JOIN gene_member gm1 ON (hm1.gene_member_id = gm1.gene_member_id)
 INNER JOIN gene_member gm2 ON (hm2.gene_member_id = gm2.gene_member_id)
 INNER JOIN genome_db g ON (gm1.genome_db_id = g.genome_db_id)
 INNER JOIN genome_db g2 ON (gm2.genome_db_id = g2.genome_db_id)
WHERE (hm1.gene_member_id <> hm2.gene_member_id)
 AND (gm1.stable_id <> gm2.stable_id)
 AND (g.name = ?)
 AND (gm1.source_name = 'ENSEMBLGENE')/,
  -CALLBACK => sub {
    my ($row) = @_;
    push @{ $homologues->{ $row->[0] } },
    { stable_id   => $row->[1],
      genome      => $row->[2],
      description => $row->[3] };
    return;
  },
  -PARAMS => [$species] );

  for my $gene ( @{$genes} ) {
    if(!defined $gene->{id}) {
      throw("No stable ID for gene");
    }
    my $homo = $homologues->{ $gene->{id} };
    if ( defined $homo ) {
      $gene->{homologues} = $homo;
    }
  }
  print "Homology integrated into gene hash\n";
  return;
}



1;