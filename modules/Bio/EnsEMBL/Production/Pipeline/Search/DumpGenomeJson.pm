
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

package Bio::EnsEMBL::Production::Pipeline::Search::DumpGenomeJson;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Search::BaseDumpJson/;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use JSON;
use File::Path qw(make_path);
use Bio::EnsEMBL::Production::Search::GenomeFetcher;
use Bio::EnsEMBL::Production::Search::GeneFetcher;
use Bio::EnsEMBL::Production::Search::SequenceFetcher;
use Bio::EnsEMBL::Production::Search::MarkerFetcher;
use Bio::EnsEMBL::Production::Search::LRGFetcher;

use Log::Log4perl qw/:easy/;

sub dump {
	my ( $self, $species ) = @_;
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
		my $output = { species => $species };
		$self->{logger}->info( "Dumping genome for " . $species );
		$output->{genome_file} = $self->dump_genome($species);
		$self->{logger}->info( "Dumping genes for " . $species );
		$output->{genes_file} = $self->dump_genes( $species, $compara );
		$self->{logger}->info( "Dumping otherfeatures genes for " . $species );
		$output->{otherfeatures_file} = $self->dump_otherfeatures( $species, $compara );
		$self->{logger}->info( "Dumping sequences for " . $species );
		$output->{seqs_file} = $self->dump_sequences($species);
		$self->{logger}->info( "Dumping markers for " . $species );
		$output->{lrgs_file} = $self->dump_lrgs($species);
		$self->{logger}->info( "Dumping markers for " . $species );
		$output->{markers_file} = $self->dump_markers($species);
		$self->{logger}->info( "Completed dumping " . $species );
		$self->dataflow_output_id( $output, 1 );

	} ## end if ( $species ne "Ancestral sequences")
	return;
} ## end sub dump

sub dump_genome {
	my ( $self, $species, $compara ) = @_;
	my $genome;
	if ( $compara && $compara ne 'multi' ) {
		$genome =
		  Bio::EnsEMBL::Production::Search::GenomeFetcher->new( -EG => 1 )
		  ->fetch_genome($species);
	}
	else {
		$genome = Bio::EnsEMBL::Production::Search::GenomeFetcher->new()
		  ->fetch_genome($species);
	}
	return $self->write_json( $species, 'genome', $genome );
}

sub dump_genes {
	my ( $self, $species, $compara ) = @_;
	my $genes = Bio::EnsEMBL::Production::Search::GeneFetcher->new()
	  ->fetch_genes( $species, $compara );
	return $self->write_json( $species, 'genes', $genes );
}

sub dump_otherfeatures {
	my ( $self, $species ) = @_;
	my $genes = Bio::EnsEMBL::Production::Search::GeneFetcher->new()
	  ->fetch_genes( $species );
	return $self->write_json( $species, 'otherfeatures', $genes );
}

sub dump_sequences {
	my ( $self, $species ) = @_;
	my $sequences = Bio::EnsEMBL::Production::Search::SequenceFetcher->new()
	  ->fetch_sequences($species);
	if ( scalar(@$sequences) > 0 ) {
		return $self->write_json( $species, 'sequences', $sequences );
	}
	else {
		return undef;
	}
}

sub dump_markers {
	my ( $self, $species ) = @_;
	my $markers = Bio::EnsEMBL::Production::Search::MarkerFetcher->new()
	  ->fetch_markers($species);
	if ( scalar(@$markers) > 0 ) {
		$self->write_json( $species, 'markers', $markers );
	}
	else {
		return undef;
	}
}

sub dump_lrgs {
	my ( $self, $species ) = @_;
	my $lrgs =
	  Bio::EnsEMBL::Production::Search::LRGFetcher->new()->fetch_lrgs($species);
	if ( scalar(@$lrgs) > 0 ) {
		$self->write_json( $species, 'lrgs', $lrgs );
	}
	else {
		return undef;
	}
}

1;
