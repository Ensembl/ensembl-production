=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 
=cut

package Bio::EnsEMBL::Production::Utils::GenomeCopier;

use Log::Log4perl qw(:easy);
use Bio::EnsEMBL::Slice;
use Bio::EnsEMBL::CoordSystem;
use Bio::EnsEMBL::Attribute;
use Bio::EnsEMBL::SeqRegionSynonym;
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Transcript;
use Bio::EnsEMBL::Translation;
use Bio::EnsEMBL::Exon;
use Bio::EnsEMBL::DBEntry;
use Bio::EnsEMBL::OntologyXref;
use Bio::EnsEMBL::IdentityXref;
use Bio::EnsEMBL::DensityFeature;
use Bio::EnsEMBL::SimpleFeature;
use Bio::EnsEMBL::ProteinFeature;

sub new {
  my $classname = shift;
  my $self = { logger => get_logger() };
  bless $self, $classname;
  return $self;
}

sub logger {
  my ($self) = @_;
  return $self->{logger};
}

my $features = {
            assembly_exception => [],
            density_feature    => [],
            ditag_feature      => [],
            dna                => [],
            dna_align_feature  => [],
            exon               => [supporting_feature],
            gene => [ alt_allele, gene_attrib, operon_transcript_gene ],
            karyotype         => [],
            marker_feature    => [],
            misc_feature      => [ misc_feature_misc_set, misc_attrib ],
            operon            => [operon_transcript],
            operon_transcript => [operon_transcript_gene],
            prediction_exon   => [],
            prediction_transcript => [prediction_exon],
            protein_align_feature => [],
            repeat_feature        => [],
            seq_region_attrib     => [],
            seq_region_synonym    => [],
            simple_feature        => [],
            transcript            => [
                            transcript_attrib, exon_transcript,
                            transcript_supporting_feature, translation ]
};
my $ox_tables = [ "ontology_xref", "identity_xref" ];
my $ref_features = { Gene             => "gene",
                     Transcript       => "transcript",
                     Translation      => "translation",
                     Operon           => "operon",
                     OperonTranscript => "operon_transcript" };

my $delete_orphans =
  q/delete from TARGET where KEY not in (select distinct SRCKEY
		from SRC)/;

my $delete_scm = q/delete m,c,s from meta as m, coord_system as c,
		seq_region as s
		where c.coord_system_id=s.coord_system_id and
		c.species_id=m.species_id and
		m.species_id=?/;

my $delete_orphan_ox =
  q/delete from object_xref where ensembl_object_type='KEY'
		and ensembl_id not in (select TABLE_id from TABLE)/;

my $delete_exon_transcript =
  q/delete from exon_transcript where transcript_id in
		(select et.transcript_id from exon_transcript et left join transcript
		t using (transcript_id) where t.transcript_id is null/;
my $delete_xref = q/delete from xref where xref_id not in (select
		display_xref_id from transcript union distinct select display_xref_id
		from gene union distinct select source_xref_id from ontology_xref
		union distinct select xref_id from object_xref/;

sub delete {
  my ( $self, $tgt ) = @_;
  $self->logger()
    ->info(
       "Deleting " . $tgt->dbc()->dbname() . "/" . $tgt->species_id() );
  my $helper     = $tgt->dbc()->sql_helper();
  my $species_id = $tgt->species_id();
  $helper->execute_update( -SQL    => $delete_scm,
                           -PARAMS => [$species_id] );
  $self->delete_orphans( $helper, "meta_coord", "coord_system_id",
                         "coord_system_id", "coord_system" );
  for my $feature ( keys %{$features} ) {
    my $tables = $features->{$feature};
    $self->delete_orphans( $helper, $feature, "seq_region_id",
                           "seq_region_id", "seq_region" );
    if ( defined $tables ) {
      for my $table (@$tables) {
        $self->delete_orphans( $helper, $table,
                               $feature . "_id",
                               $feature . "_id", $feature );
      }
    }
  }
  $self->delete_orphans( $helper, "assembly", "asm_seq_region_id",
                         "seq_region_id", "seq_region" );
  $self->delete_orphans( $helper, "assembly", "cmp_seq_region_id",
                         "seq_region_id", "seq_region" );
  $self->delete_orphans( $helper, "translation_attrib",
                         "translation_id", "translation_id",
                         "translation" );
  $self->delete_orphans( $helper,          "protein_feature",
                         "translation_id", "translation_id",
                         "translation" );
  $self->delete_orphans( $helper,               "repeat_consensus",
                         "repeat_consensus_id", "repeat_consensus_id",
                         "repeat_feature" );
  $self->delete_orphans( $helper, "genome_statistics", "species_id",
                         "species_id", "meta" );

  for my $ref_feature ( keys %{$ref_features} ) {
    my $table = $ref_features->{$ref_feature};
    ( my $sql = $delete_orphan_ox ) =~ s/KEY/$ref_feature/g;
    $sql =~ s/TABLE/$table/g;
    $helper->execute_update( -SQL => $sql );
  }

  for my $table ( @{$ox_tables} ) {
    $self->delete_orphans( $helper, $table, "object_xref_id",
                           "object_xref_id", "object_xref" );
  }

  $self->logger()
    ->info( "Completed deleting " . $tgt->dbc()->dbname() . "/" .
            $tgt->species_id() );

  return;
} ## end sub delete

sub delete_orphans {
  my ( $self, $helper, $target, $key, $srcKey, $source ) = @_;

  my $sql = $delete_orphans;

  $sql =~ s/TARGET/$target/g;
  $sql =~ s/SRCKEY/$srcKey/g;
  $sql =~ s/SRC/$source/g;
  $sql =~ s/KEY/$key/g;

  $helper->execute_update( -SQL => $sql );
  return;
}

sub copy {
  my ( $self, $src, $tgt ) = @_;
  $self->logger()
    ->info(
    "Copying from " . $src->dbc()->dbname() . "/" . $src->species_id() .
      " to " . $tgt->dbc()->dbname() . "/" . $tgt->species_id() );
  # prepare the schema
  $self->prepare_schema( $src, $tgt );
  # copy metadata
  $self->copy_metadata( $src, $tgt );
  # copy assembly
  $self->copy_assembly( $src, $tgt );
  # copy features
  $self->copy_features( $src, $tgt );
  # post-processing
  $self->finish_schema( $src, $tgt );
  return;
}

my $ctrl_tables = {
  external_db => [
    qw/external_db_id db_name db_release status priority db_display_name type secondary_db_name secondary_db_table description/
  ],
  attrib_type => [qw/attrib_type_id code name description/] };

my @analysis =
  qw/logic_name created db db_version db_file program program_version program_file parameters module gff_source gff_feature/;
my @analysis_description =
  qw/analysis_id description display_label displayable web_data/;

sub prepare_schema {
  my ( $self, $src, $tgt ) = @_;
  # external_db and attrib_type - iterate over and insert
  while ( my ( $name, $cols ) = each %{$ctrl_tables} ) {
    $self->logger()->debug("Merging $name");
    my $col_str = join( ',', @$cols );
    my $place_holders = "?," x scalar(@$cols);
    chop $place_holders;
    my $sql = 'select ' . $col_str . ' from ' . $name;
    $src->dbc()->sql_helper()->execute_no_return(
      -SQL      => $sql,
      -CALLBACK => sub {
        my @row = @{ shift @_ };
        $tgt->dbc()->sql_helper()->execute_update(
          -SQL =>
            "insert ignore into $name($col_str) values($place_holders)",
          -PARAMS => [@row] );
        return;
      } );
  }

  # deal with analysis
  $self->logger()->debug("Merging analysis");
  my $col_str = join( ',', @analysis );
  my $place_holders = "?," x scalar(@analysis);
  chop $place_holders;
  my $tgt_analysis =
    $tgt->dbc()->sql_helper()
    ->execute_into_hash(
                -SQL => "select logic_name,analysis_id from analysis" );
  my $missing_analysis = {};
  $src->dbc()->sql_helper()->execute_no_return(
    -SQL      => 'select ' . $col_str . ' from analysis',
    -CALLBACK => sub {
      my @row        = @{ shift @_ };
      my $logic_name = $row[0];
      # do we have it?
      if ( !defined $tgt_analysis->{$logic_name} ) {
        $self->logger()
          ->debug("Inserting missing analysis $logic_name");
        my $rows =
          $src->dbc()->sql_helper()->execute(
             -SQL => "select $col_str from analysis where logic_name=?",
             -PARAMS => [$logic_name] );
        # insert it
        $tgt->dbc()->sql_helper()->execute_update(
              -SQL =>
                "insert into analysis($col_str) values($place_holders)",
              -PARAMS => $rows->[0] );
        # get the analysis_id back
        my $analysis_id =
          $tgt->dbc()->sql_helper()->execute_single_result(
          -SQL => "select analysis_id from analysis where logic_name=?",
          -PARAMS => [$logic_name] );
        $missing_analysis->{$logic_name} = $analysis_id;
        $self->logger()
          ->debug("Analysis $logic_name has id $analysis_id");
      }
      return;
    } );
# next deal with analysis_description - assume that we don't have to copy analysis_description where analysis already exists

  $self->logger()->debug("Merging analysis_description");
  $col_str = join( ',', @analysis_description );
  $place_holders = "?," x scalar(@analysis_description);
  chop $place_holders;
  while ( my ( $logic_name, $analysis_id ) = each %$missing_analysis ) {
    print "Dealing with $logic_name $analysis_id\n";
    my $rows =
      $src->dbc()->sql_helper()->execute(
      -SQL =>
"select $col_str from analysis_description where analysis_id=(select analysis_id from analysis where logic_name=?)",
      -PARAMS => [$logic_name] );
    if(scalar(@$rows>0)) {
      $rows->[0][0] = $analysis_id;
      $tgt->dbc()->sql_helper()->execute_update(
                                                -SQL =>
                                                "insert into analysis_description($col_str) values($place_holders)",
                                                -PARAMS => $rows->[0] );
    }
  }

  return;
} ## end sub prepare_schema

sub finish_schema {
  my ( $self, $src, $tgt ) = @_;
  # break object_xref-display_xref links where needed
  # populate interpro table and xrefs if needed
  my $interpro_xrefs = {};
  my $tgt_dba        = $tgt->get_DBEntryAdaptor();
  $src->dbc()->sql_helper()->execute_no_return(
    -SQL =>
      q/select distinct interpro_ac,id,x.description from coord_system 
  join seq_region using (coord_system_id) 
  join transcript using (seq_region_id) 
  join translation using (transcript_id) 
  join protein_feature using (translation_id) 
  join interpro on (id=hit_name) 
  join xref x on (dbprimary_acc=interpro_ac) 
  join external_db using (external_db_id) 
  where db_name='Interpro' and species_id=?
  /,
    -PARAMS   => [ $tgt->species_id() ],
    -CALLBACK => sub {
      my ( $interpro_ac, $id, $description ) = @{ shift @_ };
      if ( !defined $interpro_xrefs->{$interpro_ac} ) {
        $tgt_dba->store( Bio::EnsEMBL::DBEntry->new(
                                            -PRIMARY_ID => $interpro_ac,
                                            -DBNAME     => 'Interpro',
                                            -DISPLAY_ID => $interpro_ac,
                                            -DESCRIPTION => $description
                         ),
                         undef, undef, 1 );
        $interpro_xrefs->{$interpro_ac} = 1;
      }
      $tgt->dbc()->sql_helper()->execute_update(
           -SQL =>
             q/insert ignore into interpro(interpro_ac,id) values(?,?)/,
           -PARAMS => [ $interpro_ac, $id ] );
      return;
      }

  );
  return;
} ## end sub finish_schema

sub copy_metadata {
  my ( $self, $src, $tgt ) = @_;
  $self->logger()->info("Copying metadata");
  my $meta = $tgt->get_MetaContainer();
  $src->dbc()->sql_helper->execute_no_return(
    -CALLBACK => sub {
      my @row = @{ shift @_ };
      $meta->store_key_value( $row[0], $row[1] );
      return;
    },
    -SQL =>
q/select meta_key,meta_value from meta where species_id=? order by meta_id/,
    -PARAMS => [ $src->species_id() ] );

  my $genome_container = $tgt->get_GenomeContainer();
  $src->dbc()->sql_helper->execute_no_return(
    -CALLBACK => sub {
      my @row = @{ shift @_ };
      $genome_container->store( $row[0], $row[1], $row[2] );
      return;
    },
    -SQL =>
q/select statistic,value,code from genome_statistics left join attrib_type using (attrib_type_id) where species_id=? order by genome_statistics_id/,
    -PARAMS => [ $src->species_id() ] );

  $meta->store_key_value( 'schema.copy_src',
                     $src->dbc()->dbname() . '/' . $src->species_id() );
  $self->logger()->info("Finished copying metadata");

  return;
} ## end sub copy_metadata

sub copy_assembly {
  my ( $self, $src, $tgt ) = @_;
  my $logger = $self->logger();
  $logger->info("Copying assembly");

  # coord system
  $logger->info();
  my $src_csa = $src->get_CoordSystemAdaptor();
  my $tgt_csa = $tgt->get_CoordSystemAdaptor();
  my $tcss = [];    # hash to allow us to reuse these
  $logger->info("Copying coord systems");

  foreach my $cs ( sort { $a->dbID() <=> $b->dbID() }
                   @{ $src_csa->fetch_all() } )
  {
    $logger->info( "Copying coord system " . $cs->name() );
    my $tcs =
      Bio::EnsEMBL::CoordSystem->new(
                            -NAME           => $cs->name(),
                            -SEQUENCE_LEVEL => $cs->is_sequence_level(),
                            -RANK           => $cs->rank(),
                            -DEFAULT        => $cs->is_default(),
                            -VERSION        => $cs->version() );
    $tgt_csa->store($tcs);
    push @$tcss, $tcs;
    # copy metacoord
    $src->dbc()->sql_helper()->execute_no_return(
      -SQL =>
'select table_name, max_length from meta_coord where coord_system_id=?',
      -PARAMS   => [ $cs->dbID() ],
      -CALLBACK => sub {
        my ( $table, $max_length ) = @{ $_[0] };
        $tgt->dbc()->sql_helper()->execute_update(
          -SQL =>
'insert into meta_coord(table_name, coord_system_id, max_length) values(?,?,?)',
          -PARAMS => [ $table, $tcs->dbID(), $max_length ] );
        return;
      } );
  } ## end foreach my $cs ( sort { $a->dbID...})
      # seq regions
  my $tgt_sa             = $tgt->get_SliceAdaptor();
  my $tgt_aa             = $tgt->get_AttributeAdaptor();
  my $tgt_syna           = $tgt->get_SeqRegionSynonymAdaptor();
  my $src_dba            = $src->get_DBEntryAdaptor();
  my $tgt_dba            = $tgt->get_DBEntryAdaptor();
  my $tgt_seqs_by_src_id = {};
  $logger->info("Copying seq regions");

  for my $cs ( @{$tcss} ) {
    $logger->info(
                "Copying seq regions for coord system " . $cs->name() );
    for my $slice (
               @{ $src->get_SliceAdaptor()->fetch_all( $cs->name() ) } )
    {
      $logger->info("Copying seq region " . $slice->seq_region_name() );

      my $tslice =
        Bio::EnsEMBL::Slice->new(
                       -SEQ_REGION_NAME   => $slice->seq_region_name(),
                       -COORD_SYSTEM      => $cs,
                       -START             => $slice->start(),
                       -END               => $slice->end(),
                       -SEQ_REGION_LENGTH => $slice->seq_region_length()
        );

      if ( $cs->is_sequence_level() ) {
        my $seq = $slice->seq();
        $tgt_sa->store( $tslice, \$seq );
      }
      else {
        $tgt_sa->store($tslice);
      }
      ## attributes (except for xref_id which needs special handling)
      my $attrs = [];
      for my $attr ( @{ $slice->get_all_Attributes() } ) {
        if ( $attr->code() eq 'xref_id' ) {
          my $dbe =
            $self->_copy_dbentry( $tgt,
                                  $src_dba->fetch_by_dbID($attr->value()
                                  ) );
          $tgt_dba->store($dbe);
          push @$attrs,
            Bio::EnsEMBL::Attribute->new(
                                   -CODE        => $attr->code(),
                                   -NAME        => $attr->name(),
                                   -DESCRIPTION => $attr->description(),
                                   -VALUE       => $dbe->dbID() );

        }
        else {
          push @$attrs,
            Bio::EnsEMBL::Attribute->new(
                                   -CODE        => $attr->code(),
                                   -NAME        => $attr->name(),
                                   -DESCRIPTION => $attr->description(),
                                   -VALUE       => $attr->value() );
        }
      }
      $logger->debug( "Storing " .
                      scalar(@$attrs) . " attrs on " .
                      $tslice->get_seq_region_id() );
      $tgt_aa->store_on_Slice( $tslice, $attrs );
      ## synonyms
      for my $syn ( @{ $slice->get_all_synonyms() } ) {
        $logger->debug( "Storing synonym " . $syn->name() . " on " .
                        $tslice->get_seq_region_id() );
        $tgt_syna->dbc()->sql_helper()->execute_update(
               -SQL => "delete from seq_region_synonym where synonym=?",
               -PARAMS => [ $syn->name() ] );
        $tgt_syna->store(
                        Bio::EnsEMBL::SeqRegionSynonym->new(
                          -synonym        => $syn->name(),
                          -external_db_id => $syn->external_db_id(),
                          -seq_region_id => $tslice->get_seq_region_id()
                        ) );
      }
      $tgt_seqs_by_src_id->{ $slice->get_seq_region_id() } = $tslice;
    } ## end for my $slice ( @{ $src...})
  } ## end for my $cs ( @{$tcss} )
      # assemblies
  ## may have to load directly
  $logger->info("Copying assembly mappings");
  $src->dbc()->sql_helper->execute_no_return(
    -CALLBACK => sub {
      my ( $asm_seq_region_id, $cmp_seq_region_id, $asm_start, $asm_end,
           $cmp_start, $cmp_end, $ori )
        = @{ shift @_ };
      $tgt->dbc()->sql_helper()->execute_update(
        -SQL =>
q/insert into assembly(asm_seq_region_id,cmp_seq_region_id,asm_start,asm_end,cmp_start,cmp_end,ori) 
	  values(?,?,?,?,?,?,?)/,
        -PARAMS => [ $tgt_seqs_by_src_id->{$asm_seq_region_id}
                       ->get_seq_region_id(),
                     $tgt_seqs_by_src_id->{$cmp_seq_region_id}
                       ->get_seq_region_id(),
                     $asm_start,
                     $asm_end,
                     $cmp_start,
                     $cmp_end,
                     $ori ] );
      return;
    },
    -SQL =>
q/select asm_seq_region_id,cmp_seq_region_id,asm_start,asm_end,cmp_start,cmp_end,ori 
	from assembly a join seq_region s on (a.asm_seq_region_id=s.seq_region_id) 
	join coord_system cs using (coord_system_id) 
	where species_id=?/,
    -PARAMS => [ $src->species_id() ] );

  $tgt_sa->_build_circular_slice_cache();

  $logger->info("Finished copying assembly");
  return;
} ## end sub copy_assembly

sub copy_features {
  my ( $self, $src, $tgt ) = @_;
  $self->logger()->info("Copying features");
  # genes & all the trimmings
  $self->copy_genes( $src, $tgt );
  # operons
  $self->copy_operons( $src, $tgt );
  # simple_features
  $self->copy_simple_features( $src, $tgt );
  # repeat_features
  $self->copy_repeat_features( $src, $tgt );
  # repeat_features
  $self->copy_density_features( $src, $tgt );
}

sub copy_genes {
  my ( $self, $src, $tgt ) = @_;
  $self->logger()->info("Copying genes");
  # iterate over slices from src
  my $src_sa  = $src->get_SliceAdaptor();
  my $tgt_sa  = $tgt->get_SliceAdaptor();
  my $src_ga  = $src->get_GeneAdaptor();
  my $tgt_ga  = $tgt->get_GeneAdaptor();
  my $tgt_dba = $tgt->get_DBEntryAdaptor();
  for my $slice ( @{ $src_sa->fetch_all('toplevel') } ) {
    my $tslice = $tgt_sa->fetch_by_name( $slice->name() );
    $self->logger()->info( "Copying genes to " . $tslice->name() );
    for my $gene ( @{ $src_ga->fetch_all_by_Slice($slice) } ) {
      $self->logger()->debug( "Copying gene " . $gene->stable_id() );
      my $gdisplay_xref =
        $self->_copy_dbentry( $tgt, $gene->display_xref() );
      my $tgene =
        Bio::EnsEMBL::Gene->new(
           -START        => $gene->start(),
           -END          => $gene->end(),
           -STRAND       => $gene->strand(),
           -SLICE        => $tslice,
           -STABLE_ID    => $gene->stable_id(),
           -VERSION      => $gene->version(),
           -DISPLAY_XREF => $gdisplay_xref,
           -DESCRIPTION  => $gene->description(),
           -ANALYSIS => $self->_get_analysis( $tgt, $gene->analysis() ),
           -CREATED_DATE  => $gene->created_date(),
           -MODIFIED_DATE => $gene->modified_date(),
           -BIOTYPE       => $gene->biotype(),
           -SOURCE        => $gene->source(),
           -IS_CURRENT    => $gene->is_current() );
      if ( defined $gdisplay_xref ) {
        $tgene->add_DBEntry($gdisplay_xref);
      }
      my $canonical_transcript = $gene->canonical_transcript();
      for my $transcript ( @{ $gene->get_all_Transcripts } ) {
        $self->logger()
          ->debug( "Copying transcript " . $transcript->stable_id() );
        my $tdisplay_xref =
          $self->_copy_dbentry( $tgt, $transcript->display_xref() );
#$tgt_dba->store($tdisplay_xref, undef, undef, 1);    # don't always get release coming through so ignore
        my $ttranscript =
          Bio::EnsEMBL::Transcript->new(
                -START  => $transcript->seq_region_start(),
                -END    => $transcript->seq_region_end(),
                -STRAND => $transcript->strand(),
                -SLICE  => $tslice,
                -ANALYSIS =>
                  $self->_get_analysis( $tgt, $transcript->analysis() ),
                -STABLE_ID     => $transcript->stable_id(),
                -VERSION       => $transcript->version(),
                -DISPLAY_XREF  => $tdisplay_xref,
                -CREATED_DATE  => $transcript->created_date(),
                -MODIFIED_DATE => $transcript->modified_date(),
                -DESCRIPTION   => $transcript->description(),
                -BIOTYPE       => $transcript->biotype(),
                -IS_CURRENT    => $transcript->is_current() );
        if ( defined $tdisplay_xref ) {
          $ttranscript->add_DBEntry($tdisplay_xref);
        }
        # translation
        my $translation = $transcript->translation();
        my $start_exon;
        my $end_exon;
        for my $exon ( @{ $transcript->get_all_Exons() } ) {
          my $texon =
            Bio::EnsEMBL::Exon->new(
                      -START  => $exon->seq_region_start(),
                      -END    => $exon->seq_region_end(),
                      -STRAND => $exon->strand(),
                      -SLICE  => $tslice,
                      -ANALYSIS =>
                        $self->_get_analysis( $tgt, $exon->analysis() ),
                      -PHASE           => $exon->phase(),
                      -END_PHASE       => $exon->end_phase(),
                      -STABLE_ID       => $exon->stable_id(),
                      -VERSION         => $exon->version(),
                      -CREATED_DATE    => $exon->created_date(),
                      -MODIFIED_DATE   => $exon->modified_date(),
                      -IS_CURRENT      => $exon->is_current(),
                      -IS_CONSTITUTIVE => $exon->is_constitutive() );
          $ttranscript->add_Exon($texon);
          if ( defined $translation &&
               $translation->start_Exon()->stable_id() eq
               $texon->stable_id() )
          {
            $start_exon = $texon;
          }
          if ( defined $translation &&
            $translation->end_Exon()->stable_id() eq $texon->stable_id()
            )
          {
            $end_exon = $texon;
          }
        } ## end for my $exon ( @{ $transcript...})

        if ( defined $translation ) {
          $self->logger()
            ->debug(
                   "Copying translation " . $translation->stable_id() );

          my $ttranslation =
            Bio::EnsEMBL::Translation->new(
                         -START_EXON    => $start_exon,
                         -END_EXON      => $end_exon,
                         -SEQ_START     => $translation->start(),
                         -SEQ_END       => $translation->end(),
                         -STABLE_ID     => $translation->stable_id(),
                         -VERSION       => $translation->version(),
                         -CREATED_DATE  => $translation->created_date(),
                         -MODIFIED_DATE => $translation->modified_date()
            );
          $ttranscript->translation($ttranslation);
          $self->_copy_dbentries( $tgt, $translation, $ttranslation );
          $self->_copy_attrs( $translation, $ttranslation );
          # also do protein features
          my $pfs = {};
          for my $pf ( @{ $translation->get_all_ProteinFeatures() } ) {

            my $key = join( "-",
                            $pf->hseqname(), $pf->hstart(), $pf->hend(),
                            $pf->analysis()->logic_name() );
            next if defined $pfs->{$key};
            $pfs->{$key} = 1;

            $self->logger()->debug("Copying protein feature $key");

            my $tpf =
              Bio::EnsEMBL::ProteinFeature->new(
                        -START        => $pf->start(),
                        -END          => $pf->end(),
                        -STRAND       => $pf->strand(),
                        -SLICE        => $tslice,
                        -HSTART       => $pf->hstart(),
                        -HEND         => $pf->hend(),
                        -HSTRAND      => $pf->hstrand(),
                        -HDESCRIPTION => $pf->hdescription(),
                        -SCORE        => $pf->score(),
                        -PERCENT_ID   => $pf->percent_id(),
                        -HSEQNAME     => $pf->hseqname(),
                        -ANALYSIS =>
                          $self->_get_analysis( $src, $pf->analysis() ),
                        -INTERPRO_AC => $pf->interpro_ac() );
            $ttranslation->add_ProteinFeature($tpf);
          } ## end for my $pf ( @{ $translation...})
        } ## end if ( defined $translation)

        $tgene->add_Transcript($ttranscript);
        if ( defined $canonical_transcript &&
             $ttranscript->stable_id() eq
             $canonical_transcript->stable_id() )
        {
          $tgene->canonical_transcript($ttranscript);
        }
        $self->_copy_dbentries( $tgt, $transcript, $ttranscript );
        $self->_copy_attrs( $transcript, $ttranscript );
      } ## end for my $transcript ( @{...})
      $self->_copy_dbentries( $tgt, $gene, $tgene );
      $self->_copy_attrs( $gene, $tgene );
      # store gene
      if ( scalar( @{ $tgene->get_all_Transcripts() } ) == 0 ) {
        $self->logger()
          ->warn( "Not storing gene " . $tgene->stable_id() .
                  " - no transcripts found" );
      }
      else {
        $self->logger()->debug( "Storing gene " . $tgene->stable_id() );
        $tgt_ga->store($tgene);
      }
    } ## end for my $gene ( @{ $src_ga...})
  } ## end for my $slice ( @{ $src_sa...})
  $self->logger()->info("Finished copying genes");
  return;
} ## end sub copy_genes

sub copy_operons {
  my ( $self, $src, $tgt ) = @_;
  $self->logger()->info("Copying operons");
  # iterate over slices from src
  my $src_sa = $src->get_SliceAdaptor();
  my $tgt_sa = $tgt->get_SliceAdaptor();
  my $src_oa = $src->get_OperonAdaptor();
  my $tgt_oa = $tgt->get_OperonAdaptor();
  my $tgt_ga = $tgt->get_GeneAdaptor();
  for my $slice ( @{ $src_sa->fetch_all('toplevel') } ) {
    my $tslice = $tgt_sa->fetch_by_name( $slice->name() );
    $self->logger()->info( "Copying operons to " . $tslice->name() );
  OPERON:
    for my $operon ( @{ $src_oa->fetch_all_by_Slice($slice) } ) {
      $self->logger()
        ->debug( "Copying operon " . $operon->stable_id() );
      eval {
        my $toperon =
          Bio::EnsEMBL::Operon->new(
                    -START         => $operon->seq_region_start(),
                    -END           => $operon->seq_region_end(),
                    -STRAND        => $operon->seq_region_strand(),
                    -SLICE         => $tslice,
                    -STABLE_ID     => $operon->stable_id(),
                    -DISPLAY_LABEL => $operon->display_label(),
                    -ANALYSIS =>
                      $self->_get_analysis( $tgt, $operon->analysis() ),
                    -CREATED_DATE  => $operon->created_date(),
                    -MODIFIED_DATE => $operon->modified_date(),
                    -VERSION       => $operon->version() );
        $self->_copy_dbentries( $tgt, $operon, $toperon );
        for my $operon_transcript (
                             @{ $operon->get_all_OperonTranscripts() } )
        {
          my $toperon_transcript =
            Bio::EnsEMBL::OperonTranscript->new(
                  -START     => $operon_transcript->seq_region_start(),
                  -END       => $operon_transcript->seq_region_end(),
                  -STRAND    => $operon_transcript->seq_region_strand(),
                  -SLICE     => $tslice,
                  -STABLE_ID => $operon_transcript->stable_id(),
                  -DISPLAY_LABEL => $operon_transcript->display_label(),
                  -ANALYSIS =>
                    $self->_get_analysis( $tgt, $operon->analysis() ),
                  -CREATED_DATE  => $operon_transcript->created_date(),
                  -MODIFIED_DATE => $operon_transcript->modified_date(),
                  -VERSION       => $operon->version() );
          $self->_copy_dbentries( $tgt, $operon_transcript,
                                  $toperon_transcript );
          for my $gene ( @{ $operon_transcript->get_all_Genes() } ) {
            $toperon_transcript->add_Gene(
                    $tgt_ga->fetch_by_stable_id( $gene->stable_id() ) );
          }
          $toperon->add_OperonTranscript($toperon_transcript);
        }
        $tgt_oa->store($toperon);
      };
      if ($@) {
        next OPERON;
      }
    } ## end for my $operon ( @{ $src_oa...})
  } ## end for my $slice ( @{ $src_sa...})
} ## end sub copy_operons

sub copy_simple_features {
  my ( $self, $src, $tgt ) = @_;
  $self->logger()->info("Copying simple features");
  my $src_sa = $src->get_SliceAdaptor();
  my $tgt_sa = $tgt->get_SliceAdaptor();
  my $src_fa = $src->get_SimpleFeatureAdaptor();
  my $tgt_fa = $tgt->get_SimpleFeatureAdaptor();
  for my $slice ( @{ $src_sa->fetch_all('toplevel') } ) {
    my $tslice = $tgt_sa->fetch_by_name( $slice->name() );
    $self->logger()
      ->info( "Copying simple features for " . $tslice->name() );
    for my $feature ( @{ $src_fa->fetch_all_by_Slice($slice) } ) {
      $self->logger()
        ->debug( "Copying " . $feature->display_label() . " at " .
                 $feature->slice()->name() );
      my $tfeature =
        Bio::EnsEMBL::SimpleFeature->new(
        -START    => $feature->seq_region_start(),
        -END      => $feature->seq_region_end(),
        -STRAND   => $feature->seq_region_strand(),
        -SLICE    => $tslice,
        -ANALYSIS => $self->_get_analysis( $tgt, $feature->analysis() ),
        -DISPLAY_LABEL => $feature->display_label(),
        -SCORE         => $feature->score() );
      $tgt_fa->store($tfeature);
    }
  }
  $self->logger()->info("Finished copying simple features");
  return;
} ## end sub copy_simple_features

sub copy_repeat_features {
  my ( $self, $src, $tgt ) = @_;
  $self->logger()->info("Copying repeat features");
  my $src_sa = $src->get_SliceAdaptor();
  my $tgt_sa = $tgt->get_SliceAdaptor();
  my $src_fa = $src->get_RepeatFeatureAdaptor();
  my $tgt_fa = $tgt->get_RepeatFeatureAdaptor();
  my $rcs    = {};
  for my $slice ( @{ $src_sa->fetch_all('toplevel') } ) {
    my $tslice = $tgt_sa->fetch_by_name( $slice->name() );
    $self->logger()
      ->info( "Copying repeat features for " . $tslice->name() );
    for my $rf ( @{ $src_fa->fetch_all_by_Slice($slice) } ) {
      my $trc;
      if ( defined $rf->repeat_consensus() ) {
        $trc =
          Bio::EnsEMBL::RepeatConsensus->new(
               -REPEAT_CONSENSUS =>
                 $rf->repeat_consensus()->repeat_consensus(),
               -NAME         => $rf->repeat_consensus()->name(),
               -REPEAT_CLASS => $rf->repeat_consensus()->repeat_class(),
               -LENGTH       => $rf->repeat_consensus()->length(),
               -TYPE         => $rf->repeat_consensus()->repeat_type()
          );
      }
      my $trf =
        Bio::EnsEMBL::RepeatFeature->new(
             -SLICE    => $tslice,
             -START    => $rf->seq_region_start(),
             -END      => $rf->seq_region_end(),
             -STRAND   => $rf->seq_region_strand(),
             -ANALYSIS => $self->_get_analysis( $tgt, $rf->analysis() ),
             -REPEAT_CONSENSUS => $trc,
             -HSTART           => $rf->hstart(),
             -HEND             => $rf->hend(),
             -SCORE            => $rf->score() );
      $tgt_fa->store($trf);
    } ## end for my $rf ( @{ $src_fa...})
  } ## end for my $slice ( @{ $src_sa...})
  $self->logger()->info("Finished copying repeat features");
  return;
} ## end sub copy_repeat_features

sub copy_density_features {
  my ( $self, $src, $tgt ) = @_;
  $self->logger()->info("Copying density features");
  my $src_sa = $src->get_SliceAdaptor();
  my $tgt_sa = $tgt->get_SliceAdaptor();
  my $src_fa = $src->get_DensityFeatureAdaptor();
  my $tgt_fa = $tgt->get_DensityFeatureAdaptor();

  # first, need to get all our types
  for my $type ( @{ $src->get_DensityTypeAdaptor()->fetch_all() } ) {
    eval {
      my $ttype =
        Bio::EnsEMBL::DensityType->new(
         -ANALYSIS   => $self->_get_analysis( $tgt, $type->analysis() ),
         -BLOCKSIZE  => $type->block_size(),
         -VALUE_TYPE => $type->value_type() );
      $self->logger()
        ->info( "Copying " . $type->analysis()->logic_name() .
                " density features" );
      for my $slice ( @{ $src_sa->fetch_all('toplevel') } ) {
        my $tslice = $tgt_sa->fetch_by_name( $slice->name() );
        $self->logger()
          ->info( "Copying " . $type->analysis()->logic_name() .
                  " density features for " . $tslice->name() );
        for my $df ( @{$src_fa->fetch_all_by_Slice( $slice,
                                       $type->analysis()->logic_name() )
                     } )
        {
          my $tdf =
            Bio::EnsEMBL::DensityFeature->new(
                                 -SEQ_REGION => $tslice,
                                 -START      => $df->seq_region_start(),
                                 -END        => $df->seq_region_end(),
                                 -DENSITY_TYPE  => $ttype,
                                 -DENSITY_VALUE => $df->density_value(),
            );

          $tgt_fa->store($tdf);
        }

      }
      if ($@) {
        $self->logger()
          ->warn( "Could not copy density feature: " . $@ );
      }
    };
  } ## end for my $type ( @{ $src->get_DensityTypeAdaptor...})
  $self->logger()->info("Finished copying density features");
  return;
} ## end sub copy_density_features

sub _copy_attrs {
  my ( $self, $src, $tgt ) = @_;
  my @attributes = ();
  for my $attr ( @{ $src->get_all_Attributes() } ) {
    push @attributes, $self->_copy_attr($attr);
  }
  $tgt->add_Attributes(@attributes);
  return;
}

sub _copy_attr {
  my ( $self, $attr ) = @_;
  return undef if !defined $attr;
  return
    Bio::EnsEMBL::Attribute->new( -CODE        => $attr->code(),
                                  -NAME        => $attr->name(),
                                  -DESCRIPTION => $attr->description(),
                                  -VALUE       => $attr->value() );
}

sub _copy_dbentries {
  my ( $self, $tgt_dba, $src, $tgt ) = @_;
  for my $dbentry ( @{ $src->get_all_DBEntries() } ) {
    $tgt->add_DBEntry( $self->_copy_dbentry( $tgt_dba, $dbentry ) );
  }
  return;
}

sub _copy_dbentry {
  my ( $self, $dba, $xref ) = @_;
  return undef if !defined $xref;
  my $dbe;
  if ( ref($xref) eq 'Bio::EnsEMBL::OntologyXref' ) {
    $dbe =
      Bio::EnsEMBL::OntologyXref->new(
           -PRIMARY_ID  => $xref->primary_id(),
           -VERSION     => $xref->version(),
           -DBNAME      => $xref->dbname(),
           -DISPLAY_ID  => $xref->display_id(),
           -DESCRIPTION => $xref->description(),
           -RELEASE     => $xref->release(),
           -INFO_TYPE   => $xref->info_type(),
           -ANALYSIS => $self->_get_analysis( $dba, $xref->analysis() ),
           -INFO_TEXT => $xref->info_text() );
    foreach my $lt ( @{ $xref->get_all_linkage_info() } ) {
      $dbe->add_linkage_type( $lt->[0],
                              $self->_copy_dbentry( $dba, $lt->[1] ) );
    }
    # TODO need to support associated_xrefs at some point
  }
  elsif ( ref($xref) eq 'Bio::EnsEMBL::IdentityXref' ) {
    $dbe =
      Bio::EnsEMBL::IdentityXref->new(
           -PRIMARY_ID  => $xref->primary_id(),
           -VERSION     => $xref->version(),
           -DBNAME      => $xref->dbname(),
           -DISPLAY_ID  => $xref->display_id(),
           -DESCRIPTION => $xref->description(),
           -RELEASE     => $xref->release(),
           -INFO_TYPE   => $xref->info_type(),
           -INFO_TEXT   => $xref->info_text(),
           -ANALYSIS => $self->_get_analysis( $dba, $xref->analysis() ),
           -SCORE    => $xref->score(),
           -EVALUE   => $xref->evalue(),
           -CIGAR_LINE       => $xref->cigar_line(),
           -XREF_IDENTITY    => $xref->xref_identity(),
           -XREF_START       => $xref->xref_start(),
           -XREF_END         => $xref->xref_end(),
           -ENSEMBL_IDENTITY => $xref->ensembl_identity(),
           -ENSEMBL_START    => $xref->ensembl_start(),
           -ENSEMBL_END      => $xref->ensembl_end() );
  }
  else {
    $dbe =
      Bio::EnsEMBL::DBEntry->new(
           -PRIMARY_ID  => $xref->primary_id(),
           -VERSION     => $xref->version(),
           -DBNAME      => $xref->dbname(),
           -DISPLAY_ID  => $xref->display_id(),
           -DESCRIPTION => $xref->description(),
           -RELEASE     => $xref->release(),
           -INFO_TYPE   => $xref->info_type(),
           -ANALYSIS => $self->_get_analysis( $dba, $xref->analysis() ),
           -INFO_TEXT => $xref->info_text() );
  }
  for my $synonym ( @{ $xref->get_all_synonyms() } ) {
    $dbe->add_synonym($synonym);
  }
  return $dbe;
} ## end sub _copy_dbentry

sub _get_analysis {
  my ( $self, $dba, $analysis ) = @_;
  return undef if !defined $analysis;
  return $dba->get_AnalysisAdaptor()
    ->fetch_by_logic_name( $analysis->logic_name() );
}

1;
