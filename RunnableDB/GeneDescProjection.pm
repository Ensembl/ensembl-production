=pod 

=head1 NAME

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneDescProjection

=cut

=head1 DESCRIPTION

 Pipeline to project gene description
 from one species to another by using the homologies derived 
 from the Compara ProteinTree pipeline. 

 Normally this is used to project from a well annotated species to one which is not.

=head1 AUTHOR 

ckong

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneDescProjection;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::Base');

sub param_defaults {
    return {
          
	   };
}


sub fetch_input {
    my ($self) = @_;

    my $flag_store_proj = $self->param_required('flag_store_projections');
    my $flag_filter     = $self->param_required('flag_filter');
    my $to_species      = $self->param_required('species');
    my $from_species    = $self->param_required('source');
    my $compara         = $self->param_required('compara');
    my $release         = $self->param_required('release');
    my $method_link_type       = $self->param_required('method_link_type');
    my $homology_types_allowed = $self->param_required('homology_types_allowed');
    my $percent_id_filter      = $self->param_required('percent_id_filter');
    my $percent_cov_filter     = $self->param_required('percent_cov_filter');
    my $output_dir             = $self->param_required('output_dir');
    my $geneDesc_rules         = $self->param_required('geneDesc_rules');
    my $geneDesc_rules_target  = $self->param_required('geneDesc_rules_target');
    my $taxon_filter           = $self->param('taxon_filter');
    my $taxonomy_db            = $self->param('taxonomy_db');

    $self->param('flag_store_proj', $flag_store_proj);
    $self->param('flag_filter', $flag_filter);    
    $self->param('to_species', $to_species);
    $self->param('from_species', $from_species);
    $self->param('compara', $compara);
    $self->param('release', $release);
    $self->param('method_link_type', $method_link_type);
    $self->param('homology_types_allowed', $homology_types_allowed);
    $self->param('percent_id_filter', $percent_id_filter);
    $self->param('percent_cov_filter', $percent_cov_filter);
    $self->param('geneDesc_rules', $geneDesc_rules);
    $self->param('geneDesc_rules_target', $geneDesc_rules_target);
    $self->param('taxon_filter', $taxon_filter);
    $self->param('taxonomy_db', $taxonomy_db);

    $self->check_directory($output_dir);
    my $log_file  = $output_dir."/".$from_species."-".$to_species."_GeneDescProjection_logs.txt";
    open my $log,">","$log_file" or die $!;

    $self->param('log', $log);

return;
}

sub run {
    my ($self) = @_;

    my $to_species       = $self->param('to_species');
    my $from_species     = $self->param('from_species');
    my $compara          = $self->param('compara');
    my $release          = $self->param('release');
    my $method_link_type = $self->param('method_link_type');
    my $taxon_filter     = $self->param('taxon_filter');

    # Get taxon ancestry of the target species
    my $taxonomy_db        = $self->param('taxonomy_db');  
    my $to_latin_species   = ucfirst(Bio::EnsEMBL::Registry->get_alias($to_species));
    my $meta_container     = Bio::EnsEMBL::Registry->get_adaptor($to_latin_species,'core','MetaContainer');
    my ($to_taxon_id)      = @{ $meta_container->list_value_by_key('species.taxonomy_id')};
    my ($ancestors,$names) = $self->get_taxon_ancestry($to_taxon_id, $taxonomy_db);  

    # Exit projection if 'taxon_filter' is not found in the $ancestor list
    if(defined $taxon_filter){
       die("$taxon_filter is not found in the ancestor list of $to_species\n") if(!grep (/$taxon_filter/, @$names));
    }

    # Creating adaptors
    my $from_ga   = Bio::EnsEMBL::Registry->get_adaptor($from_species, 'core', 'Gene');
    my $to_ga     = Bio::EnsEMBL::Registry->get_adaptor($to_species  , 'core', 'Gene');
    my $to_ta     = Bio::EnsEMBL::Registry->get_adaptor($to_species  , 'core', 'Transcript');
    my $to_dbea   = Bio::EnsEMBL::Registry->get_adaptor($to_species  , 'core', 'DBEntry');
    die("Problem getting DBadaptor(s) - check database connection details\n") if (!$from_ga || !$to_ga || !$to_ta || !$to_dbea);

=pod
    Bio::EnsEMBL::Registry->load_registry_from_db(
            -host       => 'mysql-eg-mirror.ebi.ac.uk',
            -port       => 4157,
            -user       => 'ensrw',
            -pass       => 'writ3r',
            -db_version => '80',
   );
=cut
    my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'MethodLinkSpeciesSet'); 
    my $ha    = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'Homology'); 
    my $gdba  = Bio::EnsEMBL::Registry->get_adaptor($compara, "compara", 'GenomeDB'); 
    die "Can't connect to Compara database specified by $compara - check command-line and registry file settings" if (!$mlssa || !$ha ||!$gdba);

    # Write projection info metadata
    my $log = $self->param('log');
    print $log "\n\tProjection log :\n";
    print $log "\t\tsoftware release :$release\n";
    print $log "\t\tfrom :".$from_ga->dbc()->dbname()." to :".$to_ga->dbc()->dbname()."\n";
 
    #Clean up projected descriptions

    # Build Compara GenomeDB objects
    my $from_GenomeDB = $gdba->fetch_by_registry_name($from_species);
    my $to_GenomeDB   = $gdba->fetch_by_registry_name($to_species);
    my $mlss          = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$from_GenomeDB, $to_GenomeDB]);
    my $mlss_id       = $mlss->dbID();

    # Get homologies from compara - comes back as a hash of arrays
    print $log "\n\tRetrieving homologies of method link type $method_link_type for mlss_id $mlss_id \n";
    my $homologies    = $self->fetch_homologies($ha, $mlss, $from_species, $log, $gdba, $self->param('homology_types_allowed'), $self->param('percent_id_filter'), $self->param('percent_cov_filter'));

    print $log "\n\tProjecting Gene Descriptions from $from_species to $to_species\n\n";

    my $total_genes   = scalar(keys %$homologies);

    foreach my $from_stable_id (keys %$homologies) {
       my $from_gene  = $from_ga->fetch_by_stable_id($from_stable_id);
       next if (!$from_gene);
       my @to_genes   = @{$homologies->{$from_stable_id}};
    
       foreach my $to_stable_id (@to_genes) {
          my $to_gene  = $to_ga->fetch_by_stable_id($to_stable_id);
          next if (!$to_gene);
          project_genedesc($self, $to_ga, $to_dbea, $from_gene, $to_gene, $log);
       }
    }
    close($log);
#Disconnecting from the registry
$meta_container->dbc->disconnect_if_idle();
$from_ga->dbc->disconnect_if_idle();
$to_ga->dbc->disconnect_if_idle();
$to_ta->dbc->disconnect_if_idle();
$to_dbea->dbc->disconnect_if_idle();
$mlssa->dbc->disconnect_if_idle();
$ha->dbc->disconnect_if_idle();
$gdba->dbc->disconnect_if_idle();
return;
}

sub write_output {
    my ($self) = @_;

}

######################
## internal methods
######################
sub project_genedesc {
    my ($self,$to_geneAdaptor, $to_dbea, $from_gene, $to_gene, $log) = @_;

    my $flag_store_proj        = $self->param('flag_store_proj'); 
    my $flag_filter            = $self->param('flag_filter'); 
    my $from_species           = $self->param('from_species');
    my $geneDesc_rules         = $self->param('geneDesc_rules');
    my $geneDesc_rules_target  = $self->param('geneDesc_rules_target');

    my $gene_desc      = $from_gene->description();
    my $gene_desc_trgt = $to_gene->description(); 
    $gene_desc_trgt    ='' if !defined($gene_desc_trgt);

    # Tests for source & target gene description rules
    my $test1 = grep {$gene_desc      =~/$_/} @$geneDesc_rules; 
    my $test2 = grep {$gene_desc_trgt =~/$_/} @$geneDesc_rules_target; 

    # First check source gene has a description and 
    # passed the source gene description filtering rules
    if(defined $from_gene->description() && $test1==0)
    {
      # Then check if target gene 
      # does not have description OR
      # its description didn't passed the filtering rules AND
      # the flag to check for filtering rules is ON
      if(!defined $to_gene->description() || ($test2==1 && $flag_filter==1))  
      {
        if ($from_gene->display_xref->dbname() =~ /MGI/ || $from_gene->display_xref->dbname() =~ /HGNC/ || $from_gene->display_xref->dbname() =~ /ZFIN_ID/)
        {
          my $gene_desc=$from_gene->description();
        }
        else
        {
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

1
