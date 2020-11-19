=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

  my $genomes = $gia->fetch_all;
  foreach my $genome (@$genomes) {
    my $production_name = $genome->name;
    my $dba = $self->dba($production_name, 'core');

    my $species_name = $self->species_name($dba);
    $species_name =~ s/_/ /g;

    my $strain = $genome->organism->strain;
    $strain = undef if defined $strain && $strain eq 'reference';

    my $mca = $dba->get_adaptor('MetaContainer');
    my $common_name = $mca->single_value_by_key('species.common_name');
    $common_name = ucfirst($common_name) if defined $common_name;

    my $geneset = $self->geneset($dba);

    my $release_date = $helper->execute_single_result(
      -SQL => $sql,
      -PARAMS => [$genome->organism->dbID]
    );

    $dba->dbc->disconnect_if_idle();

    push @metadata, {
      species => $species_name,
      strain => $strain,
      common_name => $common_name,
      ensembl_production_name  => $production_name,
      taxonomy_id => $genome->organism->taxonomy_id,
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
