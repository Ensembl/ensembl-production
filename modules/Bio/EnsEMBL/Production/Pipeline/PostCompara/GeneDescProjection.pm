=pod 

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneDescProjection

=cut

=head1 DESCRIPTION

 Pipeline to project gene description
 from one species to another by using the homologies derived 
 from the Compara ProteinTree pipeline. 

 Normally this is used to project from a well annotated species to one which is not.

=head1 AUTHOR 

ckong and maurel

=cut
package Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneDescProjection;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyNodeAdaptor;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::Production::Pipeline::PostCompara::Base');


sub run {
    my ($self) = @_;

    my $to_species       = $self->param_required('species');
    my $from_species     = $self->param_required('source');
    my $compara          = $self->param_required('compara');
    my $release          = $self->param_required('release');
    my $method_link_type = $self->param_required('method_link_type');
    my $output_dir             = $self->param_required('output_dir');

    print "Processing names projection from $from_species to $to_species\n";

    # Creating adaptors
    my $from_ga   = Bio::EnsEMBL::Registry->get_adaptor($from_species, 'core', 'Gene');
    my $to_ga     = Bio::EnsEMBL::Registry->get_adaptor($to_species  , 'core', 'Gene');
    my $to_ta     = Bio::EnsEMBL::Registry->get_adaptor($to_species  , 'core', 'Transcript');
    my $to_dbea   = Bio::EnsEMBL::Registry->get_adaptor($to_species  , 'core', 'DBEntry');
    die("Problem getting DBadaptor(s) - check database connection details\n") if (!$from_ga || !$to_ga || !$to_ta || !$to_dbea);

    my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'MethodLinkSpeciesSet'); 
    my $ha    = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'Homology'); 
    my $gdba  = Bio::EnsEMBL::Registry->get_adaptor($compara, "compara", 'GenomeDB'); 
    die "Can't connect to Compara database specified by $compara - check command-line and registry file settings" if (!$mlssa || !$ha ||!$gdba);

    # Write projection info metadata
    $self->check_directory($output_dir);
    my $log_file  = $output_dir."/".$from_species."-".$to_species."_GeneDescProjection_logs.txt";
    open my $log,">","$log_file" or die $!;
    print $log "\n\tProjection log :\n";
    print $log "\t\tsoftware release :$release\n";
    print $log "\t\tfrom :".$from_ga->dbc()->dbname()." to :".$to_ga->dbc()->dbname()."\n";
 
    # Build Compara GenomeDB objects
    my $from_GenomeDB = $gdba->fetch_by_registry_name($from_species);
    my $to_GenomeDB   = $gdba->fetch_by_registry_name($to_species);
    my $mlss          = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$from_GenomeDB, $to_GenomeDB]);
    if(!defined $mlss) {
      warn "No orthology found for $from_species to $to_species";
      return;
    }
    my $mlss_id       = $mlss->dbID();

    # Get homologies from compara - comes back as a hash of arrays
    print $log "\n\tRetrieving homologies of method link type $method_link_type for mlss_id $mlss_id \n";
    my $homologies    = $self->fetch_homologies($ha, $mlss, $from_species, $log, $gdba, $self->param('homology_types_allowed'), $self->param('is_tree_compliant'), $self->param('percent_id_filter'), $self->param('percent_cov_filter'));

    print $log "\n\tProjecting Gene Descriptions from $from_species to $to_species\n\n";

    my $total_genes   = scalar(keys %$homologies);

    while (my ($from_stable_id,$to_genes) = each %{$homologies}) {
       my $from_gene  = $from_ga->fetch_by_stable_id($from_stable_id);
       next if (!$from_gene);

       foreach my $to_stable_id (@{$to_genes}) {
          my $to_gene  = $to_ga->fetch_by_stable_id($to_stable_id);
          next if (!$to_gene);
          $self->project_genedesc($to_ga, $to_dbea, $from_gene, $to_gene, $log);
       }
    }
    close($log);
#Disconnecting from the registry
$from_ga->dbc->disconnect_if_idle();
$to_ga->dbc->disconnect_if_idle();
$mlssa->dbc->disconnect_if_idle();
return;
}


######################
## internal methods
######################
sub project_genedesc {
    my ($self,$to_geneAdaptor, $to_dbea, $from_gene, $to_gene, $log) = @_;

    my $flag_store_proj        = $self->param_required('flag_store_projections');
    my $flag_filter            = $self->param_required('flag_filter');
    my $from_species           = $self->param_required('source');
    my $geneName_source        = $self->param_required('geneName_source');
    my $geneDesc_rules         = $self->param_required('geneDesc_rules');
    my $geneDesc_rules_target  = $self->param_required('geneDesc_rules_target');
    my $compara                = $self->param_required('compara');

    #Checking that source passed the rules
    if($self->is_source_ok($from_gene,$geneDesc_rules))
    {
      #Checking that target passed the rules
      if($self->is_target_ok($to_gene,$geneDesc_rules_target,$flag_filter))
      {
        # Finally check if the from gene dbname is in the allowed gene name source
        # This is to avoid projecting things that are not part of the allowed gene name source
        my $from_gene_dbname = $from_gene->display_xref->dbname();
        if (grep (/$from_gene_dbname/, @$geneName_source)) {
          # For e! species, project source description
          my $gene_desc;
          if ($compara eq "Multi"){
            $gene_desc = $from_gene->description();
          }
          # For EG species, create a new description
          else {
            my $species_text = ucfirst($from_species);
            $species_text    =~ s/_/ /g;
            my $source_id    = $from_gene->stable_id();
            $gene_desc       =~ s/(\[Source:)/$1Projected from $species_text ($source_id) /;
          }

          print $log "\t\tProject from: ".$from_gene->stable_id()."\t";
          print $log "to: ".$to_gene->stable_id()."\t";
          print $log "Gene Description: $gene_desc\n";

          if($flag_store_proj==1){
             $to_gene->description($gene_desc);
             $to_geneAdaptor->update($to_gene);
          }
        }
      }
    }

}

# Check if source gene has a description, a display xref and passed the source gene description filtering rules
sub is_source_ok {
  my ($self,$from_gene,$geneDesc_rules) = @_;
  my $ok=0;
  # Check if source gene has a description and display_xref
  if (defined $from_gene->description() && defined $from_gene->display_xref()) {
    # Check if from_gene description is part of the geneDesc rules
    my $part_of_genedesc_rule = grep {$from_gene->description() =~/$_/} @$geneDesc_rules;
    if ($part_of_genedesc_rule==0){
      $ok=1;
    }
  }
return $ok;
}

# Then check if target gene
# does not have description OR
# its description didn't passed the filtering rules AND
# the flag to check for filtering rules is ON
sub is_target_ok {
  my ($self,$to_gene,$geneDesc_rules_target,$flag_filter) = @_;
  my $ok=0;
  if (defined $to_gene->description()){
    my $part_of_genedesc_target_rule = grep {$to_gene->description() =~/$_/} @$geneDesc_rules_target;
    if ($part_of_genedesc_target_rule==1 && $flag_filter==1){
      $ok=1;
    }
  }
  else{
    $ok=1;
  }
return $ok;
}

1
