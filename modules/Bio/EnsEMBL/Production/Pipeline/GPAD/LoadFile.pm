=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::GPAD::LoadFile;

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk and maurel@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::GPAD::LoadFile;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub run {
    my ($self)  = @_;
    # Parse filename to get $target_species
    my $species = $self->param_required('species');
    my $file = $self->param_required('gpad_file');
    my $logic_name = $self->param_required('logic_name');

    my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $species, 'core' );
    my $hive_dbc = $self->dbc;
    $hive_dbc->disconnect_if_idle() if defined $self->dbc;

    $self->log()->info("Loading $species from $file");

    # Remove existing projected GO annotations from GOA
    if ($self->param_required('delete_existing')) {
      $self->log()->info("Deleting existing terms");
      # Delete by analysis.logic_name='goa_import' for GOs mapped to translation
      my $translation_go_sql=qq/
        DELETE ox.*,onx.*,dx.*  FROM xref x
          JOIN object_xref ox USING (xref_id)
          LEFT JOIN ontology_xref onx USING (object_xref_id)
          LEFT JOIN dependent_xref dx USING (object_xref_id)
          JOIN analysis a USING (analysis_id)
          JOIN translation tl ON (ox.ensembl_id=tl.translation_id)
          JOIN transcript tf USING (transcript_id)
          JOIN seq_region s USING (seq_region_id)
          JOIN coord_system c USING (coord_system_id)
        WHERE x.external_db_id=1000
          AND c.species_id=?
          AND a.logic_name=?/;
      # Same deletes but for GOs mapped to transcripts
      my $transcript_go_sql=qq/
        DELETE ox.*,onx.*,dx.*  FROM xref x
          JOIN object_xref ox USING (xref_id)
          LEFT JOIN ontology_xref onx USING (object_xref_id)
          LEFT JOIN dependent_xref dx USING (object_xref_id)
          JOIN analysis a USING (analysis_id)
          JOIN transcript tf ON (ox.ensembl_id = tf.transcript_id)
          JOIN seq_region s USING (seq_region_id)
          JOIN coord_system c USING (coord_system_id)
        WHERE x.external_db_id=1000
          AND c.species_id=?
          AND a.logic_name=?/;

      $self->log()->debug("Deleting GO mapped to translation");
      $dba->dbc()->sql_helper()->execute_update(-SQL=>$translation_go_sql,-PARAMS=>[$dba->species_id(),$logic_name]);
      $self->log()->debug("Deleting GO mapped to transcript");
      $dba->dbc()->sql_helper()->execute_update(-SQL=>$transcript_go_sql,-PARAMS=>[$dba->species_id(),$logic_name]);
    }

    my $odba = Bio::EnsEMBL::Registry->get_adaptor('multi', 'ontology', 'OntologyTerm');
    my $gos  = $self->fetch_ontology($odba);
    $odba->dbc->disconnect_if_idle();
    
    # Retrieve existing or create new analysis object
    my $analysis_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species , "core", "analysis" );
    my $analysis = $analysis_adaptor->fetch_by_logic_name($logic_name);

    my $tl_adaptor  = $dba->get_TranslationAdaptor();
    my $dbe_adaptor = $dba->get_DBEntryAdaptor();
    my $t_adaptor   = $dba->get_TranscriptAdaptor();

    my (%translation_hash, %transcript_hash, %species_missed, %species_added);
    # When no stable_id or not found in db, try corresponding direct xref
    my %species_added_via_xref;
    # When GO mapped to Ensembl stable_id, add as direct xref
    my %species_added_via_tgt;
    # UniProt data is the latest, we might not have the links yet
    # This should be rare though, so numbers should stay low
    my %unmatched_uniprot;
    my %unmatched_rnacentral;
    my %unmatched_protein_id;
    my %unmatched_wormbase_transcript;
    my %unmatched_flybase_translation;
    open my $fh, "<", $file or die "Could not open '$file' for reading : $!";
    my $lineN = 0;
    while (<$fh>) {
      chomp $_;
      $lineN++;
      next if $_ =~ /^!/;

      my ($translation, $translations, $transcript, $transcripts, $is_protein, $is_transcript);

      $self->log()->debug($lineN . ": " . $_);
      # UniProtKB       A0A060MZW1      involved_in     GO:0042254      GO_REF:0000002  ECO:0000256     InterPro:IPR001790|InterPro:IPR030670           20160716        InterPro                tgt_species=entamoeba_histolytica|go_evidence=IEA
      #or
      # UniProtKB       A0A1I9WA83      enables GO:0004129      GO_REF:0000107  ECO:0000265     UniProtKB:P00403|ensembl:ENSP00000354876                20180303        Ensembl         tgt_species=ailuropoda_melanoleuca|tgt_gene=ensembl:ENSAMEG00000023439|tgt_protein=ensembl:ENSAMEP00000021356|src_species=homo_sapiens|src_gene=ensembl:ENSG00000198712|src_protein=ensembl:ENSP00000354876|go_evidence=IEA
      my ($db, $db_object_id, $qualifier, $go_id, $go_ref, $eco, $with, $taxon_id, $date, $assigned_by, $annotation_extension, $annotation_properties) = split /\t/,$_ ;
      # Parse annotation information
      # $go_evidence and $tgt_species should always be populated
      # The remaining fields might or might not, but they should alwyays be available in that order
      my ($go_evidence, $tgt_species, $tgt_gene, $tgt_protein, $tgt_transcript, $src_species, $src_gene, $src_protein, $precursor_rna);
      foreach my $annotation_propertie (split /\|/, $annotation_properties){
        if ($annotation_propertie =~ m/tgt_gene/){
          $annotation_propertie =~ s/tgt_gene=\w+://;
          $tgt_gene=$annotation_propertie;
        }
        elsif ($annotation_propertie =~ m/tgt_species/){
          $annotation_propertie =~ s/tgt_species=//;
          $tgt_species=$annotation_propertie;
        }
        elsif ($annotation_propertie =~ m/go_evidence/){
          $annotation_propertie =~ s/go_evidence=//;
          $go_evidence=$annotation_propertie;
        }
        elsif ($annotation_propertie =~ m/tgt_protein/){
          $annotation_propertie =~ s/tgt_protein=[\w\-]+://;
          $tgt_protein=$annotation_propertie;
        }
        elsif ($annotation_propertie =~ m/tgt_transcript/){
          $annotation_propertie =~ s/tgt_transcript=//;
          $tgt_transcript=$annotation_propertie;
        }
        elsif ($annotation_propertie =~ m/src_protein/){
          $annotation_propertie =~ s/src_protein=[\w\-]+://;
          $src_protein=$annotation_propertie;
        }
        elsif ($annotation_propertie =~ m/src_species/){
          $annotation_propertie =~ s/src_species=//;
          $src_species=$annotation_propertie;
        }
        elsif ($annotation_propertie =~ m/src_gene/){
          $annotation_propertie =~ s/src_gene=//;
          $src_gene=$annotation_propertie;
        }
        elsif ($annotation_propertie =~ m/precursor_rna/){
          $annotation_propertie =~ s/precursor_rna=//;
          $precursor_rna=$annotation_propertie;
        }
        else{
          $self->warning("Error parsing $annotation_propertie, not matching any expected annotation\n");
        }
      }

      # target species should always be the same as production name in the GOA file
      next unless $tgt_species=~/$species/;
 
      $self->log()->debug("Creating GO xref for $go_id");
      my $info_type = 'DIRECT';
      my $info_text = $assigned_by;
      if ($assigned_by =~ /Ensembl/ and defined $src_protein) {
        $info_text   = "from $src_species translation $src_protein";
        $info_type = 'PROJECTION'
      }
      
      # Create new GO dbentry object
      my $go_xref = Bio::EnsEMBL::OntologyXref->new(
						    -primary_id  => $go_id,
						    -display_id  => $go_id,
						    -info_text   => $info_text,
						    -info_type   => $info_type,
						    -description => $$gos{$go_id},
						    -linkage_annotation => $go_evidence,
						    -dbname      => 'GO'
						   ); 
      
      $go_xref->analysis($analysis);
      my $master_xref;
      # There could technically be more than one xref with the same display_label
      # In practice, we just want to add it as master_xref, so the first one is fine
      # Distinguish if data is UniProt (proteins), RNACentral (transcripts), Protein_id (proteins),
      # wormbase_transcript (transcripts), flybase_translation_id (translations)
      if ($db =~ /UniProt/) {
        $self->log()->debug("Adding linkage to UniProt");
        $is_protein = 1;
        my $uniprot_xrefs = $dbe_adaptor->fetch_all_by_name($db_object_id);
        my @master_xref = grep { $_->dbname =~ m/uniprot/i } @$uniprot_xrefs;
        if (scalar(@master_xref) !=0 ) {
          $master_xref = $master_xref[0];
          $go_xref->add_linkage_type($go_evidence, $master_xref);
        } else {
          $unmatched_uniprot{$tgt_species}++;
        }
      } elsif ($db =~ /RNAcentral/) {
        $self->log()->debug("Adding linkage to RNAcentral");
        $is_transcript = 1;
        # Accession is the version with taxonomy id appended, e.g. URS0000007FBA_9606
        # We store as URS0000007FBA, so need to remove everything from the _
        # precursor_rna could be a list of accessions
        my @precursor_rnas = split(",", $precursor_rna) if $precursor_rna;
        foreach my $rna (@precursor_rnas) {
          $rna =~ s/_[0-9]*//;
          $db_object_id = $rna;
          my $rnacentral_xrefs = $dbe_adaptor->fetch_all_by_name($db_object_id, 'RNAcentral');
          if (scalar(@$rnacentral_xrefs) != 0) {
            $master_xref = $rnacentral_xrefs->[0];
            $go_xref->add_linkage_type($go_evidence, $master_xref);
            $transcripts = $t_adaptor->fetch_all_by_external_name($db_object_id);
            foreach my $transcript (@$transcripts) {
              $dbe_adaptor->store($go_xref, $transcript->dbID, 'Transcript', 1, $master_xref);
              $species_added_via_xref{$tgt_species}++;
            }
          } else {
            $unmatched_rnacentral{$tgt_species}++;
          }
        }
      }
      elsif (lc($db) =~ /ena/) {
        $self->log()->debug("Adding linkage to Protein ID");
        $is_protein = 1;
        my $protein_id_xrefs = $dbe_adaptor->fetch_all_by_name($db_object_id, 'protein_id');
        if (scalar(@$protein_id_xrefs) !=0 ) {
          $master_xref = $protein_id_xrefs->[0];
          $go_xref->add_linkage_type($go_evidence, $master_xref);
        } else {
          $unmatched_protein_id{$tgt_species}++;
        }
      }
      elsif (lc($db) =~ /wormbase/) {
        $self->log()->debug("Adding linkage to Wormbase Transcript");
        $is_transcript = 1;
        my $wormbase_transcript_xrefs = $dbe_adaptor->fetch_all_by_name($db_object_id, 'wormbase_transcript');
        if (scalar(@$wormbase_transcript_xrefs) !=0 ) {
          $master_xref = $wormbase_transcript_xrefs->[0];
          $go_xref->add_linkage_type($go_evidence, $master_xref);
          $transcripts = $t_adaptor->fetch_all_by_external_name($db_object_id);
          foreach my $transcript (@$transcripts) {
            $dbe_adaptor->store($go_xref, $transcript->dbID, 'Transcript', 1, $master_xref);
            $species_added_via_xref{$tgt_species}++;
          }
        } else {
          $unmatched_wormbase_transcript{$tgt_species}++;
        }
      }
      elsif (lc($db) =~ /flybase/) {
        $self->log()->debug("Adding linkage to Flybase translation");
        $is_protein = 1;
        my $flybase_translation_xrefs = $dbe_adaptor->fetch_all_by_name($db_object_id, 'flybase_translation_id');
        if (scalar(@$flybase_translation_xrefs) !=0 ) {
          $master_xref = $flybase_translation_xrefs->[0];
          $go_xref->add_linkage_type($go_evidence, $master_xref);
        } else {
          $unmatched_flybase_translation{$tgt_species}++;
        }
      }
       else {
        $self->log()->debug("Adding default linkage");
        $go_xref->add_linkage_type($go_evidence);
      }
      
  if (defined $tgt_protein) {
	# If GOA provide a tgt_protein, this is the direct mapping to Ensembl feature
	# This becomes our object for the new xref	
	$self->log()->debug("Looking for protein $tgt_protein");
	if ($translation_hash{$tgt_protein}) {
          $translation = $translation_hash{$tgt_protein};
          $transcript = $transcript_hash{$tgt_protein};
	} else {
          $translation = $tl_adaptor->fetch_by_stable_id($tgt_protein);
          $transcript = $translation->transcript;
          $translation_hash{$tgt_protein} = $translation;
          $transcript_hash{$tgt_protein} = $transcript;
	}
	
	if (defined $translation) {
	  $self->log()->debug("Storing on transcript ".$transcript->dbID());
	  $dbe_adaptor->store($go_xref, $transcript->dbID, 'Transcript', 1, $master_xref);
	  $species_added_via_tgt{$tgt_species}++;
	} else {
	  $self->log()->debug("Protein $tgt_protein not found");
	  $species_missed{$tgt_species}++;
	}
	# If GOA provide a tgt_transcript, it could be a list of transcript mappings
      } elsif (defined $tgt_transcript) {
	
	$self->log()->debug("Handling tgt_transcripts $tgt_transcript");
	my @tgt_transcripts = split(",", $tgt_transcript);
	
	foreach my $transcript (@tgt_transcripts) {
	  $self->log()->debug("Storing on transcript ".$transcript->dbID());
	  $dbe_adaptor->store($go_xref, $transcript->dbID, 'Transcript', 1, $master_xref);
	  $species_added_via_tgt{$tgt_species}++;
	}
      }
         # If GOA did not provide a tgt_transcript or tgt_protein, we have to guess the correct target based on our xrefs
      # This is slower, hence only used if nothing better is available
      else {
	$self->log()->debug("Finding tgt_feature");
  if (defined $master_xref) {
    if ($is_protein) {
      $self->log()->debug("Finding protein $db_object_id");
      $translations = $tl_adaptor->fetch_all_by_external_name($db_object_id, $master_xref->dbname);
      if(scalar @$translations == 0) {
        $self->log()->debug("Could not find translation for $db_object_id");
      }
      # Protein xref is attached to translation
      # But GO term should be attached to transcript
      foreach my $translation (@$translations) {
        $self->log()->debug("Attaching via translation to transcript ".$translation->transcript()->dbID());
             $dbe_adaptor->store($go_xref, $translation->transcript->dbID, 'Transcript', 1, $master_xref);
        $species_added_via_xref{$tgt_species}++;
      }
    } elsif ($is_transcript) {
      $self->log()->debug("Finding transcript $db_object_id");
      $transcripts = $t_adaptor->fetch_all_by_external_name($db_object_id, $master_xref->dbname);
      foreach my $transcript (@$transcripts) {
        $self->log()->debug("Attaching to transcript ".$transcript->dbID());
        $dbe_adaptor->store($go_xref, $transcript->dbID(), 'Transcript', 1, $master_xref);
        $species_added_via_xref{$tgt_species}++;
           }
    } else {
      $self->log()->debug("Couldn't figure out how to find target feature");
    }
  } else {
    $self->log()->debug("Source xref not in core database");
  }
      }
    }
    
    close $fh;
    $dba->dbc->disconnect_if_idle();
    
    return;
  }

#############
##SUBROUTINES
#############
sub fetch_ontology {
  my ($self, $odba) = @_;
  
  my %ontology_definition;
  my $gos = $odba->fetch_all();
  
  foreach my $go (@$gos) {
    $ontology_definition{$go->accession} = $go->name();
  }
  
  return \%ontology_definition;
}

1;
