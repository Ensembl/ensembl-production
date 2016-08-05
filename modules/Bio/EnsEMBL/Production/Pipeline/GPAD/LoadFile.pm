=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::GPAD::LoadFile;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use base ('Bio::EnsEMBL::Hive::Process');

sub param_defaults {
    return {
     delete_existing => 1,
    };
}


sub fetch_input {
    my ($self) = @_;

    # Delete by xref.info_type='PROJECTION' OR 'DEPENDENT'
    my $sql_delete_1 = 'DELETE x,ox,onx  FROM xref x 
		      JOIN object_xref ox USING (xref_id) 
		      JOIN ontology_xref onx USING (object_xref_id) 
		      JOIN analysis a USING (analysis_id)
		      JOIN translation tl ON (ox.ensembl_id=tl.translation_id) 
		      JOIN transcript tf USING (transcript_id) 
		      JOIN seq_region s USING (seq_region_id) 
		      JOIN coord_system c USING (coord_system_id) 
		      WHERE x.external_db_id=1000 
		      AND c.species_id=?
		      AND x.info_type="PROJECTION" 
		      OR  x.info_type="DEPENDENT"';

    # Delete by analysis.logic_name='go_projection'
    # this is to cater for eg! cores, 
    # whereby e! cores didn't has a specific analysis.logic_name 
    # defined for 'go_projection' 
    my $sql_delete_2 = 'DELETE x,ox,onx  FROM xref x 
                      JOIN object_xref ox USING (xref_id) 
                      JOIN ontology_xref onx USING (object_xref_id) 
                      JOIN analysis a USING (analysis_id)
                      JOIN translation tl ON (ox.ensembl_id=tl.translation_id) 
                      JOIN transcript tf USING (transcript_id) 
                      JOIN seq_region s USING (seq_region_id) 
                      JOIN coord_system c USING (coord_system_id) 
                      WHERE x.external_db_id=1000 
		      AND a.logic_name="go_projection" 
                      AND c.species_id=?';

    $self->param('sql_delete_1', $sql_delete_1);
    $self->param('sql_delete_2', $sql_delete_2);

return 0;
}

sub run {
    my ($self)  = @_;

    my $reg  = 'Bio::EnsEMBL::Registry';

    my $species;
    # Remove existing projected GO annotations from GOA 
    if ($self->param_required('delete_existing')) {
        $species = 'puccinia_graminis';
        my $dba          = $reg->get_DBAdaptor($species, "core");         
        my $sql_delete_1 = $self->param_required('sql_delete_1');
        my $sql_delete_2 = $self->param_required('sql_delete_2');
        my $sth_1        = $dba->dbc->prepare($sql_delete_1);
        my $sth_2        = $dba->dbc->prepare($sql_delete_2);

        $sth_1->execute($dba->species_id());
        $sth_2->execute($dba->species_id());
        $sth_1->finish();
        $sth_2->finish();
    }

    my $odba = $reg->get_adaptor('multi', 'ontology', 'OntologyTerm');
    my $gos  = $self->fetch_ontology($odba);
    my $file = $self->param_required('gpad_file'); 

    open(FILE, $file) or die "Could not open '$file' for reading : $!";

    while (<FILE>) {
      chomp $_;
      next if $_ =~ /^!/;
# UniProtKB       A0A060MZW1      involved_in     GO:0042254      GO_REF:0000002  ECO:0000256     InterPro:IPR001790|InterPro:IPR030670           20160716        InterPro                go_evidence=IEA|tgt_species=entamoeba_histolytica
      my ($db, $db_object_id, $qualifier, $go_id, $go_ref, $eco, $with, $taxon_id, $date, $assigned_by, $annotation_extension, $annotation_properties) = split /\t/,$_ ;
      # Parse annotation information
      # $go_evidence and $tgt_species should always be populated
      # The remaining fields might or might not, but they should alwyays be available in that order
      my ($go_evidence, $tgt_species, $tgt_gene, $tgt_feature, $src_species, $src_gene, $src_protein) = split /\|/, $annotation_properties;
      my ($tgt_protein, $tgt_transcript);
      $tgt_gene    =~ s/tgt_gene=\w+:// if $tgt_gene;
      $tgt_species =~ s/tgt_species=// if $tgt_species;
########
next unless $tgt_species=~/$species/;
#######
      $go_evidence =~ s/go_evidence=// if $go_evidence;
 
      # If the tgt_feature field is populated, it could be tgt_protein or tgt_transcript
      if (defined $tgt_feature) {
         if ($tgt_feature =~ /tgt_protein/) {
             $tgt_feature =~ s/tgt_protein=\w+://;
             $tgt_protein = $tgt_feature;
         } 
         elsif ($tgt_feature =~ /tgt_transcript/) {
             $tgt_feature =~ s/tgt_transcript=//;
             $tgt_transcript = $tgt_feature;
         } else {
             $self->warning("Error parsing $annotation_properties, no match for $tgt_feature\n");
         }
      }

     my (%adaptor_hash, %dbe_adaptor_hash, %t_adaptor_hash );
     my ($tl_adaptor, $dbe_adaptor, $t_adaptor);
     my ($translation, $translations);
     my (%translation_hash, %species_missed, %species_added);
     # When no stable_id or not found in db, try corresponding direct xref
     my %species_added_via_xref;
     # When GO mapped to Ensembl stable_id, add as direct xref
     my %species_added_via_tgt;
     my %ontology_definition;

     if ($adaptor_hash{$tgt_species}) {
        # If the file lists a species not in the current registry, skip it
        if ($adaptor_hash{$tgt_species} eq 'undefined') { 
	   $self->warning("Could not find $tgt_species in registry\n");
           next; 
        }
    	$tl_adaptor  = $adaptor_hash{$tgt_species};
    	$dbe_adaptor = $dbe_adaptor_hash{$tgt_species};
    	$t_adaptor   = $t_adaptor_hash{$tgt_species};
     } else {
    	if (!$reg->get_alias($tgt_species)) {
      	   $adaptor_hash{$tgt_species} = 'undefined';
      	   next;
        }
       $tl_adaptor  = $reg->get_adaptor($tgt_species, 'core', 'Translation');
       $dbe_adaptor = $reg->get_adaptor($tgt_species, 'core', 'DBEntry');
       $t_adaptor   = $reg->get_adaptor($tgt_species, 'core', 'Transcript');
       $adaptor_hash{$tgt_species}     = $tl_adaptor;
       $dbe_adaptor_hash{$tgt_species} = $dbe_adaptor;
       $t_adaptor_hash{$tgt_species}   = $t_adaptor;
    }

    my $info_type = 'DIRECT';
    #my $info_type = 'DEPENDENT';
    #if ($src_species) { $info_type = 'PROJECTION' ; }

    # Create new GO dbentry object
    my $go_xref = Bio::EnsEMBL::OntologyXref->new(
    	-primary_id  => $go_id,
	-display_id  => $go_id,
	-info_text   => $go_ref,
    	-info_type   => $info_type,
    	-description => $$gos{$go_id},#$ontology_definition{$go_id},
    	-linkage_annotation => $go_evidence,
    	-dbname      => 'GO'
   ); 

   # Retrieve existing or create new analysis object
   my $analysis_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species , "core", "analysis" );
   my $analysis; 
   $analysis = $analysis_adaptor->fetch_by_logic_name('go_projection');
   
   # Update to existing analysis object
   # to reflect import from GOA  
   if(defined $analysis){
     $analysis->description('Gene Ontology xrefs projection data from GOA');
     $analysis->display_label('GO projected xrefs from GOA');
     $analysis_adaptor->update($analysis);
   }

   if(!defined $analysis){
   #my $analysis = Bio::EnsEMBL::Analysis->
     $analysis = Bio::EnsEMBL::Analysis->
        new( -logic_name      => 'go_projection',
             -db              => 'GO',
             -db_version      => '',
             -program         => 'go_projection',
             -description     => 'Gene Ontology xrefs projection data from GOA',
             -display_label   => 'GO projected xrefs from GOA',
          );

   }
   $go_xref->analysis($analysis);

   # There could technically be more than one xref with the same display_label
   # In practice, we just want to add it as master_xref, so the first one is fine
   my $uniprot_xrefs = $dbe_adaptor->fetch_all_by_name($db_object_id);
   $go_xref->add_linkage_type($go_evidence, $uniprot_xrefs->[0]);

   # If GOA did not provide a tgt_feature, we have to guess the correct target based on our xrefs
   # This is slower, hence only used if nothing better is available
   if (!defined $tgt_feature) {
      $translations = $tl_adaptor->fetch_all_by_external_name($db_object_id);

      foreach my $translation (@$translations) {
        $dbe_adaptor->store($go_xref, $translation->dbID, 'Translation', 1, $uniprot_xrefs->[0]);
        $species_added_via_xref{$tgt_species}++;
      }
      # If GOA provide a tgt_protein, this is the direct mapping to Ensembl feature
      # This becomes our object for the new xref
   } elsif (defined $tgt_protein) {
      if ($translation_hash{$tgt_protein}) {
          $translation = $translation_hash{$tgt_protein};
      } else {
          $translation = $tl_adaptor->fetch_by_stable_id($tgt_protein);
          $translation_hash{$tgt_protein} = $translation;
      }
    
      if (defined $translation) {
      	$dbe_adaptor->store($go_xref, $translation->dbID, 'Translation', 1, $uniprot_xrefs->[0]);
      	$species_added_via_tgt{$tgt_species}++;
      } else {
      	$species_missed{$tgt_species}++;
      }
   # If GOA provide a tgt_transcript, it could be a list of transcript mappings
   # We still need to fetch the translation as GOs are linked on protein level
   } elsif (defined $tgt_transcript) {
      my @tgt_transcripts = split(",", $tgt_transcript);

      foreach my $transcript (@tgt_transcripts) {
        if ($translation_hash{$transcript}) {
          $translation = $translation_hash{$transcript};
        } else {
          my $translation_transcript = $t_adaptor->fetch_by_stable_id($transcript);
          $translation = $tl_adaptor->fetch_by_Transcript($translation_transcript);
        }

       if (defined $translation) {
          $dbe_adaptor->store($go_xref, $translation->dbID, 'Translation', 1, $uniprot_xrefs->[0]);
          $species_added_via_tgt{$tgt_species}++;
       } else {
          $species_missed{$tgt_species}++;
       }
     }
  }

  # Disconnects from the database if 
  # there are no currently active statement handles. 
  $tl_adaptor->dbc->disconnect_if_idle();
  $dbe_adaptor->dbc->disconnect_if_idle();
  $t_adaptor->dbc->disconnect_if_idle();
  }# while FILE


return 0;
}

sub write_output {
    my ($self)  = @_;

return 0;
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
