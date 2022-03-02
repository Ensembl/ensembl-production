=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::TaxonomyUpdate::QueryMetadata

=head1 DESCRIPTION

Backup databases before taxonomy update 
=over 8

=item type - The format to parse

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::TaxonomyUpdate::QueryMetadata;

use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw/wrap_array/;

sub fetch_input {
  my ($self) = @_;
  return;
}

sub run {
  my ($self) = @_;
  my $dbname = $self->param('dbname');
  my ($shost, $sport, $suser);
  my ($dba) = @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors_by_dbname($dbname) };
  if (! defined $dba){
	throw "Database $dbname not found in registry.";  
  }
  my $gdba = Bio::EnsEMBL::Registry->get_DBAdaptor("multi", "metadata"); 
  my $tdba =  Bio::EnsEMBL::Registry->get_DBAdaptor( "multi", "taxonomy" );
  $self->warning("Processing $dbname ");
  $self->_meta($dba, $gdba, $tdba);
  $self->warning('Remove depricated');
  #$self->_remove_deprecated($dba);
  return;
}


sub _meta {

  my ( $self, $dba, $gdba, $tdba ) = @_;
  my $dbname = $dba->dbc->dbname;
  $self->warning('Querying Metadata');
  my $metadata = $self->_metadata($dba, $gdba);
  $self->warning('Querying Taxonomy');
  #my $tdba =  Bio::EnsEMBL::Registry->get_DBAdaptor( "multi", "taxonomy" );
  my $taxonomy  = $self->_taxonomy( $tdba, $metadata->{'species.taxonomy_id'});
  $metadata->{'species.classification'} = $taxonomy; 	
  my $mc = $dba->get_MetaContainer();
  $self->warning('Updating meta');
  foreach my $key ( keys %{$metadata} ) {
    my $array = wrap_array( $metadata->{$key} );
    $mc->delete_key($key);
    foreach my $value ( @{$array} ) {
        $mc->store_key_value( $key, $value );
    }
  }
}


sub _metadata {
  my ( $self, $dba, $gdba ) = @_;
  my $dbname = $dba->dbc->dbname;
  #get taxonomy id / production names from meta table
  my $mca = $dba->get_MetaContainer();
  my $taxon = $mca->single_value_by_key('species.taxonomy_id');
  my $production_name = $mca->single_value_by_key('species.production_name');
  if ( !$taxon || !$production_name ){
	  throw "Cannot discover the taxonomy id / production name for the database $dbname. Populate meta table with 'species.taxonomy_id' and 'species.production_name' ";
  }

  #get metadata from metadata db
  my $meta_info_adaptor = $gdba->get_GenomeInfoAdaptor();
  throw "No metadata DB adaptor found" unless defined $meta_info_adaptor;
  $meta_info_adaptor->set_ensembl_release($self->param('ensembl_release'));
  my $meta_data = $meta_info_adaptor->fetch_by_name($production_name)->[0]; 

  my $hash_ref = {
      'species.display_name' => $meta_data->display_name(),
      'species.scientific_name' => $meta_data->scientific_name(),
      'species.production_name' => $meta_data->name(),
      'species.url' => $meta_data->url_name(),
      'species.taxonomy_id' => $meta_data->taxonomy_id(),
      'species.alias' => $meta_data->aliases()
  };

  return $hash_ref;

}

sub _taxonomy {
  my ( $self, $tdba, $taxon_id ) = @_;
  $self->warning('Querying taxonomy for classification');
  my @excluded_ranks = ('root', 'genus', 'species subgroup', 'species group', 'subgenus');
  my @excluded_names = ('cellular organisms', 'root');
  my $sql            = <<'SQL';
select n.name
from ncbi_taxa_node t 
join ncbi_taxa_node t2 on (t2.left_index <= t.left_index and t2.right_index >= t.right_index)
join ncbi_taxa_name n on (t2.taxon_id = n.taxon_id)
where t.taxon_id =?
and n.name_class =? 
and t2.rank not in (?,?,?,?,?)
and n.name not in (?,?)
order by t2.left_index desc
SQL
  my $dbc = $tdba->dbc();
  my $res = $dbc->sql_helper()->execute_simple(
    -SQL    => $sql,
    -PARAMS => [ $taxon_id, 'scientific name', @excluded_ranks, @excluded_names ]
  );
  #$self->warning( 'Classification is [%s]', join( q{, }, @{$res} ) );
  return $res;
}


sub _remove_deprecated {
  my ($self, $dba) = @_;

  if(!$self->param('removedeprecated')) {
    $self->warning('Not removing deprecated meta keys');
    return;
  }
  my $mc  = $dba->get_MetaContainer();
  $self->warning('Removing deprecated meta keys');

  my @deprecated_keys = $self->param('deprecated_keys');
  foreach my $key (@deprecated_keys) {
    $self->warning('Deleting key "%s"', $key);
    $mc->delete_key($key);
  }
  $self->warning('Finished removing deprecated meta keys');
  return;
}

1;
