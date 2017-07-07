
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

=cut

package Bio::EnsEMBL::Production::Pipeline::Search::DumpGenesJson;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Search::BaseDumpJson/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Registry;

use JSON;
use File::Path qw(make_path);
use Bio::EnsEMBL::Production::Search::GenomeFetcher;
use Bio::EnsEMBL::Production::Search::GeneFetcher;
use Bio::EnsEMBL::Production::Search::SequenceFetcher;
use Bio::EnsEMBL::Production::Search::MarkerFetcher;
use Bio::EnsEMBL::Production::Search::LRGFetcher;
use Bio::EnsEMBL::Production::Search::IdFetcher;
use Log::Log4perl qw/:easy/;

sub dump {
	my ( $self, $species, $type ) = @_;
	if ( $species ne "Ancestral sequences" ) {

		my $compara = $self->param('compara');
		if ( !defined $compara ) {
			$compara = $self->division();
			if ( !defined $compara || $compara eq '' ) {
				$compara = 'multi';
			}
		}
		if ( defined $compara ) {
			$self->{logger}->info("Using compara $compara");
		}

		$type ||= 'core';
		my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $species, $type );

		my $output = { species     => $species,
					   type        => $type,
					   genome_file => $self->param('genome_file') };
		$self->{logger}->info("Dumping data for $species $type");
		$self->{logger}->info("Dumping genes");
		$output->{genes_file} = $self->dump_genes( $dba, $compara, $type );
		$self->{logger}->info("Dumping sequences");
		$output->{sequences_file} = $self->dump_sequences( $dba, $type );
		$self->{logger}->info("Dumping markers");
		$output->{lrgs_file} = $self->dump_lrgs( $dba, $type );
		$self->{logger}->info("Dumping markers");
		$output->{markers_file} = $self->dump_markers( $dba, $type );
		$self->{logger}->info("Dumping IDs");
		$output->{ids_file} = $self->dump_ids( $dba, $type );		
		
		$self->{logger}->info("Completed dumping $species $type");
		$self->dataflow_output_id( $output, 1 );
	} ## end if ( $species ne "Ancestral sequences")
	return;
} ## end sub dump

sub dump_genes {
	my ( $self, $dba, $compara, $type ) = @_;

	my $funcgen_dba;
	my $compara_dba;
	if ( $type eq 'core' ) {
		$funcgen_dba =
		  Bio::EnsEMBL::Registry->get_DBAdaptor( $dba->species(), 'funcgen' );
		$compara_dba =
		  Bio::EnsEMBL::Registry->get_DBAdaptor( $compara, 'compara' )
		  if defined $compara;
	}

	my $genes = Bio::EnsEMBL::Production::Search::GeneFetcher->new()
	  ->fetch_genes_for_dba( $dba, $compara_dba, $funcgen_dba );
	if ( defined $genes && scalar(@$genes) > 0 ) {
		return $self->write_json( $dba->species(), 'genes', $genes, $type );
	}
	else {
		return undef;
	}
}

sub dump_sequences {
	my ( $self, $dba, $type ) = @_;
	my $sequences = Bio::EnsEMBL::Production::Search::SequenceFetcher->new()
	  ->fetch_sequences_for_dba($dba);
	if ( scalar(@$sequences) > 0 ) {
		return $self->write_json( $dba->species, 'sequences', $sequences,
								  $type );
	}
	else {
		return undef;
	}
}

sub dump_markers {
	my ( $self, $dba, $type ) = @_;
	my $markers = Bio::EnsEMBL::Production::Search::MarkerFetcher->new()
	  ->fetch_markers_for_dba($dba);
	if ( scalar(@$markers) > 0 ) {
		$self->write_json( $dba->species, 'markers', $markers, $type );
	}
	else {
		return undef;
	}
}

sub dump_lrgs {
	my ( $self, $dba, $type ) = @_;
	my $lrgs = Bio::EnsEMBL::Production::Search::LRGFetcher->new()
	  ->fetch_lrgs_for_dba($dba);
	if ( scalar(@$lrgs) > 0 ) {
		$self->write_json( $dba->species, 'lrgs', $type );
	}
	else {
		return undef;
	}
}

sub dump_ids {
	my ( $self, $dba, $type ) = @_;
	my $ids = Bio::EnsEMBL::Production::Search::IdFetcher->new()
	  ->fetch_ids_for_dba($dba);
	if ( scalar(@$ids) > 0 ) {
		$self->write_json( $dba->species, 'ids', $ids, $type );
	}
	else {
		return undef;
	}
}


1;
