
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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::Common::MetadataDbFactory;

=head1 DESCRIPTION

 Retrieve species-species database names from the metadata database.

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::MetadataDbFactory;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Hive::Process/;

use Bio::EnsEMBL::Registry;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    division => [],
    group => [],
  };
}

sub run {
  my ($self) = @_;
  my $ensembl_release = $self->param_required('ensembl_release');
  my $division = $self->param_required('division');
  my $group = $self->param_required('group');

  my $mdba = Bio::EnsEMBL::Registry->get_DBAdaptor('multi', 'metadata');

  my $sql = qq/
    SELECT
      gd.dbname,
      lower(replace(d.name, 'Ensembl', '')) AS division
    FROM
      data_release dr INNER JOIN
      genome g USING (data_release_id) INNER JOIN
      genome_database gd USING (genome_id) INNER JOIN
      division d USING (division_id)
    WHERE
      dr.ensembl_version = $ensembl_release
  /;

  if (scalar(@$division)) {
    $sql .= ' AND d.name IN ("Ensembl' . join('", Ensembl"', @$division) . '")';
  }

  if (scalar(@$group)) {
    $sql .= ' AND gd.type IN ("' . join('", "', @$group) . '")';
  }

  my $helper = $mdba->dbc->sql_helper;
  my $dbnames = $helper->execute_into_hash(-SQL => $sql);

  $self->param('dbnames', $dbnames);
}

sub write_output {
  my ($self) = @_;
  my $dbnames = $self->param('dbnames');

  foreach my $dbname (keys %$dbnames) {
    $self->dataflow_output_id(
      {
        dbname => $dbname,
        division => $$dbnames{$dbname},
      },
      2
    );
  }
}

1;
