
=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

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
		# dump the genome file
		$self->{logger}->info( "Dumping genome for " . $species );
		my $genome_file = $self->dump_genome( $species, $compara );
		$self->{logger}->info( "Completed dumping " . $species );

		# figure out output
		$self->dataflow_output_id( {  species     => $species,
									  type        => 'core',
									  genome_file => $genome_file },
								   2 );

		$self->dataflow_output_id( {  species     => $species,
									  type        => 'otherfeatures',
									  genome_file => $genome_file },
								   7 )
		  if (Bio::EnsEMBL::Registry->get_DBAdaptor( $species, 'otherfeatures' )
		  );

		$self->dataflow_output_id( {  species     => $species,
									  type        => 'variation',
									  genome_file => $genome_file },
								   4 )
		  if ( Bio::EnsEMBL::Registry->get_DBAdaptor( $species, 'variation' ) );

		$self->dataflow_output_id( {  species     => $species,
									  type        => 'funcgen',
									  genome_file => $genome_file },
								   6 )
		  if ( Bio::EnsEMBL::Registry->get_DBAdaptor( $species, 'funcgen' ) )
		  ;

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

1;
