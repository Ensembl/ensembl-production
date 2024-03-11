=head1 LICENSE
Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute
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
Bio::EnsEMBL::Production::Pipeline::ProductionDBSync::PopulateControlledTables

=head1 DESCRIPTION
A Module for synchronising controlled tables
=cut

package Bio::EnsEMBL::Production::Pipeline::ProductionDBSync::PopulateControlledTables;

use strict;
use warnings;
use Bio::EnsEMBL::Production::Utils::ProductionDbUpdater;

use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub param_defaults {
  return {
    core_tables => [
      'attrib_type',
      'biotype',
      'external_db',
      'misc_set',
      'unmapped_reason'
      ],
    variation_tables => [
      'attrib',
      'attrib_set',
      'attrib_type'
      ],
  };
}

sub run {
  my ($self) = @_;
  my $species = $self->param('species');
  my $group = $self->param('group');

  my $dba = $self->get_DBAdaptor($group);
  $self->throw("Could not fetch $species $group database") unless defined $dba;

  my $prod_dba = $self->get_DBAdaptor('production');
  $self->throw('Could not fetch production database') unless defined $prod_dba;

  my $updater =
	  Bio::EnsEMBL::Production::Utils::ProductionDbUpdater->new(
      -PRODUCTION_DBA => $prod_dba
    );

  my $tables;
  if ($group =~ /^(cdna|core|otherfeatures|rnaseq)$/) {
	  $tables = $self->param('core_tables');
  } elsif ($group eq 'variation') {
	  $tables = $self->param('variation_tables');
  } else {
	  $self->throw("No controlled tables for $group databases");
  }
	  
  $updater->update_controlled_tables($dba->dbc, $tables);

  $dba->dbc && $dba->dbc->disconnect_if_idle();
  $prod_dba->dbc && $prod_dba->dbc->disconnect_if_idle();
}

1;
