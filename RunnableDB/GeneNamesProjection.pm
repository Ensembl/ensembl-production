=pod 

=head1 NAME

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneNamesProjection

=cut

=head1 DESCRIPTION

 Pipeline to project gene display_xref 
 from one species to another by using the homologies derived 
 from the Compara ProteinTree pipeline. 

 Normally this is used to project from a well annotated species to one which is not.

=head1 AUTHOR 

ckong

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneNamesProjection;

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
    my $to_species      = $self->param_required('species');
    my $from_species    = $self->param_required('source');
    my $compara         = $self->param_required('compara');
    my $release         = $self->param_required('release');
    my $method_link_type       = $self->param_required('method_link_type');
    my $homology_types_allowed = $self->param_required('homology_types_allowed');
    my $percent_id_filter      = $self->param_required('percent_id_filter');
    my $percent_cov_filter     = $self->param_required('percent_cov_filter');
    my $output_dir             = $self->param_required('output_dir');
    my $geneName_source        = $self->param_required('geneName_source');
    my $taxon_filter           = $self->param('taxon_filter');
    my $taxonomy_db            = $self->param('taxonomy_db');
   
    $self->param('flag_store_proj', $flag_store_proj);
    $self->param('to_species', $to_species);
    $self->param('from_species', $from_species);
    $self->param('compara', $compara);
    $self->param('release', $release);
    $self->param('method_link_type', $method_link_type);
    $self->param('homology_types_allowed', $homology_types_allowed);
    $self->param('percent_id_filter', $percent_id_filter);
    $self->param('percent_cov_filter', $percent_cov_filter);
    $self->param('geneName_source', $geneName_source);
    $self->param('taxon_filter', $taxon_filter);
    $self->param('taxonomy_db', $taxonomy_db);

    $self->check_directory($output_dir);
    my $log_file  = $output_dir."/".$from_species."-".$to_species."_GeneNamesProjection_logs.txt";
    open my $log,">","$log_file" or die $!;

    $self->param('log', $log);

return;
}

sub run {
    my ($self) = @_;

    Bio::EnsEMBL::Registry->set_disconnect_when_inactive(1);

    my $to_species 	 = $self->param('to_species');
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
            -host       => 'mysql-eg-staging-1.ebi.ac.uk',
            -port       => 4160,
            -user       => 'ensrw',
            -pass       => 'scr1b3s1',
            -db_version => '82',
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
 
    # Build Compara GenomeDB objects
    my $from_GenomeDB = $gdba->fetch_by_registry_name($from_species);
    my $to_GenomeDB   = $gdba->fetch_by_registry_name($to_species);
    my $mlss          = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$from_GenomeDB, $to_GenomeDB]);
    my $mlss_id       = $mlss->dbID();
 
    # Get homologies from compara - comes back as a hash of arrays
    print $log "\n\tRetrieving homologies of method link type $method_link_type for mlss_id $mlss_id \n";
    my $homologies    = $self->fetch_homologies($ha, $mlss, $from_species, $log, $gdba, $self->param('homology_types_allowed'), $self->param('percent_id_filter'), $self->param('percent_cov_filter'));

    print $log "\n\tProjecting Gene Names & descriptions from $from_species to $to_species\n\n";

    my $total_genes   = scalar(keys %$homologies);

    foreach my $from_stable_id (keys %$homologies) {
       my $from_gene  = $from_ga->fetch_by_stable_id($from_stable_id);
       next if (!$from_gene);
       my @to_genes   = @{$homologies->{$from_stable_id}};
    
       foreach my $to_stable_id (@to_genes) {
          my $to_gene  = $to_ga->fetch_by_stable_id($to_stable_id);
          next if (!$to_gene);
          project_genenames($self, $to_ga, $to_dbea, $from_gene, $to_gene, $log);
       }
    }
    close($log);

return;
}

sub write_output {
    my ($self) = @_;

}

######################
## internal methods
######################
sub project_genenames {
    my ($self, $to_geneAdaptor, $to_dbea, $from_gene, $to_gene, $log) = @_;

    my $flag_store_proj  = $self->param('flag_store_proj');
    my $from_species     = $self->param('from_species');
    my $geneName_source  = $self->param('geneName_source');

    # Project when 'source gene' has display_xref and 
    # 'target gene' has NO display_xref
    if(defined $from_gene->display_xref() && !defined $to_gene->display_xref()) {
       my $from_gene_dbname     = $from_gene->display_xref->dbname();
       my $from_gene_display_id = $from_gene->display_xref->display_id();         

       # Get all DBEntries for 'source gene' base on the dbname of display_xref  
       foreach my $dbEntry (@{$from_gene->get_all_DBEntries($from_gene_dbname)}) { 

          if($dbEntry->display_id=~/$from_gene_display_id/  
               && $flag_store_proj==1
               && grep (/$from_gene_dbname/, @$geneName_source)){

             print $log "\t\tProject from:".$from_gene->stable_id()."\t";
             print $log "to:".$to_gene->stable_id()."\t";
             print $log "GeneName:".$from_gene->display_xref->display_id()."\t";
             print $log "DB:".$from_gene->display_xref->dbname()."\n";

	     # Adding projection source information 
             $dbEntry->info_type("PROJECTION");
             $dbEntry->info_text("projected from $from_species,".$from_gene->stable_id());

             $to_dbea->store($dbEntry,$to_gene->dbID(), 'Gene', 1);
             $to_gene->display_xref($dbEntry);
             $to_geneAdaptor->update($to_gene);
         }
      }
   } 

}


1
