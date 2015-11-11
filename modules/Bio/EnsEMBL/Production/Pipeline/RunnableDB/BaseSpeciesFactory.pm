=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::RunnableDB::BaseSpeciesFactory;

=head1 DESCRIPTION

 Given a division or a list of species, output species names. Optionally
 send output down different pipes if a species has chromosomes or variants.

=head1 MAINTAINER

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::RunnableDB::BaseSpeciesFactory;

use strict;
use warnings;
use Data::Dumper;
use base qw/Bio::EnsEMBL::Production::Pipeline::RunnableDB::BaseRunnable/;

sub param_defaults {
  my ($self) = @_;
  
  return {
    species         => [],
    division        => [],
    run_all         => 0,
    antispecies     => [],
    core_flow       => 2,
    chromosome_flow => 3,
    variation_flow  => 4,
    div_synonyms    =>
      {
        'eb'  => 'bacteria',
        'ef'  => 'fungi',
        'em'  => 'metazoa',
        'epl' => 'plants',
        'epr' => 'protists',
      },
    meta_filters    => {},
  };
}

sub fetch_input {
  my ($self) = @_;
  my $species      = $self->param('species');
  my @species      = (ref($species) eq 'ARRAY') ? @$species : ($species);
  my $division     = $self->param('division');
  my @division     = (ref($division) eq 'ARRAY') ? @$division : ($division);
  my $run_all      = $self->param('run_all');
  my $antispecies  = $self->param('antispecies');
  my @antispecies  = (ref($antispecies) eq 'ARRAY') ? @$antispecies : ($antispecies);
  my %meta_filters = %{$self->param('meta_filters')};

  my $all_dbas = Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'core');
  my %core_dbas;
  
  if (!scalar(@$all_dbas)) {
    $self->throw("No core databases found in the registry; please check your registry parameters.");
  }
  
  if ($run_all) {
    %core_dbas = map {$_->species => $_} @$all_dbas;
    $self->warning(scalar(@$all_dbas)." species loaded");
    
  } elsif (scalar(@division)) {
    foreach my $division (@division) {
      $self->process_division($all_dbas, $division, \%core_dbas);
    }
    
  } elsif (scalar(@species)) {
    foreach my $species (@species) {
      $self->process_species($all_dbas, $species, \%core_dbas);
    }
    
  } else {
    $self->throw('You must supply one of: -species, -division, -run_all');
    
  }
  
  if (scalar(@antispecies)) {
    foreach my $antispecies (@antispecies) {
      delete $core_dbas{$antispecies};
      $self->warning("$antispecies successfully removed");
    }
  }
  
  if (scalar(keys %meta_filters)) {
    foreach my $meta_key (keys %meta_filters) {
      $self->filter_species($meta_key, $meta_filters{$meta_key}, \%core_dbas);
    }
  }
  
  $self->param('core_dbas', \%core_dbas);
}

sub process_division {
  my ($self, $all_dbas, $division, $core_dbas) = @_;
  my $division_count = 0;
  
  my %div_synonyms = %{$self->param('div_synonyms')};
  if (exists $div_synonyms{$division}) {
    $division = $div_synonyms{$division};
  }
  
  $division = lc($division);
  $division =~ s/ensembl//;
  my $div_long = 'Ensembl'.ucfirst($division);
  
  foreach my $dba (@$all_dbas) {
    my $dbname = $dba->dbc->dbname();
    if ($dbname =~ /$division\_.+_collection_/) {
    #if ($dbname =~ /$division\_\d+_collection_/) {
      $$core_dbas{$dba->species()} = $dba;
      $division_count++
    
    } elsif ($dbname !~ /_collection_/) {
      if ($div_long eq $dba->get_MetaContainer->get_division()) {
        $$core_dbas{$dba->species()} = $dba;
        $division_count++
      }
      $dba->dbc->disconnect_if_idle();
    }
  }
  
  $self->warning("$division_count species loaded for $division");
}

sub process_species {
  my ($self, $all_dbas, $species, $core_dbas) = @_;
  
  foreach my $dba (@$all_dbas) {
    if ($species eq $dba->species()) {
      $$core_dbas{$species} = $dba;
      last;
    }
  }
  
  if (exists $$core_dbas{$species}) {
    $self->warning("$species successfully found");
  } else {
    $self->throw("Core database not found for '$species'; please check your registry parameters.");
  }
}

sub filter_species {
  my ($self, $meta_key, $meta_value, $core_dbas) = @_;
  
  foreach my $species (keys %$core_dbas) {
    my $core_dba = $$core_dbas{$species};
    my $meta_values = $core_dba->get_MetaContainer->list_value_by_key($meta_key);
    unless (exists {map {$_ => 1} @$meta_values}->{$meta_value}) {
      delete $$core_dbas{$species};
      $self->warning("$species successfully removed by filter '$meta_key = $meta_value'");
    }
  }
}

sub run {
  my ($self) = @_;
  my $chromosome_flow = $self->param('chromosome_flow');
  my $variation_flow  = $self->param('variation_flow');
  my $core_dbas       = $self->param('core_dbas');
  my ($chromosome_dbas, $variation_dbas);
  
  if ($chromosome_flow || $variation_flow) {
    foreach my $species (keys %$core_dbas) {
      my $core_dba = $$core_dbas{$species};
      
      if ($chromosome_flow) {
        if ($self->has_chromosome($core_dba)) {
          $$chromosome_dbas{$species} = $core_dba;
        }
      }
      
      if ($variation_flow) {
        if ($self->has_variation($species)) {
          $$variation_dbas{$species} = $core_dba;
        }
      }
    }
  }
  
  $self->param('chromosome_dbas', $chromosome_dbas);
  $self->param('variation_dbas', $variation_dbas);
}

sub has_chromosome {
  my ($self, $dba) = @_;
  my $helper = $dba->dbc->sql_helper();
  my $sql = q{
    SELECT COUNT(*) FROM
    coord_system cs INNER JOIN
    seq_region sr USING (coord_system_id) INNER JOIN
    seq_region_attrib sa USING (seq_region_id) INNER JOIN
    attrib_type at USING (attrib_type_id)
    WHERE cs.species_id = ?
    AND at.code = 'karyotype_rank'
  };
  my $count = $helper->execute_single_result(-SQL => $sql, -PARAMS => [$dba->species_id()]);
  
  $dba->dbc->disconnect_if_idle();
  
  return $count;
}

sub has_variation {
	my ($self, $species) = @_;
  my $dbva = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'variation');
  return $dbva ? 1 : 0;
}

sub write_output {
  my ($self) = @_;
  my $core_dbas       = $self->param('core_dbas');
  my $chromosome_dbas = $self->param('chromosome_dbas');
  my $variation_dbas  = $self->param('variation_dbas');
  
  foreach my $species (sort keys %$core_dbas) {
    $self->dataflow_output_id({'species' => $species}, $self->param('core_flow'));
  }
  
  foreach my $species (sort keys %$chromosome_dbas) {
    $self->dataflow_output_id({'species' => $species}, $self->param('chromosome_flow'));
  }
  
  foreach my $species (sort keys %$variation_dbas) {
    $self->dataflow_output_id({'species' => $species}, $self->param('variation_flow'));
  }
}

1;
