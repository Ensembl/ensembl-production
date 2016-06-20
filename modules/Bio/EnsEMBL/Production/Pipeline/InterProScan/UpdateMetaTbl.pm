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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::UpdateMetaTbl;

=head1 DESCRIPTION

 This module will add/update InterProScan related meta_key
 in the 'meta' table

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::UpdateMetaTbl;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::Base');

sub fetch_input {
    my ($self) 	= @_;

return 0;
}

sub run {
    my ($self)       = @_;

    my $interproscan_version = $self->param_required('interproscan_version');
    my $interproscan_date    = $self->param_required('interproscan_date');
    my $interpro_version     = $self->param_required('interpro_version');

    my $species              = $self->param_required('species');
    my $meta_container       = Bio::EnsEMBL::Registry->get_adaptor($species,'core','MetaContainer');
    my $helper               = Bio::EnsEMBL::Utils::SqlHelper->new( -DB_CONNECTION => $self->core_dbc() );
    my $species_id           = $self->core_dba()->species_id();

    my $meta_count1 = $helper->execute_single_result(
                       -SQL => 'select count(*) from meta where meta_key =? and species_id =?',
                       -PARAMS => ['interproscan.version', $species_id] );

    if($meta_count1==0){
        $meta_container->store_key_value('interproscan.version', $interproscan_version);
    } else {
        $meta_container->update_key_value('interproscan.version', $interproscan_version);
    }

    my $meta_count2 = $helper->execute_single_result(
                       -SQL => 'select count(*) from meta where meta_key =? and species_id =?',
                       -PARAMS => ['interproscan.date', $species_id] );

    if($meta_count2==0){
        $meta_container->store_key_value('interproscan.date', $interproscan_date);
    } else {
        $meta_container->update_key_value('interproscan.date', $interproscan_date);
    }

    my $meta_count3 = $helper->execute_single_result(
                       -SQL => 'select count(*) from meta where meta_key =? and species_id =?',
                       -PARAMS => ['interpro.version', $species_id] );

    if($meta_count3==0){
        $meta_container->store_key_value('interpro.version', $interpro_version);
    } else {
        $meta_container->update_key_value('interpro.version', $interpro_version);
    }

    $meta_container->dbc->disconnect_if_idle();

return 0;
}

sub write_output {
    my ($self)  = @_;


return 0;
}




1;


