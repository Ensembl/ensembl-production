
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

=cut

package Bio::EnsEMBL::Production::Pipeline::JSON::DumpGenomeJson;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Production::DBSQL::BulkFetcher;
use JSON;
use File::Path qw(make_path);
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Production::Pipeline::JSON::JsonRemodeller;

sub fetch_input {
  my ($self) = @_;

  $self->param( 'dba', $self->core_dba() );

  my $tax_dba  = Bio::EnsEMBL::Registry->get_DBAdaptor( "multi", "taxonomy" );
  my $onto_dba = Bio::EnsEMBL::Registry->get_DBAdaptor( "multi", "ontology" );
  $self->param( 'metadata_dba',
                Bio::EnsEMBL::Registry->get_DBAdaptor( "multi", "metadata" ) );

  $self->param( 'remodeller',
                Bio::EnsEMBL::Production::Pipeline::JSON::JsonRemodeller->new(
                                                      -taxonomy_dba => $tax_dba,
                                                      -ontology_dba => $onto_dba
                ) );

  return;
}

sub param_defaults {
  return {};
}

sub run {
  my ($self) = @_;
  print $self->param('species');
  if ( $self->param('species') ne "Ancestral sequences" ) {
    $self->write_json();
  }
  return;
}

sub write_json {
  my ($self)     = @_;
  my $sub_dir    = $self->get_data_path('json');
  print $sub_dir."\n";
  $self->info( "Processing " . $self->production_name() . " into $sub_dir" );
  my $dba = $self->core_dba();
  my $exporter =
    Bio::EnsEMBL::Production::DBSQL::BulkFetcher->new(
                                                    -LEVEL => 'protein_feature',
                                                    -LOAD_EXONS => 1,
                                                    -LOAD_XREFS => 1 );

  # get compara
  my $division = $self->division();
  if ( !defined $division || $division eq '' ) {
    $division = 'ensembl';
  }
  if ( $division eq 'bacteria' ) {
    $division = 'pan_homology';
  }
  my $compara = $self->get_DBAdaptor( $division, 'compara' );
  if ( defined $compara ) {
    $self->info( "Adding " . $compara->species() . " compara" );
    #$exporter->add_compara($self->production_name(), $genes, $compara);
    $compara->dbc()->disconnect_if_idle();
  }
  # get genome
  my $genome_dba = $self->param('metadata_dba')->get_GenomeInfoAdaptor();
  if ( $division ne 'ensembl' ) {
    $genome_dba->set_ensembl_genomes_release();
  }
  my $md = $genome_dba->fetch_by_name( $self->production_name() );
  die "Could not find genome " . $self->production_name() if !defined $md;

  my $genome = { id           => $md->name(),
                 dbname       => $md->dbname(),
                 species_id   => $md->species_id(),
                 division     => $md->division(),
                 genebuild    => $md->genebuild(),
                 is_reference => $md->is_reference() == 1 ? "true" : "false",
                 organism     => {
                              name                => $md->name(),
                              display_name        => $md->display_name(),
                              scientific_name     => $md->scientific_name(),
                              strain              => $md->strain(),
                              serotype            => $md->serotype(),
                              taxonomy_id         => $md->taxonomy_id(),
                              species_taxonomy_id => $md->species_taxonomy_id(),
                              aliases             => $md->aliases() },
                 assembly => { name      => $md->assembly_name(),
                               accession => $md->assembly_accession(),
                               level     => $md->assembly_level() } };

  $self->info("Exporting genes");
  $genome->{genes} = $exporter->export_genes($dba);
  # remodel
  my $remodeller = $self->param('remodeller');
  if ( defined $remodeller ) {
    $self->info("Remodelling genes");
    $remodeller->remodel_genome($genome);
    $remodeller->disconnect();
  }
  $dba->dbc()->disconnect_if_idle();
  my $json_file_path = $sub_dir . '/' . $self->production_name() . '.json';
  $self->info("Writing to $json_file_path");
  open my $json_file, '>', $json_file_path or
    throw "Could not open $json_file_path for writing";
  print $json_file encode_json($genome);
  close $json_file;
  $self->info("Write complete");
  return;
} ## end sub write_json

1;
