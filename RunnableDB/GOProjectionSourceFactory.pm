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

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GOProjectionSourceFactory;

=head1 DESCRIPTION


This analysis take the GO projection hash in, if parallel_GO_projections is set, the pipeline will dataflow all the GO projections.
If parallel_GO_projections is not defined then the pipeline will dataflow each projections sequentially to avoid projecting dependant species at the same time.

=head1 AUTHOR

ckong and maurel

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GOProjectionSourceFactory;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::Base');

sub run {
    my ($self)  = @_;

    my $go_config = $self->param_required('go_config') || die "'go_config' is an obligatory parameter";
    my $projection_list = $self->param('projection_list');
    my $parallel_GO_projections = $self->param('parallel_GO_projections');
    my $final_projection_list;

    if ($projection_list)
    {
      $final_projection_list=$projection_list;
    }
    else
    {
      $final_projection_list=$go_config;
    }
    # Making sure that the projection hash is not empty
    if (keys $final_projection_list){
      foreach my $pair (sort (keys $final_projection_list)){
         my $source                 = $final_projection_list->{$pair}->{'source'};
         my $species                = $final_projection_list->{$pair}->{'species'};
         my $antispecies            = $final_projection_list->{$pair}->{'antispecies'};
         my $division               = $final_projection_list->{$pair}->{'division'};
         my $run_all                = $final_projection_list->{$pair}->{'run_all'};       
         my $method_link_type       = $final_projection_list->{$pair}->{'go_method_link_type'};  
         my $homology_types_allowed = $final_projection_list->{$pair}->{'go_homology_types_allowed'};
         my $percent_id_filter      = $final_projection_list->{$pair}->{'go_percent_id_filter'};
         my $ensemblObj_type        = $final_projection_list->{$pair}->{'ensemblObj_type'};
         my $ensemblObj_type_target = $final_projection_list->{$pair}->{'ensemblObj_type_target'};
        # Remove source/target species from the hash
        delete $final_projection_list->{$pair};
        $self->param('projection_list', $final_projection_list);
        $self->dataflow_output_id(
		{'source'      		  => $source, 
		 'species'     		  => $species, 
		 'antispecies' 		  => $antispecies, 
  		 'division'    	  	  => $division, 
		 'run_all' 		  => $run_all,
		 'method_link_type' 	  => $method_link_type,
                 'homology_types_allowed' => $homology_types_allowed,
  		 'percent_id_filter'      => $percent_id_filter,
		 'ensemblObj_type'        => $ensemblObj_type,
		 'ensemblObj_type_target' => $ensemblObj_type_target 
		},2); 
        # If parallel_GO_projections is defined, we run all the projections at the same time in parallel
        if ($parallel_GO_projections){
          $self->dataflow_output_id({'projection_list'    => {},
                                 'species'                => $species,
                                 'source'                 => $source},1);
        }
        # else, we run the projections sequentially, one set of projection at the time
        else{
          # Making sure that the projection hash is not empty
          if (keys $final_projection_list){
            $self->dataflow_output_id({'projection_list'       => $self->param('projection_list'),
                                 'species'                => $species,
                                 'source'                 => $source},1);
          }
          last;
        }
      }
    }
return 0;
}



1;


