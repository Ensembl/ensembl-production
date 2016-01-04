=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::TblCleanup;

=head1 DESCRIPTION

=head1 AUTHOR 

ckong 

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::TblCleanup;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::Base');
use Bio::EnsEMBL::Utils::SqlHelper;

sub fetch_input {
    my ($self) 	= @_;

    my $flag_delete_gene_names = $self->param('flag_delete_gene_names');
    my $flag_delete_gene_descriptions = $self->param('flag_delete_gene_descriptions');
    my $flag_delete_go_terms = $self->param('flag_delete_go_terms');
 
    $self->param('flag_delete_gene_names', $flag_delete_gene_names);
    $self->param('flag_delete_gene_descriptions', $flag_delete_gene_descriptions);
    $self->param('flag_delete_go_terms', $flag_delete_go_terms);

return 0;
}

sub write_output {
    my ($self)  = @_;

    $self->dataflow_output_id({}, 1 );

return 0;
}

sub run {
    my ($self)       = @_;

    my $helper = Bio::EnsEMBL::Utils::SqlHelper->new( -DB_CONNECTION => $self->core_dbc() );

    my $flag_delete_gene_names = $self->param('flag_delete_gene_names');
    my $flag_delete_gene_descriptions = $self->param('flag_delete_gene_descriptions');
    my $flag_delete_go_terms = $self->param('flag_delete_go_terms');

    $self->delete_gene_names($helper) if($flag_delete_gene_names==1);
    $self->delete_gene_desc($helper) if($flag_delete_gene_descriptions==1);
    $self->delete_go_terms($helper) if($flag_delete_go_terms==1);
    
    $self->core_dbc()->disconnect_if_idle();
    
return 0;
}

=head2 delete_go_terms

=cut
sub delete_go_terms {
    my ($self,$helper)       = @_;

    print STDERR "Delete existing projected GO terms in core\n";

    my $sql_del_terms = "DELETE x, ox, gx FROM xref x, external_db e, object_xref ox, ontology_xref gx WHERE x.xref_id=ox.xref_id AND x.external_db_id=e.external_db_id AND ox.object_xref_id=gx.object_xref_id AND e.db_name='GO' AND x.info_type='PROJECTION'";

    $helper->execute_update(-SQL => $sql_del_terms);

    # note don't need to delete synonyms as GO terms don't have any
    # Also no effect on descriptions or status

return 0;
}

=head2 delete_gene_names

=cut
sub delete_gene_names {
    my ($self,$helper)       = @_;

    print STDERR "Setting projected transcript statuses to NOVEL\n";

    my $sql_del_terms = "UPDATE gene g, xref x, transcript t SET t.display_xref_id = NULL, t.description = NULL, t.status='NOVEL' WHERE g.display_xref_id=x.xref_id AND x.info_type='PROJECTION' AND g.gene_id = t.gene_id";
    $helper->execute_update(-SQL => $sql_del_terms);

    print STDERR "Setting gene display_xrefs that were projected to NULL and status to NOVEL\n\n";

    $sql_del_terms = "UPDATE gene g, xref x SET g.display_xref_id = NULL, g.status='NOVEL' WHERE g.display_xref_id=x.xref_id AND x.info_type='PROJECTION'";

    $helper->execute_update(-SQL => $sql_del_terms);

    print STDERR "Deleting projected xrefs, object_xrefs and synonyms\n";

    $sql_del_terms = "DELETE es FROM xref x, external_synonym es WHERE x.xref_id=es.xref_id AND x.info_type='PROJECTION'";

    $helper->execute_update(-SQL => $sql_del_terms);

    $sql_del_terms="DELETE x, ox FROM xref x, object_xref ox, external_db e WHERE x.xref_id=ox.xref_id AND x.external_db_id=e.external_db_id AND x.info_type='PROJECTION' AND e.db_name!='GO'";

    $helper->execute_update(-SQL => $sql_del_terms);

return 0;
}

=head2 delete_gene_desc

=cut
sub delete_gene_desc {
    my ($self,$helper)       = @_;

    print STDERR "Setting descriptions that were projected to NULL \n";

    my $sql_del_terms = "UPDATE gene g, xref x SET g.description=NULL WHERE g.display_xref_id=x.xref_id AND x.info_type='PROJECTION'";

    $helper->execute_update(-SQL => $sql_del_terms);

return 0;
}

1;


