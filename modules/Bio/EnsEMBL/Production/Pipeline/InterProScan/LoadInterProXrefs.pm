
=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::LoadInterProXrefs;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR 

 ckong@ebi.ac.uk

=cut

package Bio::EnsEMBL::Production::Pipeline::InterProScan::LoadInterProXrefs;

use strict;
use DBI;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use base (
		 'Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreFeaturesBase');

sub fetch_input {
	my ($self) = @_;

	return 0;
      }

sub write_output {
	my ($self) = @_;

	return 0;
}

sub run {
	my ($self) = @_;
	my ( $interpro_accession, $interpro_description, $interpro_name );

	my $interpro = $self->param_required('interpro_db');

	my $interpro_dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(%$interpro);

	my $core_dba = $self->core_dba;
	my $core_dbh = $core_dba->dbc()->db_handle();
	my $external_dbId =
	  $self->fetch_external_db_id( $core_dba->dbc()->db_handle(), 'Interpro' );

	$interpro_dbc->sql_helper()->execute_no_return(
							  -SQL =>
							  "SELECT entry_ac, name, short_name FROM interpro.entry WHERE checked = 'Y'",
							  -CALLBACK => sub {
							    my $result = shift;
							    my $interpro_accession = $result->[0];
							    my $interpro_description = $result->[1];
							    my $interpro_name = $result->[2];

							    if ( !$self->xref_exists( $core_dbh, $interpro_accession,
										      $external_dbId ) )
							      {
								$self->insert_xref( $core_dbh, {
												external_db_id => $external_dbId,
												dbprimary_acc  => $interpro_accession,
												display_label  => $interpro_name,
												description    => $interpro_description, } );
							      }
							    return;
							  }
							 );
	
	$core_dba->dbc->disconnect_if_idle();
	
	return 0;
      } ## end sub run

1;

