
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::Common::MultiDbFactory;

=head1 DESCRIPTION

 Retrieve 'multi' database names from the metadata database.

=cut

package Bio::EnsEMBL::Production::Pipeline::Common::MultiDbFactory;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Hive::Process/;

use Bio::EnsEMBL::Registry;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    division => [],
    marts => 0,
    compara => 0,
    pan_ensembl => 0,
    pan_ensembl_name => 'pan_ensembl',
  };
}

sub run {
  my ($self) = @_;
  my $ensembl_release = $self->param_required('ensembl_release');
  my $division = $self->param_required('division');
  my $marts = $self->param_required('marts');
  my $compara = $self->param_required('compara');
  my $pan_ensembl = $self->param_required('pan_ensembl');
  my $pan_ensembl_name = $self->param_required('pan_ensembl_name');

  my $mdba = Bio::EnsEMBL::Registry->get_DBAdaptor('multi', 'metadata');

  my $sql = qq/
    SELECT
      drd.dbname,
      lower(replace(d.name, 'Ensembl', '')) AS division
    FROM
      data_release dr INNER JOIN
      data_release_database drd USING (data_release_id) INNER JOIN
      division d USING (division_id)
    WHERE
      dr.ensembl_version = $ensembl_release
    
    UNION
    
    SELECT DISTINCT
      ca.dbname,
      lower(replace(d.name, 'Ensembl', '')) AS division
    FROM
      data_release dr INNER JOIN
      compara_analysis ca USING (data_release_id) INNER JOIN
      division d USING (division_id)
    WHERE
      dr.ensembl_version = $ensembl_release
  /;

  my $helper = $mdba->dbc->sql_helper;
  my $dbnames = $helper->execute_into_hash(-SQL => $sql);

  my %divisions = map { $_ => 1 } @$division;

  my %filtered_dbnames;
  foreach my $dbname (keys %$dbnames) {
    if ($$dbnames{$dbname} eq 'pan') {
      if ($pan_ensembl) {
        $filtered_dbnames{$dbname} = $pan_ensembl_name;
      }
    } else {
      my $mart_dbname = ($dbname =~ /_mart_/);
      my $compara_dbname = ($dbname =~ /_(ancestral|compara)_/);
      if ( ($marts && $mart_dbname) || ($compara && $compara_dbname) ) {
        if (scalar(@$division)) {
          if (exists($divisions{$$dbnames{$dbname}})) {
            $filtered_dbnames{$dbname} = $$dbnames{$dbname};
          }
        } else {
          $filtered_dbnames{$dbname} = $$dbnames{$dbname};
        }
      }
    }
  }

  $self->param('dbnames', \%filtered_dbnames);
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
