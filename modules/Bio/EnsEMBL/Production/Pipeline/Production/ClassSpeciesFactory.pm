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

Bio::EnsEMBL::Production::Pipeline::Production::ClassSpeciesFactory

=head1 DESCRIPTION

An extension of the SpeciesFactory code. This uses the ensembl production
database to decide if 
- there has been a change to the species
- there is a variation database associated

Allowed parameters are:

=over 8

=item release - Needed to query production with

=back

The registry should also have a DBAdaptor for the production schema 
registered under the species B<multi> and the group B<production>. 

The code adds an additional flow output:

=over 8

=item 4 - Perform DNA reuse

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Production::ClassSpeciesFactory;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::SpeciesFactory/;

use Bio::EnsEMBL::Registry;
use File::Spec;



sub run {
  my ($self) = @_;
  my @dbs;
  foreach my $dba (@{$self->param('dbas')}) {
    if(!$self->process_dba($dba)) {
      $self->fine('Skipping %s', $dba->species());
      next;
    }

    my $all = $self->production_flow($dba, 'all');
    if($all) {
      push(@dbs, [$self->input_id($dba), $all]);
    }
    my $vega = $self->production_flow($dba, 'vega');
    if ($vega) {
      push(@dbs, [$self->input_id($dba), $vega]);
    }
    my $karyotype = $self->production_flow($dba, 'karyotype');
    if ($karyotype) {
      push(@dbs, [$self->input_id($dba), $karyotype]);
    }
    my $variation = $self->production_flow($dba, 'variation');
    if ($variation) {
      push(@dbs, [$self->input_id($dba), $variation]);
    }
  }
  $self->param('dbs', \@dbs);
  return;
}


sub input_id {
  my ($self, $dba) = @_;
  my $mc = $dba->get_MetaContainer();
  $dba->dbc()->disconnect_if_idle();
  my $input_id = {
    species => $mc->get_production_name(),
  };
  return $input_id;
}


sub has_karyotype {
  my ($self, $dba) = @_;
  my $helper = $dba->dbc()->sql_helper();
  my $sql = q{
    SELECT count(*)
    FROM seq_region_attrib sa, attrib_type at, seq_region s, coord_system cs
    WHERE s.seq_region_id = sa.seq_region_id
    AND cs.coord_system_id = s.coord_system_id
    AND at.attrib_type_id = sa.attrib_type_id
    AND cs.species_id = ?
    AND at.code = 'karyotype_rank' };
  my $count = $helper->execute_single_result(-SQL => $sql, -PARAMS => [$dba->species_id()]);
  $dba->dbc()->disconnect_if_idle();
  return $count;
}


sub has_vega {
  my ($self, $dba) = @_;
  my $production_name  = $dba->get_MetaContainer()->get_production_name();
  my $sql = q{
     SELECT count(*)
     FROM db d, species s
     WHERE db_type = 'vega'
     AND d.is_current = 1
     AND s.species_id = d.species_id
     AND db_name = ?
     AND db_release = ? };
  my $prod_dba = $self->get_production_DBAdaptor();
  my @params = ($production_name, $self->param('release'));
  my $result = $prod_dba->dbc()->sql_helper()->execute_single_result(-SQL => $sql, -PARAMS => [@params]);
  $prod_dba->dbc()->disconnect_if_idle();
  return $result;
}

sub has_variation {
  my ($self, $dba) = @_;
  my $production_name  = $dba->get_MetaContainer()->get_production_name();
  my $sql = q{
     SELECT count(*)
     FROM db d, species s
     WHERE db_type = 'variation'
     AND d.is_current = 1
     AND s.species_id = d.species_id
     AND db_name = ?
     AND db_release = ? };
  my $prod_dba = $self->get_production_DBAdaptor();
  my @params = ($production_name, $self->param('release'));
  my $result = $prod_dba->dbc()->sql_helper()->execute_single_result(-SQL => $sql, -PARAMS => [@params]);
  $prod_dba->dbc()->disconnect_if_idle();
  return $result;
}


sub production_flow {
  my ($self, $dba, $class) = @_;
  if($self->is_run($dba, $class)) {
    if ($class =~ 'vega') {
      if ($self->has_vega($dba)) {
        return 5;
      }
    }
    if ($class =~ 'variation') {
      if ($self->has_variation($dba)) {
        return 4;
      }
    }
    if ($class =~ 'karyotype') {
      if ($self->has_karyotype($dba)) {
        return 3;
      }
    }
    if ($class =~ 'all') {
      return 2;
    }
  }
}


sub is_run {
  my ($self, $dba, $class) = @_;
  my $production_name  = $dba->get_MetaContainer()->get_production_name();
  if ($self->param('run_all')) {
    return 1;
  }

  my $sql = <<'SQL';
     SELECT count(*)
     FROM   db_list dl, db d
     WHERE  dl.db_id = d.db_id and db_type = 'core' and is_current = 1 
     AND full_db_name like ?
     AND    species_id IN (
     SELECT species_id 
     FROM   changelog c, changelog_species cs 
     WHERE  c.changelog_id = cs.changelog_id 
     AND    c.is_current = 1
     AND    release_id = ?
     AND    status not in ('cancelled', 'postponed') 
SQL

  my @params = ("$production_name%", $self->param('release'));

  if ($class =~ 'variation') {
    $sql .= <<'SQL';
     AND    (gene_set = 'Y' OR assembly = 'Y' OR repeat_masking = 'Y' OR variation_pos_changed = 'Y'))
     AND    species_id IN (
     SELECT distinct species_id 
     FROM   db 
     WHERE  db_release = ? AND db_type = 'variation')
SQL
    push (@params, $self->param('release'));
  }
  else {
    $sql .= <<'SQL';
     AND    (gene_set = 'Y' OR assembly = 'Y' OR repeat_masking = 'Y'))
SQL
  }

  $dba->dbc()->disconnect_if_idle();
  my $prod_dba = $self->get_production_DBAdaptor();
  my $result = $prod_dba->dbc()->sql_helper()->execute_single_result(-SQL => $sql, -PARAMS => [@params]);
  $prod_dba->dbc()->disconnect_if_idle();
  return $result;
}


sub write_output {
  my ($self) = @_;
  $self->do_flow('dbs');
  return;
}



1;
