=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Metadata_JSON;

use strict;
use warnings;
use feature 'say';
use base qw(Bio::EnsEMBL::Production::Pipeline::FileDump::Base_Filetype);

use JSON;
use Path::Tiny;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    data_type => 'species_metadata',
    file_type => 'json',
  };
}

sub fetch_input {
  my ($self) = @_;

  my $dump_dir  = $self->param_required('dump_dir');
  my $data_type = $self->param_required('data_type');
  my $file_type = $self->param_required('file_type');

  my $filename = $self->generate_custom_filename(
    $dump_dir, $data_type, $file_type
  );

  $self->param('filename', $filename);
}

sub run {
  my ($self) = @_;

  my $mdba = $self->dba('multi', 'metadata');
  my $dria = $mdba->get_adaptor('DataReleaseInfo');
  my $gia = $mdba->get_adaptor('GenomeInfo');
  my $helper = $mdba->dbc->sql_helper;

  my $dri = $dria->fetch_current_ensembl_release;
  $gia->data_release($dri);

  my $sql = qq/
    SELECT MIN(release_date) FROM
      genome INNER JOIN
      organism USING (organism_id) INNER JOIN
      data_release USING (data_release_id)
    WHERE organism_id = ?
  /;

  my @metadata;

  # Common names are not stored in the metadata db,
  # so need to look them up in the taxonomy db.
  my $tba = $self->dba('multi', 'taxonomy');
  my $tna = $tba->get_adaptor('TaxonomyNode');

  my $genomes = $gia->fetch_all;
  foreach my $genome (@$genomes) {
    my $production_name = $genome->name;

    my $species_name = $genome->display_name;
    # Replicate the trimming done in FileDump::Base:species_name
    $species_name =~ s/^([\w ]+) [\-\(].+/$1/;

    my $strain = $genome->organism->strain;
    $strain = undef if defined $strain && $strain eq 'reference';

    my $taxonomy_id = $genome->organism->taxonomy_id;

    my $common_name;
    my $node = $tna->fetch_by_taxon_id($taxonomy_id);
    if (defined $node) {
      $common_name = $node->name('genbank common name');
      $common_name = $node->name('common name') if ! defined $common_name;
      if (! defined $common_name && $node->rank eq 'subspecies') {
        $common_name = $node->parent->name('genbank common name');
        $common_name = $node->parent->name('common name') if ! defined $common_name;
      }
      $common_name = ucfirst($common_name) if defined $common_name;
    } else {
      $self->warning("Out-dated taxonomy ID for $production_name: $taxonomy_id");
    }

    # The 'last_geneset_update' value is the last part of the
    # geneset identifier in the metadata db.
    my $geneset = $genome->genebuild;
    if ($geneset =~ /\/(\d{4}\-\d{2})$/) {
      $geneset = $1;
      $geneset =~ tr/-/_/;
    }

    my $release_date = $helper->execute_single_result(
      -SQL => $sql,
      -PARAMS => [$genome->organism->dbID]
    );

    push @metadata, {
      species => $species_name,
      strain => $strain,
      common_name => $common_name,
      ensembl_production_name => $production_name,
      taxonomy_id => $taxonomy_id,
      assembly_accession => $genome->assembly_accession,
      assembly_name => $genome->assembly_name,
      geneset => $geneset,
      release_date => $release_date
    };
  }

  @metadata = sort { $$a{'species'} cmp $$b{'species'} } @metadata;
  my $json = JSON->new->canonical->pretty->encode(\@metadata);

  my $filename = $self->param_required('filename');
  path($filename)->spew($json);
  path($filename)->chmod("g+w");
}

1;
