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

    my $flag_GeneNames = $self->param('flag_GeneNames');
    my $flag_GeneDescr = $self->param('flag_GeneDescr');

    my $sql_update  = 'UPDATE gene SET display_xref_id = NULL 
		      WHERE display_xref_id IN 
                      (SELECT xref_id FROM xref WHERE info_text rlike "projected from")';

    my $sql_update2 = 'UPDATE gene SET description = ""
		       WHERE description like "%Source%"';
			
    my $sql_delete  = 'DELETE FROM xref WHERE info_text rlike "projected from"';
    
 
    $self->param('flag_GeneNames', $flag_GeneNames);
    $self->param('flag_GeneDescr', $flag_GeneDescr);
    $self->param('sql_update',  $sql_update);
    $self->param('sql_update2', $sql_update2);
    $self->param('sql_delete',  $sql_delete);

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

    my $flag_GeneNames = $self->param('flag_GeneNames');
    my $flag_GeneDescr = $self->param('flag_GeneDescr');

    my $sql_update  = $self->param_required('sql_update');
    my $sql_update2 = $self->param_required('sql_update2');
    my $sql_delete  = $self->param_required('sql_delete');

    $helper->execute_update(-SQL => $sql_update2)if($flag_GeneDescr==1);
    $helper->execute_update(-SQL => $sql_update) if($flag_GeneNames==1);
    $helper->execute_update(-SQL => $sql_delete) if($flag_GeneNames==1);
    
    $self->core_dbc()->disconnect_if_idle();
    
return 0;
}



1;


