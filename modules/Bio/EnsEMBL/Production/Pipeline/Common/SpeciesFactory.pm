
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory;

=head1 DESCRIPTION

 Given a division or a list of species, dataflow jobs with species names. 
 Optionally send output down different dataflow if a species has chromosomes or variants.

 Dataflow of jobs can be made intentions aware by using ensembl production
 database to decide if a species has had an update to its DNA or not. An update
 means any change to the assembly or repeat masking.

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::DbFactory/;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    all_species_flow   => 1,
    core_flow          => 2,
    chromosome_flow    => 3,
    variation_flow     => 4,
    compara_flow       => 5,
    regulation_flow    => 6,
    otherfeatures_flow => 7,
  };
}

sub write_output {
  my ($self) = @_;
  my $all_species      = $self->param_required('all_species');
  my $all_species_flow = $self->param('all_species_flow');
  my $core_flow        = $self->param('core_flow');

  foreach my $species ( @{$all_species} ) {
    $self->dataflow_output_id( {'species' => $species}, $core_flow );
  }

  my $flow_species = $self->flow_species($all_species);
  foreach my $flow ( keys %$flow_species ) {
    foreach my $species ( @{ $$flow_species{$flow} } ) {
      $self->dataflow_output_id( {'species' => $species}, $flow );
    }
  }

  $self->dataflow_output_id( {'all_species' => $all_species}, $all_species_flow );
}

sub flow_species {
  my ($self, $all_species) = @_;
  my $compara_dbs        = $self->param('compara_dbs');
  my $chromosome_flow    = $self->param('chromosome_flow');
  my $variation_flow     = $self->param('variation_flow');
  my $compara_flow       = $self->param('compara_flow');
  my $regulation_flow    = $self->param('regulation_flow');
  my $otherfeatures_flow = $self->param('otherfeatures_flow');

  my @chromosome_species;
  my @variation_species;
  my @regulation_species;
  my @otherfeatures_species;
  my @compara_species;

  if ($chromosome_flow || $variation_flow || $regulation_flow || $otherfeatures_flow) {
    foreach my $species ( @{$all_species} ) {
      if ($chromosome_flow) {
        if ( $self->has_chromosome($species) ) {
          push @chromosome_species, $species;
        }
      }

      if ($variation_flow) {
        if ( $self->has_variation($species) ) {
          push @variation_species, $species;
        }
      }
      if ($regulation_flow) {
        if ($self->has_regulation($species)) {
          push @regulation_species, $species;
        }
      }
      if ($otherfeatures_flow){
        if ($self->has_otherfeatures($species)) {
          push @otherfeatures_species, $species;
        }
      }
    }
  }

  if ($compara_flow) {
    foreach my $division ( keys %$compara_dbs ) {
      push @compara_species, $division;
    };
  }

  my $flow_species = {
    $chromosome_flow    => \@chromosome_species,
    $variation_flow     => \@variation_species,
    $regulation_flow    => \@regulation_species,
    $otherfeatures_flow => \@otherfeatures_species,
    $compara_flow       => \@compara_species,
  };

  return $flow_species;
}

sub has_chromosome {
  my ( $self, $species ) = @_;
  my $gc = 
    Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'GenomeContainer');
  
  my $has_chromosome = $gc->has_karyotype();
  
  $gc && $gc->dbc->disconnect_if_idle();

  return $has_chromosome;
}

sub has_variation {
  my ( $self, $species ) = @_;
  my $dbva =
    Bio::EnsEMBL::Registry->get_DBAdaptor( $species, 'variation' );

  my $has_variation = defined $dbva ? 1 : 0;
  
  $has_variation && $dbva->dbc->disconnect_if_idle();

  return $has_variation;
}

sub has_regulation {
  my ($self, $species) = @_;
  my $dbreg = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'funcgen');

  my $has_regulation = defined $dbreg ? 1 : 0;
  
  $has_regulation && $dbreg->dbc->disconnect_if_idle();

  return $has_regulation;
}

sub has_otherfeatures {
  my ($self, $species) = @_;
  my $dbof = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'otherfeatures');

  my $has_otherfeatures = defined $dbof ? 1 : 0;
  
  $has_otherfeatures && $dbof->dbc->disconnect_if_idle();

  return $has_otherfeatures;
}

1;
