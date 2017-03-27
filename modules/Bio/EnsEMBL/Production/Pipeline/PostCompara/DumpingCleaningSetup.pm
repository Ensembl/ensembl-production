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
    my $final_projection_backup_list;
    # If we have a projection list then that mean that we have already backed up and cleaned up a projections
    if ($projection_backup_list)
    {
      $final_projection_backup_list=$projection_backup_list;
      if (keys $final_projection_backup_list){
        foreach my $name (sort keys $final_projection_backup_list) {
          $self->dataflow_output_id($final_projection_backup_list->{$name},2);
          delete $final_projection_backup_list->{$name};
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
       $self->dataflow_output_id({},2);
       $self->dataflow_output_id({},1);
     }
    }
    # If the parameter don't exist, process the projection hashes making sure that we have data for each projections
    else
      {
        if ($flag_GeneDescr){
          # Process the Gene description projection hash and create unique species, division and antispecies hashes.
          $final_projection_backup_list->{gd} = process_pairs(values $self->param('gd_config'));
          $final_projection_backup_list->{gd}->{flag_delete_gene_descriptions} = $self->param('flag_delete_gene_descriptions');
          $final_projection_backup_list->{gd}->{output_dir} = $self->param('output_dir');
          $final_projection_backup_list->{gd}->{dump_tables} = $self->param('g_dump_tables');
      }

      if ($flag_GeneNames){
          $final_projection_backup_list->{gn} = process_pairs(values $self->param('gn_config'));
          $final_projection_backup_list->{gn}->{output_dir} = $self->param('output_dir');
          $final_projection_backup_list->{gn}->{dump_tables} = $self->param('g_dump_tables');
          $final_projection_backup_list->{gn}->{flag_delete_gene_names} = $self->param('flag_delete_gene_names');
      }

      # Making sure that the projection hash is not empty 
      if (keys $final_projection_backup_list){
        foreach my $name (sort keys $final_projection_backup_list) {
          $self->dataflow_output_id($final_projection_backup_list->{$name},2);
          delete $final_projection_backup_list->{$name};
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
  for my $k (qw/species antispecies division/) {
    foreach my $pair (@_){
      print Dumper($pair);
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



