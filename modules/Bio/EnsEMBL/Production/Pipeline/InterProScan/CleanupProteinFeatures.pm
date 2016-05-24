=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::CleanupProteinFeatures;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::CleanupProteinFeatures;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreTsvBase');

sub fetch_input {
    my ($self) 	= @_;

return 0;
}

sub write_output {
    my ($self)  = @_;

    my $exclusion = $self->param('exclusion');
    my $species   = $self->param_required('species');

    if(!grep (/$species/, @$exclusion)){
        $self->dataflow_output_id( { }, 1 );
    }

return 0;
}

sub run {
    my ($self) = @_;

    my $species             = $self->param_required('species');
    my $translation_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,'Core','Translation');
    my $helper              = Bio::EnsEMBL::Utils::SqlHelper->new( -DB_CONNECTION => $self->core_dbc() );

    # Query to retrieve all ncoil features
    #  Since the API $t->get_all_ProteinFeatures('ncoils');
    #  Is not returning the correct number of ncoil features
    my $sql_ncoil_pf = 'SELECT protein_feature_id, translation_id, hit_name, seq_end from protein_feature where hit_name="Coil"';

    # Query to remove protein_features fro ncoil analysis, which ends beyond the length of the translation 
    my $sql_del_feat = 'DELETE FROM protein_feature WHERE protein_feature_id =?';
    
    my $iterator     = $helper->execute( -SQL => $sql_ncoil_pf,-ITERATOR => 1);

    while($iterator->has_next()) {
        my $row      = $iterator->next();
        my $pf_id    = $row->[0];
        my $t_id     = $row->[1];
        my $hit_name = $row->[2];        
        my $seq_end  = $row->[3]; 

        my $translation = $translation_adaptor->fetch_by_dbID($t_id);
        next unless defined $translation;
        my $length      = $translation->length();

        if($seq_end > $length){
            $helper->execute_update(-SQL => $sql_del_feat, -PARAMS =>[$pf_id]);
        }
    }

    $translation_adaptor->dbc->disconnect_if_idle();

return 0;
}


1;


