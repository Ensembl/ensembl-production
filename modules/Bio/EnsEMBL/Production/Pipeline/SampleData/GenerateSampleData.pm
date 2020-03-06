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

Bio::EnsEMBL::Production::Pipeline::SampleData::GenerateSampleData

=head1 DESCRIPTION

This module is based on this script from the Genebuild team: https://github.com/Ensembl/ensembl-analysis/blob/dev/hive_master/scripts/genebuild/get_sample_genes.pl
The module will update the sample data in the core database meta table.
To select new sample data, the module will do the following:
1) get a list of good gene trees from compara
2) pick out trees with human (for vertebrates only)
3) Filter gene by length, maximum 100000 and minimum 75000 (for vertebrates only since Non-vert genes are smaller and we have less candidates)
4) Then the pipeline will select the best candidate by looking at:
a) presence of xrefs
b) presence of supporting evidence
c) still store every candidate even without support
5) If no candidate were found, the pipeline will fall back on getting transcript for the 10 longest seq_region then check for supporting evidence
6) If still no candidate found, stop here

=cut

package Bio::EnsEMBL::Production::Pipeline::SampleData::GenerateSampleData;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Attribute;
use base('Bio::EnsEMBL::Production::Pipeline::Common::Base');
sub run {
  my ($self) = @_;
  my $species = $self->param('species');
  my $db = $self->core_dba();
  # defaults
  my $max_len = $self->param('maximum_gene_length');
  my $min_len = $max_len * 0.75;
  # Create Compara adaptors
  my $compara_name = $self->division() ne "vertebrates"?$self->division():'Multi';
  my $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara_name, 'compara') if defined $compara_name;
  throw("Can't connect to Compara database specified by $compara_name - check command-line and registry file settings") if (!$compara_dba);
  # First try to get the genomedb for the species
  my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
  my $genome_db  = $genome_db_adaptor->fetch_by_registry_name($species);
  if (defined $genome_db){
    # then, grab all gene trees that are good candidates
    my $gene_tree_adaptor = $compara_dba->get_GeneTreeAdaptor;
    my $good_gene_trees_sql = "SELECT root_id, tree_type, member_type, clusterset_id, gene_align_id, method_link_species_set_id, species_tree_root_id, stable_id, version, ref_root_id, NULL, NULL, NULL ".
                "FROM gene_tree_root_attr a JOIN gene_tree_root r USING(root_id) ".
                "WHERE a.taxonomic_coverage > 0.95 AND a.aln_percent_identity > 75 AND r.member_type = 'protein' and r.clusterset_id = 'default' and r.tree_type = 'tree';";
    my $gene_tree_sth = $compara_dba->dbc->prepare($good_gene_trees_sql);
    $gene_tree_sth->execute;
    my $good_gene_trees = $gene_tree_adaptor->_objs_from_sth($gene_tree_sth);
    $self->warning("Found " . scalar @$good_gene_trees . " 'good' gene trees\n") if $self->debug();
    # next, pick out genes from any tree that includes human (i.e. has a human ortholog) for vert only
    my $human_genome_db = $genome_db_adaptor->fetch_by_name_assembly('homo_sapiens') if $self->division() eq 'vertebrates';
    my @candidate_genes;
    foreach my $tree ( @$good_gene_trees ) {
      my $human_gene_count = $tree->Member_count_by_source_GenomeDB('ENSEMBLPEP', $human_genome_db) if $self->division() eq 'vertebrates';
      if ($self->division() eq 'vertebrates'){
        next unless $human_gene_count > 0;
      }
      my $tree_genes = $tree->get_Member_by_source_GenomeDB('ENSEMBLPEP', $genome_db);
      foreach my $gene ( @$tree_genes ) {
        # Check gene size with max and min length only for vertebrates
        if ($self->division() eq 'vertebrates'){
          push @candidate_genes, $gene if ($gene->length > $min_len && $gene->length < $max_len);
        }
        else{
          push @candidate_genes, $gene;
        }
      }
    }
    # Disconnect from the Compara db
    $compara_dba->dbc()->disconnect_if_idle();
    # now find a candidate with xrefs and good support
    $self->warning("Found: " . scalar @candidate_genes . " genes for ".$species."\n") if $self->debug();
    my %sample_transcripts;
    my $sample_transcript;
    TRANSCRIPT:foreach my $seq_member ( @candidate_genes ) {
      # find a transcript that has xrefs and 'good' supporting evidence
      my $transcript = $seq_member->get_Transcript;
      my $xrefs = $transcript->get_all_xrefs();
      if (scalar @$xrefs){
        my $supporting_features = $transcript->get_all_supporting_features;
        if (scalar @$supporting_features){
          foreach my $support (@$supporting_features){
            if ($support->hcoverage() >= 50 && $support->percent_id() >= 75){
              if ($transcript->external_name()){
                push @{$sample_transcripts{'xref_supporting_evidence_external_name'}}, $transcript;
              }
              else{
                push @{$sample_transcripts{'xref_supporting_evidence'}}, $transcript;
              }
            }
          }
        }
        else{
          push @{$sample_transcripts{'xref'}}, $transcript;
        }
      }
      # If there are no xrefs available, fall back on supporting evidence
      else{
        my $supporting_features = $transcript->get_all_supporting_features;
        if (scalar @$supporting_features){
          foreach my $support (@$supporting_features){
            if ($support->hcoverage() >= 50 && $support->percent_id() >= 75){
              push @{$sample_transcripts{'high_supporting_evidence'}}, $transcript;
            }
            else{
              push @{$sample_transcripts{'low_supporting_evidence'}}, $transcript;
            }
          }
        }
        # If no xrefs or no supporting evidences, still record it
        else{
          push @{$sample_transcripts{'no_extra_support'}}, $transcript;
        }
      }
    }
    #Select a transcript from the best support to least
    if (exists($sample_transcripts{'xref_supporting_evidence_external_name'})){
      $sample_transcript=$sample_transcripts{'xref_supporting_evidence_external_name'}[0];
    }
    elsif (exists($sample_transcripts{'xref_supporting_evidence'})){
      $sample_transcript=$sample_transcripts{'xref_supporting_evidence'}[0];
    }
    elsif (exists($sample_transcripts{'high_supporting_evidence'})){
      $sample_transcript=$sample_transcripts{'high_supporting_evidence'}[0];
    }
    elsif (exists($sample_transcripts{'xref'})){
      $sample_transcript=$sample_transcripts{'xref'}[0];
    }
    elsif (exists($sample_transcripts{'low_supporting_evidence'})){
      $sample_transcript=$sample_transcripts{'low_supporting_evidence'}[0];
    }
    else{
      $sample_transcript=$sample_transcripts{'no_extra_support'}[0];
    }
    # If we have a good candidate with gene/transcript name or without
    # populate the sample data meta keys
    if ($sample_transcript){
      $self->populate_sample_data_meta_table($sample_transcript,$db);
    }
    else{
     $self->find_sample_data_no_compara_no_xrefs($db,$species);
    }
  }
  else {
    $self->find_sample_data_no_compara_no_xrefs($db,$species);
  }
  $db->dbc()->disconnect_if_idle();
  return;
}

#Populate the sample meta keys
sub populate_sample_data_meta_table {
  my ($self, $sample_transcript,$db) = @_;
  my $species_id = $db->species_id();
  my $sample_gene=$sample_transcript->get_Gene;
  my $sample_coord=$sample_gene->seq_region_name().':'.$sample_gene->seq_region_start().'-'.$sample_gene->seq_region_end();
  $db->dbc()->sql_helper()->execute_update(
    -SQL => qq/UPDATE meta set meta_value=?
      WHERE meta_key='sample.location_param'
      AND species_id = ?;/,
      -PARAMS => [$sample_coord,$species_id] );
  $db->dbc()->sql_helper()->execute_update(
    -SQL => qq/UPDATE meta set meta_value=?
      WHERE meta_key='sample.location_text'
      AND species_id = ?;/,
      -PARAMS => [$sample_coord,$species_id] );
  $db->dbc()->sql_helper()->execute_update(
    -SQL => qq/UPDATE meta set meta_value=?
      WHERE meta_key='sample.gene_param'
      AND species_id = ?;/,
      -PARAMS => [$sample_gene->stable_id(),$species_id] );
  my $gene_text = defined $sample_gene->external_name() ? $sample_gene->external_name() : $sample_gene->stable_id();
  $db->dbc()->sql_helper()->execute_update(
    -SQL => qq/UPDATE meta set meta_value=?
      WHERE meta_key='sample.gene_text'
      AND species_id = ?;/,
      -PARAMS => [$gene_text,$species_id] );
  $db->dbc()->sql_helper()->execute_update(
    -SQL => qq/UPDATE meta set meta_value=?
      WHERE meta_key='sample.transcript_param'
      AND species_id = ?;/,
      -PARAMS => [$sample_transcript->stable_id(),$species_id] );
  my $transcript_text = defined $sample_transcript->external_name() ? $sample_transcript->external_name() : $sample_transcript->stable_id();
  $db->dbc()->sql_helper()->execute_update(
    -SQL => qq/UPDATE meta set meta_value=?
      WHERE meta_key='sample.transcript_text'
      AND species_id = ?;/,
      -PARAMS => [$transcript_text,$species_id] );
  $db->dbc()->sql_helper()->execute_update(
    -SQL => qq/UPDATE meta set meta_value=?
      WHERE meta_key='sample.search_text'
      AND species_id = ?;/,
      -PARAMS => ['glycoprotein',$species_id] );
  return;
}
#Find sample data without using Compara nor the xrefs
sub find_sample_data_no_compara_no_xrefs {
  my ($self, $db, $species) = @_;
   $self->warning("Can't find genome db for this species. module will run without Compara or Xref information\n");
   my $species_id = $db->species_id();
   my $sa = $db->get_SliceAdaptor;
   my $sth_longest = $db->dbc->prepare('SELECT seq_region_id FROM seq_region JOIN coord_system USING (coord_system_id) WHERE species_id=? order by length desc limit 10');
   $sth_longest->execute($species_id);
   my %sample_transcripts;
   my $sample_transcript;
   LOOP: while (my $seq_region_id = $sth_longest->fetchrow_array) {
     my $region = $sa->fetch_by_seq_region_id($seq_region_id);
     my @transcripts = @{$region->get_all_Transcripts_by_type('protein_coding')};

     TRANSCRIPT:foreach my $transcript (@transcripts){
       my $supporting_features = $transcript->get_all_supporting_features;
       foreach my $support (@$supporting_features){
         if ($support->hcoverage() >= 99 && $support->percent_id() >= 75){
           push @{$sample_transcripts{'high_supporting_evidence'}}, $transcript;
         }
         elsif ($support->hcoverage() >= 50 && $support->percent_id() >= 75){
           push @{$sample_transcripts{'low_supporting_evidence'}}, $transcript;
         }
         else{
           push @{$sample_transcripts{'no_extra_support'}}, $transcript;
         }
       }
     }
   }#end while
   #Select a transcript from the best support to least
   if (exists($sample_transcripts{'high_supporting_evidence'})){
     $sample_transcript=$sample_transcripts{'high_supporting_evidence'}[0];
   }
   elsif (exists($sample_transcripts{'low_supporting_evidence'})){
     $sample_transcript=$sample_transcripts{'low_supporting_evidence'}[0];
   }
   else{
     $sample_transcript=$sample_transcripts{'no_extra_support'}[0];
   }
   #If we have found a good candidate, populate the sample meta keys
   if ($sample_transcript){
     $self->populate_sample_data_meta_table($sample_transcript,$db);
   } 
   else{
     $self->warning("No suitable transcripts found for ".$species." in ".$db->dbc->dbname."\n");
   }
  return;
}

1;