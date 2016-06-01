=pod 

=head1 NAME

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneCoverageFactory

=cut

=head1 DESCRIPTION

=head1 AUTHOR 

ckong

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneCoverageFactory;

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

    my $division     = $self->param_required('division');

    my $sql_geneTree = "SELECT distinct(r.root_id) 
		       FROM gene_tree_node n, gene_tree_root r, seq_member m, genome_db g, gene_align_member gam 
		       WHERE m.seq_member_id = n.seq_member_id 
		       AND gam.seq_member_id = m.seq_member_id 
		       AND r.root_id         = n.root_id 
		       AND r.clusterset_id   = 'default' 
		       AND gam.gene_align_id = r.gene_align_id 
		       AND g.genome_db_id    = m.genome_db_id
		       ORDER BY r.root_id ";

   $self->param('division', $division);
   $self->param('sql_geneTree', $sql_geneTree);

=pod

    $sql_geneTree       = "SELECT distinct(r.root_id) 
 			     FROM gene_tree_node n, gene_tree_root r, member m, genome_db g, gene_align_member gam
 			     WHERE m.member_id     = n.member_id
 			     AND gam.member_id     = m.member_id
 			     AND r.root_id         = n.root_id
 			     AND r.clusterset_id   = 'default'
 			     AND gam.gene_align_id = r.gene_align_id
 			     AND g.genome_db_id    = m.genome_db_id
                             ORDER BY r.root_id ";
=cut

return;
}

sub run {
    my ($self) = @_;

    my $division     = $self->param('division');  
    my $sql_geneTree = $self->param('sql_geneTree');  

    my $dba_compara = Bio::EnsEMBL::Registry->get_DBAdaptor($division, "compara");
    print STDERR "Analysing ".$dba_compara->dbc()->dbname()."\n";

    my $helper    = Bio::EnsEMBL::Utils::SqlHelper->new( -DB_CONNECTION => $dba_compara->dbc() );
    my $array_ref = $helper->execute(-SQL => $sql_geneTree);
       
    foreach my $row (@{$array_ref}) {
       my $root_id  = $row->[0];
       $self->dataflow_output_id( { 'root_id'=> $root_id }, 2 );
    }

    $self->dataflow_output_id(1);

return;
}

sub write_output {
    my ($self) = @_;

}


1;
