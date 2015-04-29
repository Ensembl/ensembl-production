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

my ($flag_store_projections, $flag_backup);
my ($flag_filter);
my ($to_species, $from_species, $compara, $release);
my ($method_link_type, $homology_types_allowed, $percent_id_filter, $percent_cov_filter);
my ($log_file, $output_dir, $data);
my ($geneDesc_rules, $geneDesc_rules_target, $taxon_filter);
my ($mlssa, $ha, $ma, $gdba);

sub fetch_input {
    my ($self) = @_;

    $flag_store_projections = $self->param('flag_store_projections');
    $flag_backup            = $self->param('flag_backup');
    $flag_filter            = $self->param('flag_filter');

    $to_species             = $self->param_required('species');
    $from_species           = $self->param_required('source');
    $compara                = $self->param_required('compara');
    $release                = $self->param_required('release');
    
    $method_link_type       = $self->param_required('method_link_type');
    $homology_types_allowed = $self->param_required('homology_types_allowed');
    $percent_id_filter      = $self->param_required('percent_id_filter');
    $percent_cov_filter     = $self->param_required('percent_cov_filter');
    $log_file               = $self->param_required('output_dir');
    $output_dir             = $self->param_required('output_dir');

    $geneDesc_rules         = $self->param_required('geneDesc_rules');
    $geneDesc_rules_target  = $self->param_required('geneDesc_rules_target');
    $taxon_filter           = $self->param('taxon_filter');

    my $taxonomy_db 	    = $self->param('taxonomy_db');

    $self->param('taxonomy_db', $taxonomy_db);

return;
}

sub run {
    my ($self) = @_;

    Bio::EnsEMBL::Registry->set_disconnect_when_inactive(1);

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


    Bio::EnsEMBL::Registry->load_registry_from_db(
            -host       => 'mysql-eg-mirror.ebi.ac.uk',
            -port       => 4157,
            -user       => 'ensrw',
            -pass       => 'writ3r',
            -db_version => '79',
   );

    $mlssa = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'MethodLinkSpeciesSet'); 
    $ha    = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'Homology'); 
    $gdba  = Bio::EnsEMBL::Registry->get_adaptor($compara, "compara", 'GenomeDB'); 
    die "Can't connect to Compara database specified by $compara - check command-line and registry file settings" if (!$mlssa || !$ha ||!$gdba);

    $self->check_directory($log_file);
    $log_file  = $log_file."/".$from_species."-".$to_species."_GeneDescProjection_logs.txt";

    # Write projection info metadata
    open  $data,">","$log_file" or die $!;
    print $data "\n\tProjection log :\n";
    print $data "\t\tsoftware release :$release\n";
    print $data "\t\tfrom :".$from_ga->dbc()->dbname()." to :".$to_ga->dbc()->dbname()."\n";
 
    # Build Compara GenomeDB objects
    my $from_GenomeDB = $gdba->fetch_by_registry_name($from_species);
    my $to_GenomeDB   = $gdba->fetch_by_registry_name($to_species);
    my $mlss          = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$from_GenomeDB, $to_GenomeDB]);
    my $mlss_id       = $mlss->dbID();
 
    # Get homologies from compara - comes back as a hash of arrays
    print $data "\n\tRetrieving homologies of method link type $method_link_type for mlss_id $mlss_id \n";
    my $homologies    = $self->fetch_homologies($ha, $mlss, $from_species, $data, $gdba, $homology_types_allowed, $percent_id_filter, $percent_cov_filter);

    print $data "\n\tProjecting Gene Descriptions from $from_species to $to_species\n\n";

    my $total_genes   = scalar(keys %$homologies);

    foreach my $from_stable_id (keys %$homologies) {
       my $from_gene  = $from_ga->fetch_by_stable_id($from_stable_id);
       next if (!$from_gene);
       my @to_genes   = @{$homologies->{$from_stable_id}};
    
       foreach my $to_stable_id (@to_genes) {
          my $to_gene  = $to_ga->fetch_by_stable_id($to_stable_id);
          next if (!$to_gene);
          project_genedesc($to_ga, $to_dbea, $from_gene, $to_gene);
       }
    }
    close($data);

return;
}

sub write_output {
    my ($self) = @_;

}

######################
## internal methods
######################
sub project_genedesc {
    my ($to_geneAdaptor, $to_dbea, $from_gene, $to_gene) = @_;

    my $gene_desc      = $from_gene->description();
    my $gene_desc_trgt = $to_gene->description(); 
    $gene_desc_trgt    ='' if !defined($gene_desc_trgt);

    # Tests for source & target gene description rules
    my $test1 = grep {$gene_desc      =~/$_/} @$geneDesc_rules; 
    my $test2 = grep {$gene_desc_trgt =~/$_/} @$geneDesc_rules_target; 

    # First check source gene has a description and 
    # passed the description filtering rules
    if(defined $from_gene->description() && $test1==0)
    {
      # Then check if target gene 
      # does not have description OR
      # its description didn't passed the filtering rules AND
      # the flag to check for filtering rules is ON
      if(!defined $to_gene->description() || ($test2==1 && $flag_filter==1))  
      {
        my $species_text = ucfirst($from_species);
        $species_text    =~ s/_/ /g;
        my $source_id    = $from_gene->stable_id();
        $gene_desc       =~ s/(\[Source:)/$1Projected from $species_text ($source_id) /;

        print $data "\t\tProject from: ".$from_gene->stable_id()."\t";
        print $data "to: ".$to_gene->stable_id()."\t";
        print $data "Gene Description: $gene_desc\n";

        if($flag_store_projections==1){
#           $to_gene->description($gene_desc);
#           $to_geneAdaptor->update($to_gene);
        }
      }
    }

}


1
