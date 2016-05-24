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

Bio::EnsEMBL::Production::Pipeline::Ortholog::MLSSJobFactory;

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::Ortholog::MLSSJobFactory;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::Hive::Process');
use Bio::EnsEMBL::Utils::Exception qw(throw);

sub param_defaults {
    return {

           };
}

sub fetch_input {
    my ($self) = @_;

return 0;
}

sub run {
    my ($self)  = @_;

return 0;
}

sub write_output {
    my ($self)  = @_;

    my $compara    = $self->param_required('compara');
    my $from_sp    = $self->param_required('source');
    my $to_sp      = $self->param('target');
    my $ex_sp      = $self->param('exclude');
    my $homo_types = $self->param('homology_types');
    my $ml_type    = $self->param_required('method_link_type');
    my $mlssa      = Bio::EnsEMBL::Registry->get_adaptor($compara, 'compara', 'MethodLinkSpeciesSet');
    my $mlss_list  = $mlssa->fetch_all_by_method_link_type($ml_type);

    foreach my $mlss (@$mlss_list){ 
       my $mlss_id = $mlss->dbID();
       my $gdbs    = $mlss->species_set_obj->genome_dbs();

       my @gdbs_nm;    

       foreach my $gdb (@$gdbs){ push @gdbs_nm,$gdb->name();}

       # Dataflow only MLSS_ID containing 
       # the exact source species
       if(grep (/^$from_sp$/, @gdbs_nm)){
 
        # Get non-source species
         my $ns_sp;
         foreach my $gdb_nm (@gdbs_nm){ $ns_sp = $gdb_nm unless($from_sp =~/^$gdb_nm/); }
  
         # target species provided
         if(defined $to_sp){
           foreach my $sp (@$to_sp){
             $self->dataflow_output_id({'mlss_id' => $mlss_id, 'compara' => $compara ,'from_sp' => $from_sp , 'homology_types' => $homo_types }, 2) if(grep (/^$sp$/, @gdbs_nm));      
           }
	 } 
 	 else {
           $self->dataflow_output_id({'mlss_id' => $mlss_id, 'compara' => $compara ,'from_sp' => $from_sp, 'homology_types' => $homo_types }, 2) unless (grep (/^$ns_sp$/, @$ex_sp));         
	 }
      }
   }
return 0;
}

1;
