=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::PostCompara::DumpingCleaningSetup;

=head1 DESCRIPTION

This analysis take the projections hashes in, create a unique list of species, division and antispecies for each projections and flow into the SpeciesFactory.
This analysis is design to run sequentially, backing and cleaning one projection at a time. This is to avoid backing up the same database at the same time or backing up after of while cleaning up

=head1 AUTHOR

maurel

=cut
package Bio::EnsEMBL::Production::Pipeline::PostCompara::DumpingCleaningSetup;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::Production::Pipeline::PostCompara::Base');

sub run {
    my ($self)  = @_;

    my $flag_GeneNames = $self->param('flag_GeneNames');
    my $flag_GeneDescr = $self->param('flag_GeneDescr');

    my $output_dir  = $self->param('output_dir');
    my $projection_backup_list = $self->param('projection_backup_list');
    my $parallel_GeneNames_projections = $self->param('parallel_GeneNames_projections');
    my $parallel_GeneDescription_projections = $self->param('parallel_GeneDescription_projections');

    my $final_projection_backup_list;
    # If we have a projection list then that mean that we have already backed up and cleaned up one projection
    if ($projection_backup_list)
    {
      $final_projection_backup_list=$projection_backup_list;
      if (keys $final_projection_backup_list){
        foreach my $name (sort keys $final_projection_backup_list) {
          # Check that we have keys for a given name.
          if (keys $final_projection_backup_list->{$name}){
            foreach my $projection (sort keys $final_projection_backup_list->{$name}){
              # Make sure we only add the delete flags to associated hash 
              if ($name eq "gn"){
                $final_projection_backup_list->{$name}->{$projection}->{flag_delete_gene_names} = $self->param('flag_delete_gene_names');
              }
              elsif ($name eq "gd"){
                $final_projection_backup_list->{$name}->{$projection}->{flag_delete_gene_descriptions} = $self->param('flag_delete_gene_descriptions');
              }
              $final_projection_backup_list->{$name}->{$projection}->{output_dir} = $self->param('output_dir');
              $final_projection_backup_list->{$name}->{$projection}->{dump_tables} = $self->param('g_dump_tables');
              # Push projection hash to dumpTables and cleanup
              $self->dataflow_output_id($final_projection_backup_list->{$name}->{$projection},2);
              # Delete the projection hash from the final_projection_backup_list hash
              delete $final_projection_backup_list->{$name}->{$projection};
             if (keys $final_projection_backup_list){
               $self->param('projection_backup_list', $final_projection_backup_list);
               $self->dataflow_output_id({'projection_backup_list'=> $self->param('projection_backup_list'),},1);
             }
             else{
               $self->dataflow_output_id({},1);
             }
            last;
            }
          }
          else {
            # If we don't have any values left for the name key, remove it from the hash
            delete $final_projection_backup_list->{$name};
            next;
          }
        last;
        }
     }
     else {
       $self->dataflow_output_id({},2);
       $self->dataflow_output_id({},1);
     }
    }
    # If the parameter don't exist, process the projection hashes making sure that we have data for each projections
    else
      { 
        if ($flag_GeneDescr){
          if ($parallel_GeneDescription_projections) {
            # Process the Gene description projection hash and create unique species, division and antispecies hashes.
            $final_projection_backup_list->{gd}->{1} = process_pairs(values $self->param('gd_config'));
          }
          else {
            # Else do the backup and clean up sequentially to respect projection order.
            $final_projection_backup_list->{gd} = $self->param('gd_config');
          }
      }

      if ($flag_GeneNames){

          if ($parallel_GeneNames_projections) {
            # Process the Gene description projection hash and create unique species, division and antispecies hashes.
            $final_projection_backup_list->{gn}->{1} = process_pairs(values $self->param('g_config'));
          }
          else {
            # Else do the backup and clean up sequentially to respect projection order.
            $final_projection_backup_list->{gn} = $self->param('g_config');
          }
      }

      # Making sure that the projection hash is not empty 
      if (keys $final_projection_backup_list){
        foreach my $name (sort keys $final_projection_backup_list) {
          # Check that we have keys for a given name.
          if (keys $final_projection_backup_list->{$name}){
            foreach my $projection (sort keys $final_projection_backup_list->{$name}){
              # Make sure we only add the delete flags to associated hash 
              if ($name eq "gn"){
                $final_projection_backup_list->{$name}->{$projection}->{flag_delete_gene_names} = $self->param('flag_delete_gene_names');
              }
              elsif ($name eq "gd"){
                $final_projection_backup_list->{$name}->{$projection}->{flag_delete_gene_descriptions} = $self->param('flag_delete_gene_descriptions');
              }
              $final_projection_backup_list->{$name}->{$projection}->{output_dir} = $self->param('output_dir');
              $final_projection_backup_list->{$name}->{$projection}->{dump_tables} = $self->param('g_dump_tables');
              # Push projection hash to dumpTables and cleanup
              $self->dataflow_output_id($final_projection_backup_list->{$name}->{$projection},2);
              # Delete the projection hash from the final_projection_backup_list hash
              delete $final_projection_backup_list->{$name}->{$projection};
              if (keys $final_projection_backup_list){
                $self->param('projection_backup_list', $final_projection_backup_list);
                $self->dataflow_output_id({'projection_backup_list'=> $self->param('projection_backup_list'),},1);
              }
              else{
                $self->dataflow_output_id({},1);
              }
            last;
            }
          }
          else {
            # If we don't have any values left for the name key, remove it from the hash
            delete $final_projection_backup_list->{$name};
            next;
          }
        last;
        }
      }
      else{
        $self->dataflow_output_id({},2);
        $self->dataflow_output_id({},1);
      }
      }
    return 0;
}

sub write_output {
    my ($self)  = @_;

return 0;
}

sub process_pairs {
  my $result = {};
  for my $k (qw/species antispecies division taxons/) {
    foreach my $pair (@_){
      add_unique($result,$pair,$k);
    }
    $result->{$k} = [keys %{$result->{$k}}] if defined $result->{$k};
  }
  return $result;
}

sub add_unique {
  my ($r,$p,$k)  = @_;
  my $v = $p->{$k};
  if(defined $v) {
    if(ref($v) eq 'ARRAY') {
      for my $s (@$v) {
        $r->{$k}->{$s} = 1;
      }
    } else {
      $r->{$k}->{$v} = 1;
    }
  }
  return;
}


1;



