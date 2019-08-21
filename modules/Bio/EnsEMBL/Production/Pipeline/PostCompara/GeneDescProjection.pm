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

Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneDescProjection

=cut

=head1 DESCRIPTION

 Pipeline to project gene description from one species to another 
 by using the homologies derived from the Compara ProteinTree pipeline. 

=cut
package Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneDescProjection;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;

use base ('Bio::EnsEMBL::Production::Pipeline::PostCompara::Base');

sub run {
  my ($self) = @_;

  my $to_species             = $self->param_required('species');
  my $from_species           = $self->param_required('source');
  my $compara                = $self->param_required('compara');
  my $release                = $self->param_required('release');
  my $output_dir             = $self->param_required('output_dir');
  my $method_link_type       = $self->param_required('method_link_type');
  my $homology_types_allowed = $self->param_required('homology_types_allowed');
  my $is_tree_compliant      = $self->param_required('is_tree_compliant');
  my $percent_id_filter      = $self->param_required('percent_id_filter');
  my $percent_cov_filter     = $self->param_required('percent_cov_filter');

  my $reg = 'Bio::EnsEMBL::Registry';

  my $from_ga = $reg->get_adaptor($from_species, 'core', 'Gene');
  my $to_ga   = $reg->get_adaptor($to_species  , 'core', 'Gene');
  my $to_dbea = $reg->get_adaptor($to_species  , 'core', 'DBEntry');
  if (!$from_ga || !$to_ga || !$to_dbea) {
    die("Problem getting core db adaptor(s)");
  }

  my $mlssa = $reg->get_adaptor($compara, 'compara', 'MethodLinkSpeciesSet'); 
  my $ha    = $reg->get_adaptor($compara, 'compara', 'Homology'); 
  my $gdba  = $reg->get_adaptor($compara, 'compara', 'GenomeDB'); 
  if (!$mlssa || !$ha || !$gdba) {
    die("Problem getting compara db adaptor(s)");
  }

  $self->check_directory($output_dir);
  my $log_file  = "$output_dir/$from_species-$to_species\_GeneDescProjection_logs.txt";
  open my $log, ">", "$log_file" or die $!;
  print $log "\n\tProjection log :\n";
  print $log "\t\tsoftware release :$release\n";
  print $log "\t\tfrom :".$from_ga->dbc()->dbname()." to :".$to_ga->dbc()->dbname()."\n";

  my $from_GenomeDB = $gdba->fetch_by_registry_name($from_species);
  if (!defined $from_GenomeDB) {
    print $log "Aborting: Genome DB not found for $from_species";
    return;
  }
  my $to_GenomeDB = $gdba->fetch_by_registry_name($to_species);
  if (!defined $to_GenomeDB) {
    print $log "Aborting: Genome DB not found for $to_species";
    return;
  }
  my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$from_GenomeDB, $to_GenomeDB]);
  if (!defined $mlss) {
    print $log "Aborting: No orthology found for $from_species to $to_species";
    return;
  }
  my $mlss_id = $mlss->dbID();

  # Get homologies from compara - comes back as a hash of arrays
  print $log "\n\tRetrieving homologies of method link type $method_link_type for mlss_id $mlss_id \n";
  my $homologies = $self->fetch_homologies(
    $ha, $mlss, $from_species, $log, $gdba, $homology_types_allowed, $is_tree_compliant, $percent_id_filter, $percent_cov_filter
  );

  print $log "\n\tProjecting Gene Descriptions from $from_species to $to_species\n\n";

  while (my ($from_stable_id, $to_genes) = each %{$homologies}) {
    my $from_gene = $from_ga->fetch_by_stable_id($from_stable_id);
    next if (!$from_gene);

    foreach my $to_stable_id (@{$to_genes}) {
      my $to_gene  = $to_ga->fetch_by_stable_id($to_stable_id);
      next if (!$to_gene);

      $self->project_genedesc($to_ga, $to_dbea, $from_gene, $to_gene, $log);
    }
  }

  close($log);

  # Explicit disconnect to free up database connections
  $from_ga->dbc->disconnect_if_idle();
  $to_ga->dbc->disconnect_if_idle();
  $mlssa->dbc->disconnect_if_idle();
}

sub project_genedesc {
  my ($self, $to_ga, $to_dbea, $from_gene, $to_gene, $log) = @_;

  my $from_species           = $self->param_required('source');
  my $compara                = $self->param_required('compara');
  my $store_projections      = $self->param_required('store_projections');
  my $gene_name_source       = $self->param_required('gene_name_source');
  my $gene_desc_rules        = $self->param_required('gene_desc_rules');
  my $gene_desc_rules_target = $self->param_required('gene_desc_rules_target');

  # Checking that source passed the rules
  if ($self->is_source_ok($from_gene, $gene_desc_rules)) {
    # Checking that target passed the rules
    if ($self->is_target_ok($to_gene,$gene_desc_rules_target)) {
      # Finally check if the from gene dbname is in the allowed gene name source
      # This is to avoid projecting things that are not part of the allowed gene name source
      my $from_gene_dbname = $from_gene->display_xref->dbname();
      if (grep (/$from_gene_dbname/, @$gene_name_source)) {
        my $gene_desc = $from_gene->description();
        if ($compara !~ /multi/i) {
          # For non-vertebrates, create new source text
          my $species_text = ucfirst($from_species);
          $species_text    =~ s/_/ /g;
          my $source_id    = $from_gene->stable_id();
          $gene_desc       =~ s/(\[Source:)/$1Projected from $species_text ($source_id) /;
        }

        print $log "\t\tProject from: ".$from_gene->stable_id()."\t";
        print $log "to: ".$to_gene->stable_id()."\t";
        print $log "Gene Description: $gene_desc\n";

        if ($store_projections) {
          $to_gene->description($gene_desc);
          $to_ga->update($to_gene);
        }
      }
    }
  }
}

# Check if source gene has a display xref and an informative description
sub is_source_ok {
  my ($self, $from_gene, $gene_desc_rules) = @_;
  my $ok = 0;
  # Check if source gene has a description and display_xref
  if (defined $from_gene->description() && defined $from_gene->display_xref()) {
    # Check if from_gene description is uninformative
    my $part_of_genedesc_rule = grep {$from_gene->description() =~ /$_/} @$gene_desc_rules;
    if ($part_of_genedesc_rule == 0) {
      $ok = 1;
    }
  }
  return $ok;
}

# Check if target gene has an informative description
sub is_target_ok {
  my ($self, $to_gene, $gene_desc_rules_target) = @_;
  my $ok = 0;
  if (defined $to_gene->description()) {
    my $part_of_genedesc_target_rule = grep {$to_gene->description() =~ /$_/} @$gene_desc_rules_target;
    if ($part_of_genedesc_target_rule == 1) {
      $ok = 1;
    }
  } else {
    $ok = 1;
  }
  return $ok;
}

1
