
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

 Given a list of species, dataflow jobs with species names. 
 Optionally send output down different dataflow if a species has chromosomes or variants.

 Dataflow of jobs can be made intentions aware by using ensembl production
 database to decide if a species has had an update to its DNA or not. An update
 means any change to the assembly or repeat masking.

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub param_defaults {
  my ($self) = @_;

  return { species_list       => [],
           core_list_flow     => 1,
           core_flow          => 2,
           chromosome_flow    => 3,
           variation_flow     => 4,
           # compara_flow       => 5, compara_flow moved to DbFactory; but avoid re-using flow #5 here, to avoid bugs
           regulation_flow    => 6,
           otherfeatures_flow => 7,
           check_intentions   => 0,
  };
}

sub run {
  my ($self) = @_;
  my $species_list       = $self->param_required('species_list');
  my $chromosome_flow    = $self->param('chromosome_flow');
  my $variation_flow     = $self->param('variation_flow');
  my $regulation_flow    = $self->param('regulation_flow');
  my $otherfeatures_flow = $self->param('otherfeatures_flow');

  my @chromosome_species;
  my @variation_species;
  my @regulation_species;
  my @otherfeatures_species;

  if ($chromosome_flow || $variation_flow || $regulation_flow || $otherfeatures_flow) {
    foreach my $species (@$species_list) {
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

  my $flow_species = {
    $chromosome_flow    => \@chromosome_species,
    $variation_flow     => \@variation_species,
    $regulation_flow    => \@regulation_species,
    $otherfeatures_flow => \@otherfeatures_species,
  };

  $self->param('flow_species', $flow_species);
}

sub write_output {
  my ($self) = @_;
  my $species_list     = $self->param_required('species_list');
  my $core_list_flow   = $self->param('species_list');
  my $core_flow        = $self->param('core_flow');
  my $check_intentions = $self->param('check_intentions');
  my $flow_species     = $self->param('flow_species');

  foreach my $species ( @$species_list ) {
    # If check_intention is turned on, then check the production database
    # and decide if data need to be re-dumped.
    my $requires_new_dna = 1;
    if ( $check_intentions == 1 ) {
      $requires_new_dna = $self->requires_new_dna($species);
    }
    my $dataflow_params = {
      species          => $species,
      requires_new_dna => $requires_new_dna,
      check_intentions => $check_intentions,
    };

    $self->dataflow_output_id( $dataflow_params, $core_flow );
  }

  foreach my $flow ( keys %$flow_species ) {
    foreach my $species ( @{ $$flow_species{$flow} } ) {
      $self->dataflow_output_id( { 'species' => $species }, $flow );
    }
  }

  $self->dataflow_output_id( { 'species' => $species_list }, $core_list_flow );
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

sub requires_new_dna {
  my ( $self, $species ) = @_;

  my $sql = <<'SQL';
    select count(*)
    from changelog c
    join changelog_species cs using (changelog_id)
    join species s using (species_id)
    where c.release_id = ?
    and (c.assembly = ? or c.repeat_masking = ?)
    and c.status = ?
    and s.production_name = ?
SQL

  my $release  = $self->param('release');
  my $params   = [ $release, 'Y', 'Y', 'handed_over', $species ];
  my $prod_dba = $self->get_production_DBAdaptor();
  my $result =
    $prod_dba->dbc()->sql_helper()
    ->execute_single_result( -SQL => $sql, -PARAMS => $params );
  $prod_dba->dbc()->disconnect_if_idle();

  return $result;
}

1;
