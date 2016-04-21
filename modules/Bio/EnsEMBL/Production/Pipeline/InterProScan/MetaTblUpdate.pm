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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::MetaTblUpdate;

=head1 DESCRIPTION

 This module will add/update InterProScan related meta_key
 in the 'meta' table

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::MetaTblUpdate;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::Base');

sub fetch_input {
    my ($self) 	= @_;

    my $interproscan_version = $self->param_required('interproscan_version');
    my $interproscan_date    = $self->param_required('interproscan_date');
    my $interpro_version     = $self->param_required('interpro_version');
    
    my $sql_ipr_ver  = 'INSERT INTO meta (species_id, meta_key, meta_value)VALUES (?, ?, ?)';
    my $sql_ipr_date = 'INSERT INTO meta (species_id, meta_key, meta_value)VALUES (?, ?, ?)';
    my $sql_ip_ver   = 'INSERT INTO meta (species_id, meta_key, meta_value)VALUES (?, ?, ?)';

    my $sql_up_ipr_ver  = 'UPDATE meta SET meta_value=? WHERE meta_key="interproscan.version"';
    my $sql_up_ipr_date = 'UPDATE meta SET meta_value=? WHERE meta_key="interproscan.date"';
    my $sql_up_ip_ver   = 'UPDATE meta SET meta_value=? WHERE meta_key="interpro.version"';

    $self->param('interproscan_version', $interproscan_version);
    $self->param('interproscan_date',    $interproscan_date);
    $self->param('interpro_version',     $interpro_version);
    $self->param('sql_ipr_ver',  $sql_ipr_ver);
    $self->param('sql_ipr_date', $sql_ipr_date);
    $self->param('sql_ip_ver',   $sql_ip_ver);
    $self->param('sql_up_ipr_ver',  $sql_up_ipr_ver);
    $self->param('sql_up_ipr_date', $sql_up_ipr_date);
    $self->param('sql_up_ip_ver',   $sql_up_ip_ver);

return 0;
}

sub run {
    my ($self)       = @_;

    my $helper = Bio::EnsEMBL::Utils::SqlHelper->new( -DB_CONNECTION => $self->core_dbc() );

    my $interproscan_version = $self->param_required('interproscan_version');
    my $interproscan_date    = $self->param_required('interproscan_date');
    my $interpro_version     = $self->param_required('interpro_version');
    my $sql_ipr_ver          = $self->param_required('sql_ipr_ver');
    my $sql_ipr_date         = $self->param_required('sql_ipr_date');
    my $sql_ip_ver           = $self->param_required('sql_ip_ver');
    my $sql_up_ipr_ver       = $self->param_required('sql_up_ipr_ver');
    my $sql_up_ipr_date      = $self->param_required('sql_up_ipr_date');
    my $sql_up_ip_ver        = $self->param_required('sql_up_ip_ver');

    my $meta_count1 = $helper->execute_single_result(
		       -SQL => 'select count(*) from meta where meta_key =?',
		       -PARAMS => ['interproscan.version'] );

    if($meta_count1==0){
       $helper->execute_update(-SQL => $sql_ipr_ver,  -PARAMS => ['1', 'interproscan.version', $interproscan_version]);
    }else {
       $helper->execute_update(-SQL => $sql_up_ipr_ver,  -PARAMS => [$interproscan_version]);
    }

    my $meta_count2 = $helper->execute_single_result(
                       -SQL => 'select count(*) from meta where meta_key =?',
                       -PARAMS => ['interproscan.date'] );

    if($meta_count2==0){
       $helper->execute_update(-SQL => $sql_ipr_date, -PARAMS => ['1', 'interproscan.date', $interproscan_date]);
    }else{
       $helper->execute_update(-SQL => $sql_up_ipr_date, -PARAMS => [$interproscan_date]);
    }

    my $meta_count3 = $helper->execute_single_result(
                       -SQL => 'select count(*) from meta where meta_key =?',
                       -PARAMS => ['interpro.version'] );

    if($meta_count3==0){
       $helper->execute_update(-SQL => $sql_ip_ver,   -PARAMS => ['1', 'interpro.version', $interpro_version]);
    }else{
       $helper->execute_update(-SQL => $sql_up_ip_ver,   -PARAMS => [$interpro_version]);
    }

    $self->core_dbc()->disconnect_if_idle();

return 0;
}

sub write_output {
    my ($self)  = @_;


return 0;
}




1;


