=pod 

=head1 NAME

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneCoverage

=cut

=head1 DESCRIPTION

 This Runnable uses the cigar lines generated from a Compara run to generate 
 consistency metrics for Compara clusters. Specifically, it compares the 
 extent of each protein sequence in the alignment to the extent of the cluster consensus.

=head1 AUTHOR 

ckong

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneCoverage;

use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::Base');

sub param_defaults {
    return {
          
	   };
}

sub fetch_input {
    my ($self) = @_;

    $root_id   = $self->param_required('root_id');
    $division  = $self->param_required('division');

    $sql_geneTree       = "SELECT r.root_id, cigar_line, n.node_id, m.stable_id, m.taxon_id, g.name
                        FROM gene_tree_node n, gene_tree_root r, seq_member m, genome_db g, gene_align_member gam 
                        WHERE m.seq_member_id = n.seq_member_id 
                        AND gam.seq_member_id = m.seq_member_id 
                        AND r.root_id = n.root_id 
                        AND r.clusterset_id = 'default' 
                        AND gam.gene_align_id = r.gene_align_id 
                        AND g.genome_db_id = m.genome_db_id
  			AND r.root_id =? ";

    $self->param('root_id', $root_id);
    $self->param('division', $division);
    $self->param('sql_geneTree', $sql_geneTree);

=pod
    $sql_geneTree       = "SELECT r.root_id, cigar_line, n.node_id, m.stable_id, m.taxon_id, g.name
 			 	FROM gene_tree_node n, gene_tree_root r, member m, genome_db g, gene_align_member gam
 			 	WHERE m.member_id = n.member_id
 			 	AND gam.member_id = m.member_id
 			 	AND r.root_id = n.root_id
 			 	AND r.clusterset_id = 'default'
 			 	AND gam.gene_align_id = r.gene_align_id
 			 	AND g.genome_db_id = m.genome_db_id
				AND r.root_id = ?";
=cut


return;
}

sub run {
    my ($self) = @_;

    my $division     = $self->param('division'); 
    my $sql_geneTree = $self->param('sql_geneTree'); 
    my $root_id      = $self->param('root_id'); 

    my $dba_compara = Bio::EnsEMBL::Registry->get_DBAdaptor($division, "compara");
    my $helper      = Bio::EnsEMBL::Utils::SqlHelper->new( -DB_CONNECTION => $dba_compara->dbc() );
    my $array_ref   = $helper->execute(-SQL => $sql_geneTree, -PARAMS => [$root_id]);       
    my @cigars;
   
    foreach my $row (@{$array_ref}) {
       my ($root_id, $cigar_line, $node_id, $stable_id, $taxon_id, $name) = @{$row};
       push @cigars, join '^^', $stable_id, $name, $cigar_line;
    }
    $self->process_cigar_line(\@cigars, $root_id);
#Disconnecting from the registry
$dba_compara->dbc->disconnect_if_idle();
return;
}

sub write_output {
    my ($self) = @_;

}


1;
