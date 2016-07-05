=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::SpeciesFactory

=head1 DESCRIPTION

A module which generates dump jobs for each species it finds in the Ensembl
Registry. The species we run the code on can be controlled by specifying
the I<species> parameter or by reducing the number of DBAdaptors loaded into
the registry. 

Allowed parameters are:

=over 8

=item species - Can be an array of species to perform dumps for or a single
                species name. If specified only jobs will be created for
                those species. Defaults to nothing so all species are processed

item db_types - Specify the types of database to dump. Defaults to core and
                should be an array.

=back

The code flows once per species to branch 2.

=cut

package Bio::EnsEMBL::Production::Pipeline::SpeciesFactory;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

use Bio::EnsEMBL::Registry;

sub param_defaults {
  my ($self) = @_;
  return {
    db_types => [qw/core/],
    species => []
  };
}

sub fetch_input {
  my ($self) = @_;
  
  $self->reset_empty_array_param('db_types');
  
  my $core_dbas = $self->get_DBAdaptors();
  $self->info('Found %d core DBAdaptor(s) to process', scalar(@{$core_dbas}));
  $self->param('dbas', $core_dbas);
  
  my %species_lookup = 
    map { $_ => 1 } 
    map { Bio::EnsEMBL::Registry->get_alias($_)  } 
    @{$self->param('species')};
  $self->param('species_lookup', \%species_lookup);
  
  return;
}
  
sub run {
  my ($self) = @_;
  my @dna;
  my @genes;
  my @species;
  foreach my $dba (@{$self->param('dbas')}) {
    if(!$self->process_dba($dba)) {
      $self->fine('Skipping %s', $dba->species());
      next;
    }
    my $input_id = $self->input_id($dba);
    push(@species, [ $input_id, 2 ]);
  }
  $self->param('species', \@species);
  return;
}

sub write_output {
  my ($self) = @_;
  $self->do_flow('species');
  return;
}

sub get_DBAdaptors {
  my ($self) = @_;
  return Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'core');
}

sub do_flow {
  my ($self, $key) = @_;
  my $targets = $self->param($key);
  foreach my $entry (@{$targets}) {
    my ($input_id, $flow) = @{$entry};
    $self->fine('Flowing %s to %d for %s', $input_id->{species}, $flow, $key);
    $self->dataflow_output_id($input_id, $flow);
  }
  return;
}

sub process_dba {
  my ($self, $dba) = @_;
  
  #Reject if DB was ancestral sequences
  return 0 if $dba->species() =~ /ancestral/i;
  
  #If species is defined then make sure we only allow those species through
  if(@{$self->param('species')}) {
    my $lookup = $self->param('species_lookup');
    my $name = $dba->species();
    my $aliases = Bio::EnsEMBL::Registry->get_all_aliases($name);
    push(@{$aliases}, $name);
    my $found = 0;
    foreach my $alias (@{$aliases}) {
      if($lookup->{$alias}) {
        $found = 1;
        last;
      }
    }
    return $found;
  }
  
  #Otherwise just accept
  return 1;
}

sub input_id {
  my ($self, $dba, $type) = @_;
  my $mc = $dba->get_MetaContainer();
  my $input_id = {
    db_types => $self->db_types($dba),
    species => $mc->get_production_name(),
  };
  return $input_id;
}

sub db_types {
  my ($self, $dba) = @_;
  return $self->param('db_types');
}

1;
