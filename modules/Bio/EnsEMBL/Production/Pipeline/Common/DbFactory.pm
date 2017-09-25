
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

 Bio::EnsEMBL::Production::Pipeline::Common::DbFactory;

=head1 DESCRIPTION

 Given a division or a list of species, dataflow jobs with database names.

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::DbFactory;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub param_defaults {
  my ($self) = @_;

  return { species      => [],
           taxons       => [],
           division     => [],
           run_all      => 0,
           antispecies  => [],
           antitaxons   => [],
           db_list_flow => 1,
           db_flow      => 2,
           compara_flow => 5, # compara_flow moved here from SpeciesFactory; retain former flow #5 here, to avoid bugs
           div_synonyms => { 'eb'  => 'bacteria',
                             'ef'  => 'fungi',
                             'em'  => 'metazoa',
                             'epl' => 'plants',
                             'epr' => 'protists',
                             'e'   => 'ensembl' },
           meta_filters => {},
           db_type      => 'core',
  };
}

sub run {
  my ($self) = @_;
  my @species      = @{ $self->param('species') };
  my @taxons       = @{ $self->param('taxons') };
  my @division     = @{ $self->param('division') };
  my $run_all      = $self->param('run_all');
  my @antispecies  = @{ $self->param('antispecies') };
  my @antitaxons   = @{ $self->param('antitaxons') };
  my %meta_filters = %{ $self->param('meta_filters') };
  my $db_type      = $self->param_required('db_type');

  my $reg = 'Bio::EnsEMBL::Registry';

  my $taxonomy_dba = $reg->get_DBAdaptor( 'multi', 'taxonomy' );

  my $all_dbas = $reg->get_all_DBAdaptors( -GROUP => $db_type );
  my %dbs;

  my $all_compara_dbas;
  if ($self->param('compara_flow')) {
    $all_compara_dbas = $reg->get_all_DBAdaptors( -GROUP => 'compara' );
  }
  my %compara_dbs;

  if ( ! scalar(@$all_dbas) && ! scalar(@$all_compara_dbas) ) {
    $self->throw("No $db_type or compara databases found in the registry");
  }

  if ($run_all) {
    foreach my $dba (@$all_dbas) {
      $self->add_species($dba, \%dbs);
    }
    delete $dbs{'Ancestral sequences'};
    $self->warning("All species in " . scalar(keys %dbs) . " databases loaded");
    
    %compara_dbs = map { $_->dbc->dbname => $_->species } @$all_compara_dbas;
  }
  elsif ( scalar(@species) ) {
    foreach my $species (@species) {
      $self->process_species( $all_dbas, $species, \%dbs );
    }
  }
  elsif ( scalar(@taxons) ) {
    foreach my $taxon (@taxons) {
      $self->process_taxon( $all_dbas , $taxonomy_dba, $taxon, "add", \%dbs );
    }
  }
  elsif ( scalar(@division) ) {
    foreach my $division (@division) {
      $self->process_division( $all_dbas, $division, \%dbs );
      $self->process_division_compara( $all_compara_dbas, $division, \%compara_dbs );
    }
  }

  if ( scalar(@antitaxons) ) {
    foreach my $antitaxon (@antitaxons) {
      $self->process_taxon( $all_dbas, $taxonomy_dba, $antitaxon, "remove", \%dbs );
      $self->warning("$antitaxon taxon removed");
    }
  }  
  if ( scalar(@antispecies) ) {
    foreach my $antispecies (@antispecies) {
      foreach my $dbname ( keys %dbs ) {
        if (exists $dbs{$dbname}{$antispecies}) {
          $self->remove_species($dbname, $antispecies, \%dbs);
          $self->warning("$antispecies removed");
        }
      }
    }
  }

  if ( scalar( keys %meta_filters ) ) {
    foreach my $meta_key ( keys %meta_filters ) {
      $self->filter_species( $meta_key, $meta_filters{$meta_key}, \%dbs );
    }
  }

  $self->param( 'dbs', \%dbs );
  $self->param( 'compara_dbs', \%compara_dbs );
} ## end sub run

sub write_output {
  my ($self) = @_;
  my $dbs          = $self->param_required('dbs');
  my $db_flow      = $self->param_required('db_flow');
  my $db_list_flow = $self->param_required('db_list_flow');
  my $compara_dbs  = $self->param_required('compara_dbs');
  my $compara_flow = $self->param_required('compara_flow');

  my @dbnames = keys %$dbs;
  foreach my $dbname ( @dbnames ) {
    my @species_list = keys %{ $$dbs{$dbname} };
    
    my $dataflow_params = {
      dbname       => $dbname,
      species_list => \@species_list,
      species      => $species_list[0],
    };

    $self->dataflow_output_id( $dataflow_params, $db_flow );
  }

  foreach my $dbname ( keys %$compara_dbs ) {
    my $dataflow_params = {
      dbname  => $dbname,
      species => $$compara_dbs{$dbname},
    };

    $self->dataflow_output_id( $dataflow_params, $compara_flow );
  }

  $self->dataflow_output_id( {dbname_list => \@dbnames}, $db_list_flow );
}

sub add_species {
  my ( $self, $dba, $dbs ) = @_;

  $$dbs{$dba->dbc->dbname}{$dba->species} = $dba;
  
  $dba->dbc->disconnect_if_idle();
}

sub remove_species {
  my ( $self, $dbname, $species, $dbs ) = @_;

  delete $$dbs{$dbname}{$species};
  
  if ( scalar( keys %{ $$dbs{$dbname} } ) == 0 ) {
    delete $$dbs{$dbname};
  }
}

sub process_species {
  my ( $self, $all_dbas, $species, $dbs ) = @_;
  my $loaded = 0;

  foreach my $dba ( @$all_dbas ) {
    if ( $species eq $dba->species() ) {
      $self->add_species($dba, $dbs);
      $self->warning("$species loaded");
      $loaded = 1;
      last;
    }
  }

  if ( ! $loaded ) {
    $self->throw("Database not found for $species; check registry parameters.");
  }
}

sub process_taxon {
  my ( $self, $all_dbas, $taxonomy_dba, $taxon, $action, $dbs ) = @_;
  my $species_count = 0;

  my $node_adaptor = $taxonomy_dba->get_TaxonomyNodeAdaptor();
  my $node = $node_adaptor->fetch_by_name_and_class($taxon,"scientific name");;
  $self->throw("$taxon not found in the taxonomy database") if (!defined $node);
  my $taxon_name = $node->names()->{'scientific name'}->[0];

  foreach my $dba (@$all_dbas) {
    #Next if DB is Compara ancestral sequences
    next if $dba->species() =~ /ancestral/i;
    my $dba_ancestors = $self->get_taxon_ancestors_name($dba,$node_adaptor);
    if (grep(/$taxon_name/, @$dba_ancestors)){
      if ($action eq "add"){
        $self->add_species($dba, $dbs);
        $species_count++;
      }
      elsif ($action eq "remove")
      {
        $self->remove_species($dba->dbc->dbname, $dba->species, $dbs);
        $self->warning($dba->species() . " removed");
        $species_count++;
      }
    }
    $dba->dbc->disconnect_if_idle();
  }

  if ($species_count == 0) {
    $self->throw("$taxon was processed but no species was added/removed")
  }
  else {
    if ($action eq "add") {
      $self->warning("$species_count species loaded for taxon $taxon_name");
    }
    if ($action eq "remove") {
      $self->warning("$species_count species removed for taxon $taxon_name");
    }
  }
}

#Return all the taxon ancestors names for a given dba
sub get_taxon_ancestors_name {
  my ($self, $dba, $node_adaptor) = @_;
  my $dba_node = $node_adaptor->fetch_by_coredbadaptor($dba);
  my @dba_lineage = @{$node_adaptor->fetch_ancestors($dba_node)};
  my @dba_ancestors;
  for my $lineage_node (@dba_lineage) {
    push @dba_ancestors, $lineage_node->names()->{'scientific name'}->[0];
  }
  return \@dba_ancestors;
}

sub process_division {
  my ( $self, $all_dbas, $division, $dbs ) = @_;
  my $species_count = 0;

  my %div_synonyms = %{ $self->param('div_synonyms') };
  if ( exists $div_synonyms{$division} ) {
    $division = $div_synonyms{$division};
  }

  $division = lc($division);
  $division =~ s/ensembl//;
  my $div_long = 'Ensembl' . ucfirst($division);

  foreach my $dba (@$all_dbas) {
    my $dbname = $dba->dbc->dbname();

    if ( $dbname =~ /$division\_.+_collection_/ ) {
      $self->add_species($dba, $dbs);
      $species_count++;
    }
    elsif ( $dbname !~ /_collection_/ ) {
      if ( $div_long eq $dba->get_MetaContainer->get_division() ) {
        $self->add_species($dba, $dbs);
        $species_count++;
      }
      $dba->dbc->disconnect_if_idle();
    }
  }
  $self->warning("$species_count species loaded for $division");
}

sub process_division_compara {
  my ( $self, $all_compara_dbas, $division, $compara_dbs ) = @_;

  foreach my $dba (@$all_compara_dbas) {
    my $compara_div = $dba->species();
    if ( $compara_div eq 'multi' ) {
      $compara_div = 'ensembl';
    }
    if ( $compara_div eq $division ) {
      $$compara_dbs{$dba->dbc->dbname} = $compara_div;
      $self->warning("Added compara for $division");
    }
  }
}

sub filter_species {
  my ( $self, $meta_key, $meta_value, $dbs ) = @_;

  foreach my $dbname ( keys %$dbs ) {
    foreach my $species ( keys %{ $$dbs{$dbname} } ) {
      my $dba = $$dbs{$dbname}{$species};
      my $meta_values = $dba->get_MetaContainer->list_value_by_key($meta_key);
      unless ( exists { map { $_ => 1 } @$meta_values }->{$meta_value} ) {
        $self->remove_species($dbname, $species, $dbs);
        $self->warning("$species removed by filter '$meta_key = $meta_value'" );
      }
    }
  }
}

1;
