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

=head1 NAME

    RDFDump - Hive Process to start with a species name and produce triples

=head1 DESCRIPTION

    This process relies heavily on modules found in the VersioningService repository
    It gets the appropriate data from BulkFetcher, and serialises to RDF

=cut

package Bio::EnsEMBL::Production::Pipeline::RDF::RDFDump;

use strict;
use warnings;

use parent ('Bio::EnsEMBL::Production::Pipeline::Base');
use Bio::EnsEMBL::RDF::EnsemblToTripleConverter;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;
use Bio::EnsEMBL::Production::DBSQL::BulkFetcher;
use IO::File;
use File::Spec::Functions qw/catdir/;

sub fetch_input {
    my $self = shift;
    $self->param_required('species');   # just make sure it has been passed
    $self->param_required('config_file');
    $self->param_required('release');
    my $eg = $self->param('eg');
    $self->param('eg', $eg);

    if($eg){
      my $base_path  = $self->build_base_directory();
      $self->param('base_path', $base_path);
      my $release = $self->param('eg_version');
      $self->param('release', $release);
    }

}


sub run {
    my $self = shift;
    my $species = $self->param('species');
    my $config_file = $self->param('config_file'); # config required for mapping Ensembl things to RDF (xref_LOD_mapping.json)
    my $release = $self->param('release');
    my $production_name = $self->production_name;
    my $path = $self->data_path();
    unless (defined $path && $path ne '') { $path = $self->get_dir($release) };
    my $target_file = catdir($path, $species.".ttl");
    my $main_fh = IO::File->new($target_file,"w") || die "$! $target_file";
    my $xref_file = catdir($path, $species."_xrefs.ttl");
    my $xref_fh;
    $xref_fh = IO::File->new($xref_file,"w") if $self->param('xref');
    my $dba = $self->get_DBAdaptor; 

    my $division = 'Multi';
    $division    = $self->division() if ($self->param('eg'));
    my $compara_dba = Bio::EnsEMBL::Registry->get_adaptor($division, 'compara', 'GenomeDB');
    # Configure bulk extractor to go all the way down to protein features.
    # Can also be told to stop at transcript level as well as others.
    my $bulk = Bio::EnsEMBL::Production::DBSQL::BulkFetcher->new(-level => 'protein_feature');
    my $gene_array = $bulk->export_genes($dba,undef,'protein_feature',$self->param('xref'));
    $bulk->add_compara($species, $gene_array, $compara_dba);

    # Configure triple converter
    my $converter_config = { 
      ontology_adaptor => Bio::EnsEMBL::Registry->get_adaptor('multi','ontology','OntologyTerm'),
      meta_adaptor => $dba->get_MetaContainer,
      species => $species,
      xref => $self->param('xref'),
      release => $release,
      xref_mapping_file => $config_file,
      main_fh => $main_fh,
      xref_fh => $xref_fh,
      production_name => $production_name
    };
    my $triple_converter = Bio::EnsEMBL::RDF::EnsemblToTripleConverter->new($converter_config);

    # start writing out
    $triple_converter->print_namespaces;
    $triple_converter->print_species_info;

    my $is_human;
    $is_human = 1 if $species eq 'homo_sapiens';
    my $slices = $self->get_Slices(undef,$is_human); # see Production::Pipeline::Base;
    $triple_converter->print_seq_regions($slices);

    # Fetch all the things!
    while (my $gene = shift @$gene_array) {
        my $feature_uri = $triple_converter->generate_feature_uri($gene->{id},'gene');
        $triple_converter->print_feature($gene,$feature_uri,'gene');
    }

    # Add a graph file for Virtuoso loading.
    my $graph_path = $path;
    $self->param('dir', $graph_path);
    unless ($graph_path) { $graph_path = $self->get_dir($release) };
    
    $triple_converter->create_virtuoso_file(sprintf("%s/%s.graph",$graph_path,$production_name));
    $triple_converter->create_virtuoso_file(sprintf("%s/%s_xrefs.graph",$graph_path,$production_name));

    #compress the files
    system("gzip $target_file");
    $target_file=$target_file.'.gz';
    system("gzip $xref_file");
    $xref_file=$xref_file.'.gz';

    # Create list of files to validate
    my @files_to_validate = ($target_file);
    if ($self->param('xref')) { push @files_to_validate, $xref_file }
    $self->param('validate_me', \@files_to_validate);
    $main_fh->close;
    $xref_fh->close if defined $xref_fh;
}


sub write_output {  # store and dataflow
    my $self = shift;
    my $files = $self->param('validate_me');
    my $dir = $self->param('dir');
    while (my $file = shift @$files) {
        $self->dataflow_output_id({filename => $file},2);
    }
    $self->dataflow_output_id({dir => $dir},3);
}

sub data_path {
  my ($self) = @_;

  $self->throw("No 'species' parameter specified")
    unless $self->param('species');

  return $self->get_dir('rdf', $self->param('species'));
}
1;
