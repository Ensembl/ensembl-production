=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Production::EGSpeciesFactory

=head1 DESCRIPTION

An extension of the ClassSpeciesFactory code, for use with
EnsemblGenomes, which uses the production database differently
and thus needs a simpler 'is_run' function.

=cut

package Bio::EnsEMBL::Production::Pipeline::Production::EGSpeciesFactory;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Production::ClassSpeciesFactory/;

sub is_run {
	my ( $self, $dba, $class ) = @_;
	my $production_name = $dba->get_MetaContainer()->get_production_name();

	if ( $class =~ 'karyotype' ) {
		return $self->has_karyotype($dba);
	}
	$dba->dbc()->disconnect_if_idle();
	return 1;
}

sub process_dba {
	my ( $self, $dba ) = @_;
	my $result = $self->SUPER::process_dba($dba);
	if ( $result == 1 && @{ $self->param('division') } ) {
		$result = 0;
		for my $division (@{$self->param('division')}) {
			if($dba->get_MetaContainer()->get_division() eq $division) {
				$result = 1;
				last;
			}
		}
		$dba->dbc()->disconnect_if_idle();
	}
	return $result;
}
1;
