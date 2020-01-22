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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::GeneAutocomplete::CreateGeneAutoComplete

=head1 DESCRIPTION

Module to populate the gene_autocomplete table inside the ensembl_website database
This table is used on the ensembl website region in detail, when you type a gene name in the "gene" box.
This module is a port of the following Web script last used in release 97: https://github.com/Ensembl/ensembl-webcode/blob/release/97/utils/make_gene_autocomplete.pl

=head1 MAINTAINER

 maurel@ebi.ac.uk

=cut

package Bio::EnsEMBL::Production::Pipeline::GeneAutocomplete::CreateGeneAutoComplete;
use strict;
use warnings FATAL => 'all';
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub run {
  my ($self) = @_;
  my $species = $self->param('species');
  my $group = $self->param('group');
  $self->hive_dbc()->disconnect_if_idle();
  my $db_uri = $self->param('db_uri');
  #Connect to gene autocomplete database
  my $gene_autocomplete = get_db_connection_params($db_uri);
  # Create Gene autocomplete DB adaptor
  my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host   => $gene_autocomplete->{host},
    -port   => $gene_autocomplete->{port},
    -user   => $gene_autocomplete->{user},
    -pass   => $gene_autocomplete->{pass},
    -dbname => $gene_autocomplete->{dbname},
  );
  my $species_dba = $self->get_DBAdaptor($group);
  # Exclude the collections databases
  return if $species_dba->is_multispecies();
  my $species_id = $species_dba->species_id();
  # Get a list of analysis excluding web_data with gene set to "do_not_display"
  my $analysis_ids = $species_dba->dbc()->sql_helper()->execute(
    -SQL          => qq/SELECT ad.analysis_id
      FROM analysis_description ad, analysis a
      WHERE a.analysis_id = ad.analysis_id AND
            a.logic_name != "estgene" AND
            a.logic_name NOT LIKE "%refseq%" AND
            ad.displayable = 1 AND
            (web_data NOT LIKE '%"gene":"do_not_display"%' or web_data is null)/);
  my $ids = join ',', map { $_->[0] } @{$analysis_ids};
  return unless $ids;
  # Get a list of stable_ids, display_label (gene name), seq_region name, start and end
  my $values = $species_dba->dbc()->sql_helper()->execute(
              -SQL => qq/SELECT g.stable_id, xr.display_label, sr.name, g.seq_region_start, g.seq_region_end
                         FROM gene g, xref xr, seq_region sr, coord_system cs
                         WHERE g.display_xref_id  = xr.xref_id  AND
                         g.seq_region_id    = sr.seq_region_id  AND
                         sr.coord_system_id = cs.coord_system_id AND
                         g.analysis_id IN ($ids) AND cs.species_id = $species_id/,
              -USE_HASHREFS => 1
            );
  # Populate the gene_autocomplete table.
  foreach my $value (@{ $values }) {
    my $location = $value->{name}.":".$value->{seq_region_start}."-".$value->{seq_region_end};
    $dba->dbc()->sql_helper()->execute_update(
        -SQL=>q/INSERT INTO gene_autocomplete (species, stable_id, display_label, location, db) VALUES (?,?,?,?,?)/,
	      -PARAMS=>[$species,$value->{stable_id},$value->{display_label},$location,$group]);
  }
  $species_dba->dbc()->disconnect_if_idle();
  $dba->dbc()->disconnect_if_idle();
  return;
}

#Subroutine to parse Server URI and return connection details
sub get_db_connection_params {
  my ($uri) = @_;
  return '' unless defined $uri;
  my $db = Bio::EnsEMBL::Hive::Utils::URL::parse($uri);
  return $db;
}

1;
