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

use Log::Log4perl qw/get_logger/;

my $log = get_logger();

sub new {
    my ($class, @args) = @_;
    my $self = bless({}, ref($class) || $class);
    ($self->{biotypes}, $self->{level}, $self->{load_xrefs}) =
        rearrange([ 'BIOTYPES', 'LEVEL', 'LOAD_XREFS' ], @args);
    $self->{load_xrefs} ||= 0;
    $self->{level} ||= 'gene';
    return $self;
}

sub export_genes {

    my ($self, $dba, $biotypes, $level, $load_xrefs) = @_;

    $biotypes = $self->{biotypes} unless defined $biotypes;
    $level = $self->{level} unless defined $level;
    $load_xrefs = $self->{load_xrefs} unless defined $load_xrefs;

    # query for all genes, hash by ID
    $log->info("Exporting genes for " . $dba->species());
    my $genes = $self->get_genes($dba, $biotypes, $level, $load_xrefs);
    my @genes_l = values %$genes;
    $log->info("Completed exporting " . scalar(@genes_l) . " genes for " . $dba->species());
    return \@genes_l;
}

# Optional third argument lets you specify another table alias for the biotype match
sub _append_biotype_sql {
    my ($self, $sql, $biotypes, $table) = @_;
    $table ||= 'f';
    if (defined $biotypes && scalar(@$biotypes) > 0) {
        $sql .= " AND $table.biotype IN (" . join(',', map {"'$_'"} @$biotypes) . ')';
    }
    return $sql;
}

sub _append_analysis_sql {
    my ($self, $dba, $sql, $table) = @_;
    my $analysis_ids = $dba->dbc()->sql_helper()->execute_simple(
        -SQL => q/select analysis_id from analysis_description where web_data rlike '"gene" *: *{"do_not_display" *: *"1"}'/
    );
    if (scalar @{$analysis_ids} > 0) {
        $sql .= ' and ' . $table . '.analysis_id not in (' . join(',', @$analysis_ids) . ')';
    }
    return $sql;
}

sub get_genes {
    my ($self, $dba, $biotypes, $level, $load_xrefs) = @_;

    my $genes_hash = {};

    {
        my $sql = qq/
  select ifnull(f.stable_id,f.gene_id) as id, f.version as version, x.display_label as name, f.description, f.biotype, f.source,
  f.seq_region_start as start, f.seq_region_end as end, f.seq_region_strand as strand,
  s.name as seq_region_name,
  'gene' as ensembl_object_type,
  a.logic_name as analysis,
  ad.display_label as analysis_display, 
  b.so_term as so_term
  from gene f
  left join xref x on (f.display_xref_id = x.xref_id)
  join seq_region s using (seq_region_id)
  join coord_system c using (coord_system_id)
  join analysis a using (analysis_id)
  left join analysis_description ad using (analysis_id) 
  left join biotype b on  b.name = f.biotype  and b.object_type='gene'
  where c.species_id = ?
  /;

        $sql = $self->_append_biotype_sql($sql, $biotypes);
        $sql = $self->_append_analysis_sql($dba, $sql, 'f');
        $log->debug("Retrieving genes");
        $log->trace($sql);
        my @genes =
            @{$dba->dbc()->sql_helper()->execute(-SQL => $sql,
                -PARAMS                               => [ $dba->species_id() ],

                -USE_HASHREFS                         => 1,)};
        $log->debug("Retrieved " . scalar(@genes) . " genes");

        # turn into hash
        $genes_hash = { map {$_->{id} => $_} @genes };

    }

    $log->debug("Found " . scalar(values %{$genes_hash}) . " gene IDs");

    if (scalar(values %{$genes_hash}) > 0) {

        $log->debug("Adding synonyms");
        # query for all synonyms, hash by gene ID
        my $synonyms = $self->get_synonyms($dba, $biotypes);
        while (my ($gene_id, $synonym) = each %$synonyms) {
            $genes_hash->{$gene_id}->{synonyms} = $synonym;
        }
        $log->debug("Adding seq_region synonyms");
        # add seq_region synonyms
        my $seq_region_synonyms = $self->get_seq_region_synonyms($dba, 'gene', $biotypes);
        while (my ($gene_id, $synonym) = each %$seq_region_synonyms) {
            $genes_hash->{$gene_id}->{seq_region_synonyms} = $synonym;
        }
        $log->debug("Adding haplotypes");
        # add haplotypes
        my $haplotypes = $self->get_haplotypes($dba, 'gene', $biotypes);
        while (my ($gene_id, $synonym) = each %$haplotypes) {
            $genes_hash->{$gene_id}->{is_haplotype} = 1;
        }
        $log->debug("Adding coord_systems");
        # add coord_system info
        my $coord_systems = $self->get_coord_systems($dba, 'gene', $biotypes);
        while (my ($gene_id, $coord_system) = each %$coord_systems) {
            $genes_hash->{$gene_id}->{coord_system} = $coord_system;
        }
        $log->debug("Adding stable IDs");
        # add stable_ids
        my $ids = $self->get_stable_ids($dba, 'gene');
        while (my ($gene_id, $old_ids) = each %{$ids}) {
            $genes_hash->{$gene_id}->{previous_ids} = $old_ids;
        }

        if ($load_xrefs == 1) {
            $log->debug("Adding xrefs");
            # query for all xrefs, hash by gene ID
            my $xrefs = $self->get_xrefs($dba, 'gene', $biotypes);
            while (my ($gene_id, $xref) = each %$xrefs) {
                $genes_hash->{$gene_id}->{xrefs} = $xref;
            }
        }
        if ($level eq 'transcript' ||
            $level eq 'translation' ||
            $level eq 'protein_feature') {
            $log->debug("Adding transcripts");
            # query for transcripts, hash by gene ID
            my $transcripts = $self->get_transcripts($dba, $biotypes, $level, $load_xrefs);
            $log->debug("Found transcripts for " . scalar(values %{$transcripts}) . " gene IDs");
            while (my ($gene_id, $transcript) = each %$transcripts) {
                my $g = $genes_hash->{$gene_id};
                if (defined $g) {
                    $g->{transcripts} = $transcript;
                }
            }
        }
    }
    return $genes_hash;
} ## end sub get_genes

sub get_transcripts {
    my ($self, $dba, $biotypes, $level, $load_xrefs) = @_;

    my $sql = q/
    select ifnull(g.stable_id, g.gene_id) as gene_id,
    ifnull(t.stable_id,t.transcript_id) as id,
    t.version as version,
    x.display_label as name,
    t.description, 
    t.biotype,
    t.seq_region_start as start, 
    t.seq_region_end as end, 
    t.seq_region_strand as strand,
    s.name as seq_region_name,
    'transcript' as ensembl_object_type,
    a.logic_name as analysis,
    ad.display_label as analysis_display,
    b.so_term 
    FROM 
    gene g
    join transcript t using (gene_id)
    left join xref x on (t.display_xref_id = x.xref_id)
    join seq_region s on (s.seq_region_id = g.seq_region_id)
    join coord_system c using (coord_system_id)
    join analysis a on (t.analysis_id=a.analysis_id)
    left join analysis_description ad on (a.analysis_id=ad.analysis_id) 
    left join biotype b on b.name = t.biotype and b.object_type='transcript' 
    where c.species_id = ?
    /;
    $sql = $self->_append_biotype_sql($sql, $biotypes, 't');
    $sql = $self->_append_analysis_sql($dba, $sql, 't');

    my $transcripts = {};
    $log->debug("Retrieving transcripts");
    $log->trace($sql);

    $dba->dbc()->sql_helper()->execute_no_return(
        -SQL          => $sql,
        -PARAMS       => [ $dba->species_id() ],
        -USE_HASHREFS => 1,
        -CALLBACK     => sub {
            my ($row) = @_;
            $transcripts->{$row->{id}} = $row;
            $transcripts->{$row->{id}}{translations} = [];
            return;
        });

    if ($load_xrefs == 1) {
        $log->debug("Getting xrefs for transcripts");
        my $xrefs = $self->get_xrefs($dba, 'transcript', $biotypes);
        while (my ($id, $xref) = each %{$xrefs}) {
            $transcripts->{$id}->{xrefs} = $xref;
        }
    }

    if ($level eq 'translation' || $level eq 'protein_feature') {
        $log->debug("Getting translations for transcripts");
        my $t = $self->get_translations($dba, $biotypes, $level, $load_xrefs);
        while (my ($id, $translation) = each %{$t}) {
            $transcripts->{$id}{translations} = $translation;
        }
    }

    {
        $log->debug("Getting seq_region synonyms for transcripts");
        my $srss = $self->get_seq_region_synonyms($dba, 'transcript', $biotypes);
        while (my ($id, $srs) = each %{$srss}) {
            $transcripts->{$id}->{seq_region_synonyms} = $srs;
        }
    }

    {
        $log->debug("Getting coord_systems for transcripts");
        my $css = $self->get_coord_systems($dba, 'transcript', $biotypes);
        while (my ($id, $cs) = each %{$css}) {
            $transcripts->{$id}->{coord_system} = $cs;
        }
    }

    {

        my $exons_list = {};
        my $current_transcript_id = '';  
        my $exon_sql = q/
		SELECT
		ifnull(t.stable_id, t.transcript_id) AS trans_id,
		ifnull(e.stable_id, e.exon_id) AS id,
		e.version AS version,
		s.name as seq_region_name,
		e.seq_region_start as start, 
		e.seq_region_end as end,
		e.seq_region_strand as strand,
		et.rank as rank,
		'exon' as ensembl_object_type
		FROM transcript t
		JOIN exon_transcript et ON t.transcript_id = et.`transcript_id`
		JOIN exon e ON et.exon_id = e.`exon_id`
		JOIN seq_region s ON e.seq_region_id = s.seq_region_id
		JOIN coord_system c ON c.coord_system_id = s.coord_system_id
		WHERE c.species_id = ?
		ORDER BY `id`
	/;

        $exon_sql = $self->_append_analysis_sql($dba, $exon_sql, 't');
        $log->debug("Getting exons for transcripts");
        $log->trace($sql);
        $dba->dbc->sql_helper->execute_no_return(
            -SQL          => $exon_sql,
            -PARAMS       => [ $dba->species_id ],
            -USE_HASHREFS => 1,
            -CALLBACK     => sub {

                my ($row) = @_;
                my $transcript = $transcripts->{$row->{trans_id}};
                $row->{coord_system} = $transcript->{coord_system};

                if($current_transcript_id ne $row->{trans_id}) {

                  if ( $current_transcript_id ne '') {
                               
                    $self->set_cds($exons_list, $transcripts->{$current_transcript_id}, $current_transcript_id); 
                    $exons_list = {};  
                  }

                  push @{ $exons_list->{ $row->{trans_id} } } , { 'start' =>  $row->{start}, 'end' => $row->{end} } ;
                  $current_transcript_id = $row->{trans_id};

                } else {
                  push @{ $exons_list->{ $row->{trans_id} } } , { 'start' =>  $row->{start}, 'end' => $row->{end} } ;
                }  
                
                delete $row->{trans_id};
                push @{$transcript->{exons}}, $row;
                return;
            });

            $self->set_cds($exons_list, $transcripts->{$current_transcript_id}, $current_transcript_id);

    }

    {
        $sql = q/
		select ifnull(t.stable_id, t.transcript_id) as trans_id,
		f.hit_name as id,
		f.hit_start as start,
		f.hit_end as end,
		f.evalue as evalue,
		d.db_name as db_name,
		d.db_display_name as db_display,
		a.logic_name as analysis,
        ad.display_label as analysis_display
		from coord_system c
		join seq_region s using (coord_system_id)
		join transcript t using (seq_region_id)
		join transcript_supporting_feature sf using (transcript_id)
		join dna_align_feature f on (f.dna_align_feature_id=sf.feature_id)
		join external_db d using (external_db_id)
		join analysis a on (a.analysis_id=f.analysis_id)
		left join analysis_description ad on (a.analysis_id=ad.analysis_id)
		where sf.feature_type='dna_align_feature'
		and c.species_id=?
		/;
        $sql = $self->_append_analysis_sql($dba, $sql, 't');
        $log->debug("Getting DNA supporting features for transcripts");
        $log->trace($sql);
        $dba->dbc->sql_helper->execute_no_return(
            -SQL          => $sql,
            -PARAMS       => [ $dba->species_id ],
            -USE_HASHREFS => 1,
            -CALLBACK     => sub {
                my ($row) = @_;
                my $transcript = $transcripts->{$row->{trans_id}};
                delete $row->{trans_id};
                push @{$transcript->{supporting_features}}, $row;
                return;
            });
    }
    {
        $sql = q/
		select ifnull(t.stable_id,t.transcript_id) as trans_id,
		f.hit_name as id,
		f.hit_start as start,
		f.hit_end as end,
		f.evalue as evalue,
		d.db_name as db_name,
		d.db_display_name as db_display,
		a.logic_name as analysis,
		ad.display_label as analysis_display
		from
		coord_system c
		join seq_region s using (coord_system_id)
		join transcript t using (seq_region_id)
		join transcript_supporting_feature sf using (transcript_id)
		join protein_align_feature f on (f.protein_align_feature_id=sf.feature_id)
		join external_db d using (external_db_id)
		join analysis a on (a.analysis_id=f.analysis_id)
	    left join analysis_description ad on (a.analysis_id=ad.analysis_id)
		where sf.feature_type='protein_align_feature'
		and c.species_id=?
		/;
        $sql = $self->_append_analysis_sql($dba, $sql, 't');
        $log->debug("Getting protein supporting features for transcripts");
        $log->trace($sql);
        $dba->dbc->sql_helper->execute_no_return(
            -SQL          => $sql,
            -PARAMS       => [ $dba->species_id ],
            -USE_HASHREFS => 1,
            -CALLBACK     => sub {
                my ($row) = @_;
                my $transcript = $transcripts->{$row->{trans_id}};
                delete $row->{trans_id};
                push @{$transcript->{supporting_features}}, $row;
                return;
            });

    }

    {
        my $stable_ids = $self->get_stable_ids($dba, 'transcript');
        while (my ($id, $prev_ids) = each(%$stable_ids)) {
            $transcripts->{$id}->{previous_ids} = $prev_ids;
        }
    }

    my $transcript_hash = {};
    for my $transcript (values %$transcripts) {
        push @{$transcript_hash->{ $transcript->{gene_id} }}, $transcript;
        delete $transcript_hash->{gene_id};
    }
    return $transcript_hash;
} ## end sub get_transcripts


sub set_cds {

  my ($self , $exons_list, $transcript, $transcript_id ) = @_;

  #"Getting CDS start and end cords for transcript" 
  my $arraylength = @{$exons_list->{$transcript_id}};
  
  if( $arraylength > 1 ){
    push @{$transcript->{cds}}, {'start'=> ${$exons_list->{$transcript_id}}[0]->{start}, 'end' => ${$exons_list->{$transcript_id}}[-1]->{end} };  
  } else{
    push @{$transcript->{cds}}, {'start'=> ${$exons_list->{$transcript_id}}[0]->{start}, 'end' => ${$exons_list->{$transcript_id}}[0]->{end} };
  }

}


sub get_translations {
    my ($self, $dba, $biotypes, $level, $load_xrefs) = @_;

    my $sql = q/
    select ifnull(t.stable_id,t.transcript_id) as transcript_id,
    ifnull(tl.stable_id,tl.translation_id) as id,
    tl.version as version,
    'translation' as ensembl_object_type
    from transcript t
    join translation tl using (transcript_id)
    join seq_region s using (seq_region_id)
    join coord_system c using (coord_system_id)
    where c.species_id = ? 
  /;
    $sql = $self->_append_biotype_sql($sql, $biotypes, 't');
    $sql = $self->_append_analysis_sql($dba, $sql, 't');
    my $xrefs = {};
    if ($load_xrefs == 1) {
        $log->debug("Retrieving xrefs for translations");
        $xrefs = $self->get_xrefs($dba, 'translation', $biotypes);
    }

    # add protein features
    my $protein_features = {};
    if ($level eq 'protein_feature') {
        $log->debug("Retrieving protein_features for translations");
        $protein_features = $self->get_protein_features($dba, $biotypes);
    }

    my $stable_ids = $self->get_stable_ids($dba, 'translation');

    $log->debug("Retrieving translations");
    my @translations = @{
        $dba->dbc()->sql_helper()->execute(
            -SQL          => $sql,
            -PARAMS       => [ $dba->species_id() ],
            -USE_HASHREFS => 1,
            -CALLBACK     => sub {
                my ($row) = @_;
                $row->{xrefs} = ( $xrefs->{ $row->{id} } ) ? $xrefs->{ $row->{id} } : [];
                $row->{protein_features} = $protein_features->{ $row->{id} };
                my $ids = $stable_ids->{$row->{id}};
                $row->{previous_ids} = $ids if defined $ids && scalar(@$ids) > 0;
                return $row;
            })};

    my $translation_hash = {};
    for my $translation (@translations) {
        push @{$translation_hash->{ $translation->{transcript_id} }}, $translation;
        delete $translation_hash->{transcript_id};
    }
    return $translation_hash;
} ## end sub get_translations

sub get_protein_features {
    my ($self, $dba, $biotypes) = @_;

    my $sql = q/
    select
    ifnull(tl.stable_id, tl.translation_id) as translation_id,
    pf.hit_name as name,
    pf.hit_description as description,
    pf.seq_start as start,
    pf.seq_end as end,
    a.db as dbname,
    i.interpro_ac,
    ix.display_label as interpro_name,
    ix.description as interpro_description,
    'protein_feature' as ensembl_object_type
    from transcript t
    join translation tl using (transcript_id)
    join protein_feature pf using (translation_id)
    join analysis a on (a.analysis_id = pf.analysis_id)
    left join interpro i on (pf.hit_name = i.id)
    left join xref ix on (i.interpro_ac = ix.dbprimary_acc)
    left join external_db idx on (ix.external_db_id=idx.external_db_id and idx.db_name='Interpro')
    join seq_region s using (seq_region_id)
    join coord_system c using (coord_system_id)
    where c.species_id = ? 
  /;
    $self->_append_biotype_sql($sql, $biotypes, 't');
    $log->debug("Retrieving protein_features");
    $log->trace($sql);
    my @protein_features = @{
        $dba->dbc()->sql_helper()->execute(
            -SQL          => $sql,
            -PARAMS       => [ $dba->species_id() ],
            -USE_HASHREFS => 1)};

    my $pf_hash = {};
    for my $protein_feature (@protein_features) {
        delete $protein_feature->{description} unless defined $protein_feature->{description};
        delete $protein_feature->{interpro_ac} unless defined $protein_feature->{interpro_ac};
        delete $protein_feature->{interpro_name} unless defined $protein_feature->{interpro_name} && $protein_feature->{interpro_name} ne $protein_feature->{interpro_ac};
        delete $protein_feature->{interpro_description} unless defined $protein_feature->{interpro_description};
        push @{$pf_hash->{ $protein_feature->{translation_id} }}, $protein_feature;
        delete $pf_hash->{translation_id};
    }
    return $pf_hash;
} ## end sub get_protein_features

sub _generate_xref_sql {
    my ($self, $table_name) = @_;
    if ($table_name eq 'translation') {
        return qq/
      SELECT ifnull(tl.stable_id, tl.translation_id) AS id, x.xref_id, x.dbprimary_acc, x.display_label, e.db_name, e.db_display_name, x.description, x.info_type, x.info_text
      FROM transcript t
      JOIN translation tl USING (transcript_id)
      JOIN object_xref ox         ON (tl.translation_id = ox.ensembl_id AND ox.ensembl_object_type = 'Translation')
      JOIN xref x                 USING (xref_id)
      JOIN external_db e          USING (external_db_id)
      JOIN seq_region s           USING (seq_region_id)
      JOIN coord_system c         USING (coord_system_id)
      LEFT JOIN ontology_xref oox USING (object_xref_id)
      WHERE c.species_id = ? AND oox.object_xref_id is null 
    /;
    }
    else {
        my $Table_name = ucfirst($table_name);
        return qq/SELECT ifnull(f.stable_id, f.${table_name}_id) AS id, x.xref_id, x.dbprimary_acc, x.display_label, e.db_name, e.db_display_name, x.description, x.info_type, x.info_text
	    FROM ${table_name} f
	    JOIN object_xref ox ON (f.${table_name}_id = ox.ensembl_id AND ox.ensembl_object_type = '${Table_name}')
	    JOIN xref x USING (xref_id)
	    JOIN external_db e USING (external_db_id)
	    JOIN seq_region s           USING (seq_region_id)
            JOIN coord_system c         USING (coord_system_id)
      LEFT JOIN ontology_xref oox USING (object_xref_id)
	    WHERE c.species_id = ? AND oox.object_xref_id is null/;
    }
} ## end sub _generate_xref_sql

sub _generate_object_xref_sql {
    my ($self, $table_name) = @_;

    if ($table_name eq 'translation') {
        return qq/SELECT ox.object_xref_id, ifnull(tl.stable_id, tl.translation_id) AS id, x.dbprimary_acc, x.display_label, e.db_name, e.db_display_name,  x.description,
           oox.linkage_type, sx.dbprimary_acc, sx.display_label, sx.description, se.db_name, se.db_display_name
      FROM transcript t
      JOIN translation tl USING (transcript_id)
      JOIN object_xref ox         ON (tl.translation_id = ox.ensembl_id AND ox.ensembl_object_type = 'Translation')
      JOIN xref x              USING (xref_id)
      JOIN external_db e       USING (external_db_id)
      JOIN seq_region s        USING (seq_region_id)
      JOIN coord_system c      USING (coord_system_id)
      JOIN ontology_xref oox   USING (object_xref_id)
      LEFT JOIN xref sx        ON (oox.source_xref_id = sx.xref_id)
      LEFT JOIN external_db se ON (se.external_db_id = sx.external_db_id)
      WHERE c.species_id = ? 
  /;
    }
    else {
        my $Table_name = ucfirst($table_name);
        return qq/SELECT ox.object_xref_id, ifnull(f.stable_id, f.${table_name}_id) AS id, x.dbprimary_acc, x.display_label, e.db_name, e.db_display_name,  x.description,
           oox.linkage_type, sx.dbprimary_acc, sx.display_label, sx.description, se.db_name, se.db_display_name
	    FROM ${table_name} f
	    JOIN object_xref ox ON (f.${table_name}_id = ox.ensembl_id AND ox.ensembl_object_type = '${Table_name}')
	    JOIN xref x USING (xref_id)
	    JOIN external_db e USING (external_db_id)
	    JOIN seq_region s           USING (seq_region_id)
            JOIN coord_system c         USING (coord_system_id)
            JOIN ontology_xref oox USING (object_xref_id)
            LEFT JOIN xref sx        ON (oox.source_xref_id = sx.xref_id)
            LEFT JOIN external_db se ON (se.external_db_id = sx.external_db_id)
	    WHERE c.species_id = ?/;
    }

} ## end sub _generate_object_xref_sql

sub _generate_associated_xref_sql {
    my ($self, $table_name) = @_;
    if ($table_name eq 'translation') {
        return qq/
    SELECT ax.object_xref_id, ax.rank, ax.condition_type, x.dbprimary_acc, x.display_label, xe.db_name, xe.db_display_name, x.description,
           sx.dbprimary_acc, sx.display_label, se.db_name, sx.description, ax.associated_group_id 
      FROM transcript t
      JOIN translation tl USING (transcript_id)
      JOIN object_xref ox     ON (tl.translation_id = ox.ensembl_id AND ox.ensembl_object_type = 'Translation')
      JOIN associated_xref ax USING (object_xref_id) 
      JOIN xref x             ON (x.xref_id = ax.xref_id) 
      JOIN external_db xe     ON (x.external_db_id = xe.external_db_id) 
      JOIN xref sx            ON (sx.xref_id = ax.source_xref_id) 
      JOIN external_db se     ON (se.external_db_id = sx.external_db_id) 
      JOIN seq_region s       USING (seq_region_id)
      JOIN coord_system c     USING (coord_system_id)
      WHERE c.species_id=? 
  /;
    }
    else {
        my $Table_name = ucfirst($table_name);
        return qq/
    SELECT ax.object_xref_id, ax.rank, ax.condition_type, x.dbprimary_acc, x.display_label, xe.db_name, xe.db_display_name, x.description,
           sx.dbprimary_acc, sx.display_label, se.db_name, sx.description, ax.associated_group_id
	    FROM ${table_name} f
	    JOIN object_xref ox ON (f.${table_name}_id = ox.ensembl_id AND ox.ensembl_object_type = '${Table_name}')
            JOIN associated_xref ax USING (object_xref_id)
            JOIN xref x             ON (x.xref_id = ax.xref_id)
            JOIN external_db xe     ON (x.external_db_id = xe.external_db_id)
            JOIN xref sx            ON (sx.xref_id = ax.source_xref_id)
            JOIN external_db se     ON (se.external_db_id = sx.external_db_id)
	    JOIN seq_region s           USING (seq_region_id)
            JOIN coord_system c         USING (coord_system_id)
	    WHERE c.species_id = ?/;
    }
} ## end sub _generate_xref_sql

sub get_xrefs {
    my ($self, $dba, $type, $biotypes) = @_;

    my $synonyms = {};
    $dba->dbc()->sql_helper()->execute_no_return(
        -SQL      => q/select xref_id,synonym from external_synonym/,
        -CALLBACK => sub {
            my ($id, $syn) = @{$_[0]};
            push @{$synonyms->{$id}}, $syn;
            return;
        });

    my $sql = $self->_generate_xref_sql($type);
    $sql = $self->_append_biotype_sql($sql, $biotypes, $type);
    my $oox_sql = $self->_generate_object_xref_sql($type);
    $oox_sql = $self->_append_biotype_sql($oox_sql, $biotypes, $type);
    my $ax_sql = $self->_generate_associated_xref_sql($type);
    $ax_sql = $self->_append_biotype_sql($ax_sql, $biotypes, $type);

    my $xrefs = {};
    $dba->dbc()->sql_helper()->execute_no_return(
        -SQL      => $sql,
        -PARAMS   => [ $dba->species_id() ],
        -CALLBACK => sub {
            my ($row) = @_;
            my ($stable_id, $xref_id, $dbprimary_acc,
                $display_label, $db_name, $db_display_name,
                $description, $info_type, $info_text) = @$row;
            my $x = { primary_id => $dbprimary_acc,
                display_id       => $display_label,
                dbname           => $db_name,
                db_display       => $db_display_name,
                description      => $description,
                info_type        => $info_type,
                info_text        => $info_text };
            my $syn = $synonyms->{$xref_id};
            $x->{synonyms} = $syn if defined $syn;
            push @{$xrefs->{$stable_id}}, $x;
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
            my ($ox_id, $stable_id,
                $dbprimary_acc, $display_label,
                $db_name, $description,
                $linkage_type, $other_dbprimary_acc,
                $other_display_label, $other_description,
                $other_dbname, $other_db_display_name) = @$row;
            my $xref = $oox_xrefs->{ $ox_id };
            if (!defined $xref) {
                $xref = { obj_id => $stable_id,
                    primary_id   => $dbprimary_acc,
                    display_id   => $display_label,
                    dbname       => $db_name,
                    description  => $description,
                };
                $oox_xrefs->{ $ox_id } = $xref;
            }
            # add linkage type to $xref
            push @{$xref->{linkage_types}}, {
                evidence => $linkage_type,
                source   => {
                    primary_id      => $other_dbprimary_acc,
                    display_id      => $other_display_label,
                    dbname          => $other_dbname,
                    db_display_name => $other_db_display_name,
                    description     => $other_description,
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
            my ($associated_ox_id, $associated_rank,
                $associated_condition, $dbprimary_acc,
                $display_label, $db_name,
                $db_display_name,
                $description, $other_dbprimary_acc,
                $other_display_label, $other_db_name,
                $other_description, $associated_group_id) = @$row;
            my $xref = $oox_xrefs->{ $associated_ox_id };
            # add linkage type to $xref
            if (defined $associated_group_id && defined $associated_condition) {
                $xref->{associated_xrefs}->{ $associated_group_id }->{ $associated_condition } = {
                    rank            => $associated_rank,
                    primary_id      => $dbprimary_acc,
                    display_id      => $display_label,
                    db_display_name => $db_display_name,
                    dbname          => $db_name,
                    description     => $description,
                    source          => {
                        primary_id  => $other_dbprimary_acc,
                        display_id  => $other_display_label,
                        dbname      => $other_db_name,
                        description => $other_description,
                    } };
            }
            return;
        }
    );

    # collate everything, remove some uninteresting keys,
    for my $xref (values %{$oox_xrefs}) {
        $xref->{associated_xrefs} = [ values %{$xref->{associated_xrefs}} ];
        push @{$xrefs->{ $xref->{obj_id} }}, $xref;
        delete $xref->{obj_id};
    }

    return $xrefs;

} ## end sub get_xrefs

sub get_coord_systems {
    my ($self, $dba, $type, $biotypes) = @_;
    my $sql = qq/
    select ifnull(g.stable_id,g.${type}_id) as id, c.name, c.version
    from $type g
    join seq_region s using (seq_region_id)
    join coord_system c using (coord_system_id)
    where c.species_id = ? 
  /;
    $sql = $self->_append_biotype_sql($sql, $biotypes);
    $sql = $self->_append_analysis_sql($dba, $sql, 'g');

    my $coord_systems = {};

    $dba->dbc()->sql_helper()->execute_no_return(
        -SQL      => $sql,
        -PARAMS   => [ $dba->species_id() ],
        -CALLBACK => sub {
            my ($row) = @_;
            $coord_systems->{ $row->[0] } = { name => $row->[1], version => $row->[2] };
            return;
        });
    return $coord_systems;
}

sub get_synonyms {
    my ($self, $dba, $biotypes) = @_;
    my $sql = q/
    select ifnull(g.stable_id,g.gene_id) as id, e.synonym
    from gene g
    join external_synonym e on (g.display_xref_id = e.xref_id)
    join seq_region s using (seq_region_id)
    join coord_system c using (coord_system_id)
    where c.species_id = ? 
  /;
    $sql = $self->_append_biotype_sql($sql, $biotypes);
    my $synonyms = {};
    $dba->dbc()->sql_helper()->execute_no_return(
        -SQL      => $sql,
        -PARAMS   => [ $dba->species_id() ],
        -CALLBACK => sub {
            my ($row) = @_;
            push @{$synonyms->{ $row->[0] }}, $row->[1];
            return;
        });
    return $synonyms;
}

sub get_seq_region_synonyms {
    my ($self, $dba, $type, $biotypes) = @_;
    my $sql = qq/
    select ifnull(g.stable_id,${type}_id) as id, sr.synonym as synonym, e.db_name as db
    from $type g
    join seq_region_synonym sr using (seq_region_id)
    join seq_region s using (seq_region_id)
    join coord_system c using (coord_system_id)
    left join external_db e using (external_db_id)
    where c.species_id = ? 
  /;
    $sql = $self->_append_biotype_sql($sql, $biotypes, 'g');
    $sql = $self->_append_analysis_sql($dba, $sql, 'g');
    my $synonyms = {};
    $dba->dbc()->sql_helper()->execute_no_return(
        -SQL      => $sql,
        -PARAMS   => [ $dba->species_id() ],
        -CALLBACK => sub {
            my ($row) = @_;
            push @{$synonyms->{ $row->[0] }}, { id => $row->[1], db => $row->[2] };
            return;
        });
    return $synonyms;
}

sub get_haplotypes {
    my ($self, $dba, $type, $biotypes) = @_;
    my $sql = qq/
    select ifnull(g.stable_id,${type}_id) as id
    from $type g
    join assembly_exception ae using (seq_region_id)
    join seq_region s using (seq_region_id)
    join coord_system c using (coord_system_id)
    where c.species_id = ? and ae.exc_type='HAP'
  /;
    $sql = $self->_append_biotype_sql($sql, $biotypes);
    $sql = $self->_append_analysis_sql($dba, $sql, 'g');
    my $haplotypes = {};
    $dba->dbc()->sql_helper()->execute_no_return(
        -SQL      => $sql,
        -PARAMS   => [ $dba->species_id() ],
        -CALLBACK => sub {
            my ($row) = @_;
            $haplotypes->{ $row->[0] } = 1;
            return;
        });
    return $haplotypes;
}

my $base_id_sql = q/
      SELECT f.stable_id as id, sie.old_stable_id as old_id
      FROM stable_id_event as sie
      JOIN %s f on (f.stable_id=sie.new_stable_id)
      %sJOIN seq_region s USING (seq_region_id)
      JOIN coord_system c USING (coord_system_id)
      WHERE sie.type=?
      AND old_stable_id != new_stable_id
      AND c.species_id=?
/;
my $stable_id_sql = {
    gene        => sprintf($base_id_sql, 'gene', ''),
    transcript  => sprintf($base_id_sql, 'transcript', ''),
    translation => sprintf($base_id_sql, 'translation', 'JOIN transcript USING (transcript_id) ')
};

sub get_stable_ids {
    my ($self, $dba, $type) = @_;
    my $stable_ids = {};
    $dba->dbc()->sql_helper()->execute_no_return(
        -SQL      => $stable_id_sql->{$type},
        -PARAMS   => [ $type, $dba->species_id() ],
        -CALLBACK => sub {
            my ($row) = @_;
            push @{$stable_ids->{ $row->[0] }}, $row->[1];
            return;
        });
    return $stable_ids;
}

sub add_compara {
    my ($self, $species, $genes, $compara_dba) = @_;
    warn "Adding compara...\n";
    $self->add_homologues($species, $genes, $compara_dba);
    $self->add_family($species, $genes, $compara_dba);
    warn "Finished adding compara...\n";
    return;
}

sub add_pan_compara {
    my ($self, $species, $genes, $compara_dba) = @_;
    warn "Adding pan taxonomic compara...\n";
    $self->add_homologues($species, $genes, $compara_dba);
    warn "Finished adding pan taxonomic compara...\n";
    return;
}

sub add_homologues {
    my ($self, $species, $genes, $compara_dba) = @_;
    my $homologues = {};
    $compara_dba->dbc()->sql_helper()->execute_no_return(
        -SQL      => q/
SELECT gm1.stable_id, gm2.stable_id, g2.name, h.description, r.stable_id
FROM homology_member hm1
 INNER JOIN homology_member hm2 ON (hm1.homology_id = hm2.homology_id)
 INNER JOIN homology h ON (hm1.homology_id = h.homology_id)
 INNER JOIN gene_member gm1 ON (hm1.gene_member_id = gm1.gene_member_id)
 INNER JOIN gene_member gm2 ON (hm2.gene_member_id = gm2.gene_member_id)
 INNER JOIN genome_db g ON (gm1.genome_db_id = g.genome_db_id)
 INNER JOIN genome_db g2 ON (gm2.genome_db_id = g2.genome_db_id)
 INNER JOIN gene_tree_root r ON (h.gene_tree_root_id=r.root_id)
WHERE (hm1.gene_member_id <> hm2.gene_member_id)
 AND (gm1.stable_id <> gm2.stable_id)
 AND (g.name = ?)
 AND (gm1.source_name = 'ENSEMBLGENE')/,
        -CALLBACK => sub {
            my ($row) = @_;
            push @{$homologues->{ $row->[0] }}, {
                stable_id      => $row->[1],
                genome         => $row->[2],
                orthology_type => $row->[3],
                gene_tree_id   => $row->[4] };
            return;
        },
        -PARAMS   => [ $species ]);
    my $n = 0;
    for my $gene (@{$genes}) {
        if (!defined $gene->{id}) {
            throw("No stable ID for gene");
        }
        my $homo = $homologues->{ $gene->{id} };
        if (defined $homo) {
            $n++;
            $gene->{homologues} ||= [];
            push @{$gene->{homologues}}, @$homo;
        }
    }
    print "Added homologues to $n genes\n";
    return;
} ## end sub add_homologues

sub add_family {
    my ($self, $species, $genes, $compara_dba) = @_;
    my $families = {};
    # hash all families for this genome by sequence stable_id
    $compara_dba->dbc()->sql_helper()->execute_no_return(
        -SQL      => q/
SELECT s.stable_id, f.stable_id, f.version, f.description
FROM family f
JOIN family_member fm USING (family_id)
JOIN seq_member s USING (seq_member_id)
JOIN genome_db g USING (genome_db_id)
WHERE g.name = ?/,
        -CALLBACK => sub {
            my ($row) = @_;
            my $f = { stable_id => $row->[1] };
            $f->{version} = $row->[2] if (defined $row->[2]);
            $f->{description} = $row->[3] if (defined $row->[3]);
            push @{$families->{ $row->[0] }}, $f;
            return;
        },
        -PARAMS   => [ $species ]);

    my $n = 0;
    # add families for each member
    for my $gene (@{$genes}) {

        for my $transcript (@{$gene->{transcripts}}) {
            my $family = $families->{ $transcript->{id} };
            if (defined $family) {
                $n++;
                $transcript->{families} = $family;
            }

            for my $translation (@{$transcript->{translations}}) {
                $family = $families->{ $translation->{id} };
                if (defined $family) {
                    $n++;
                    $translation->{families} = $family;
                }
            }
        }
    }
    print "Added families to $n objects\n";
    return;
} ## end sub add_family

my $probe_set_sql = q/select distinct
    probe_set_transcript.stable_id AS transcript_stable_id,
    array.name                     AS array_name,
    probe_set.name                 AS display_label,
    CONCAT(array.vendor, '_', REPLACE(REPLACE(array.name, '-', '_'), '.', '_'))
                                   AS array_vendor_and_name
from array
  join array_chip using (array_id)
  join probe using (array_chip_id)
  join probe_set using (probe_set_id)
  join probe_set_transcript using (probe_set_id)
where
  array.is_probeset_array=1/;

my $probe_sql = q/select distinct
    probe_transcript.stable_id     AS transcript_stable_id,
    array.name                     AS array_name,
    probe.name                     AS display_label,
    CONCAT(array.vendor, '_', REPLACE(REPLACE(array.name, '-', '_'), '.', '_'))
                                   AS array_vendor_and_name
from array
  join array_chip using (array_id)
  join probe using (array_chip_id)
  join probe_transcript using (probe_id)
where
  array.is_probeset_array=0/;

sub add_funcgen {
    my ($self, $genes, $funcgen_dba) = @_;
    my $probes = {};
    for my $sql ($probe_set_sql) {
        $funcgen_dba->dbc()->sql_helper()->execute_no_return(
            -SQL      => $sql,
            -CALLBACK => sub {
                my ($transcript_id, $array, $probe, $vendor) = @{shift @_};
                push @{$probes->{$transcript_id}},
                    { array => $array, probe => $probe, vendor => $vendor };
                return;
            });
    }

    for my $gene (@{$genes}) {
        for my $transcript (@{$gene->{transcripts}}) {
            my $probes_for_transcript = $probes->{ $transcript->{id} };
            $transcript->{probes} = $probes_for_transcript
                if defined $probes_for_transcript;
        }
    }
    return;
}



1;
