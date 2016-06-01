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

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::DumpingCleaningSetup;

=head1 DESCRIPTION

This analysis take the projections hashes in, create a unique list of species, division and antispecies for each projections and flow into the SpeciesFactory.
This analysis is design to run sequentially, backing and cleaning one projection at a time. This is to avoid backing up the same database at the same time or backing up after of while cleaning up

=head1 AUTHOR

maurel

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::DumpingCleaningSetup;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::Base');

sub run {
    my ($self)  = @_;

    my $g_config = $self->param('g_config');
    my $gd_config = $self->param('gd_config');
    my $go_config = $self->param('go_config');
    my $flag_GeneNames = $self->param('flag_GeneNames');
    my $flag_GeneDescr = $self->param('flag_GeneDescr');
    my $flag_GO        = $self->param('flag_GO');
    my $flag_delete_gene_names = $self->param('flag_delete_gene_names');
    my $flag_delete_gene_descriptions = $self->param('flag_delete_gene_descriptions');
    my $flag_delete_go_terms        = $self->param('flag_delete_go_terms');
    my $output_dir  = $self->param('output_dir');
    my $g_dump_tables = $self->param('g_dump_tables');
    my $go_dump_tables = $self->param('go_dump_tables');
    my $projection_backup_list = $self->param('projection_backup_list');
    my $final_projection_backup_list;
    my @species;
    my @antispecies;
    my @division;
    my (@g_species,@g_antispecies,@g_division,@gd_species,@gd_antispecies,@gd_division,@go_species,@go_antispecies,@go_division);
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
      # Process the Gene description projection hash and create unique species, division and antispecies hashes.
      if ($flag_GeneDescr){
        foreach my $pair (keys $gd_config){
           push (@gd_species, @{$gd_config->{$pair}->{'species'}});
           push (@gd_antispecies, @{$gd_config->{$pair}->{'antispecies'}});
           push (@gd_division, @{$gd_config->{$pair}->{'division'}});
        }
        @gd_species=uniq(@gd_species);
        @gd_antispecies=uniq(@gd_antispecies);
        @gd_division=uniq(@gd_division);

        $final_projection_backup_list->{"gd"} =
          { 'species'       => \@gd_species,
            'antispecies'   => \@gd_antispecies,
            'division'        => \@gd_division,
            'flag_delete_gene_descriptions' => $flag_delete_gene_descriptions,
            'output_dir'      => $output_dir,
            'dump_tables'     => $g_dump_tables,
                  };
      }
      # Process the gene name projection hash and create unique species, division and antispecies hashes.
      if ($flag_GeneNames){
        foreach my $pair (keys $g_config){
          push (@g_species, @{$g_config->{$pair}->{'species'}});
          push (@g_antispecies, @{$g_config->{$pair}->{'antispecies'}});
          push (@g_division, @{$g_config->{$pair}->{'division'}});
        }
        @g_species=uniq(@g_species);
        @g_antispecies=uniq(@g_antispecies);
        @g_division=uniq(@g_division);

        $final_projection_backup_list->{"gn"} =
          { 'species'       => \@g_species,
            'antispecies'   => \@g_antispecies,
            'division'        => \@g_division,
            'flag_delete_gene_names' => $flag_delete_gene_names,
            'output_dir'      => $output_dir,
            'dump_tables'     => $g_dump_tables,
                  };
      }
      # Process the go projection hash and create unique species, division and antispecies hashes.
      if ($flag_GO){
        foreach my $pair (keys $go_config){
           push (@go_species, @{$go_config->{$pair}->{'species'}});
           push (@go_antispecies,  @{$go_config->{$pair}->{'antispecies'}});
           push (@go_division,  @{$go_config->{$pair}->{'division'}});
        }
        @go_species=uniq(@go_species);
        @go_antispecies=uniq(@go_antispecies);
        @go_division=uniq(@go_division);

        $final_projection_backup_list->{"go"} =
          { 'species'       => \@go_species,
            'antispecies'   => \@go_antispecies,
            'division'        => \@go_division,
            'flag_delete_go_terms' => $flag_delete_go_terms,
            'output_dir'      => $output_dir,
            'dump_tables'     => $go_dump_tables,
                  };
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

# Create a hash with unique items
sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}


1;



