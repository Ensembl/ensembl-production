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

=cut

package Bio::EnsEMBL::Production::Pipeline::Webdatafile::GenomeInfo;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Production::Search::GenomeFetcher;


sub run {
	my ( $self) = @_;
        my $species = $self->param('species');
	if ( $species !~ /Ancestral sequences/ ) {
		my $compara = $self->param('compara');
		if ( !defined $compara ) {
			$compara = $self->division();
			if ( !defined $compara || $compara eq '' ) {
				$compara = 'multi';
			}
		}
		my %genome = %{$self->genome_info( $species, $compara )};
		# figure out output
		$self->dataflow_output_id( {  
                        species    => $species,
			group      => 'core',
                        genome_id  => $species . '_' . $genome{'assembly'}{'accession'},
                        gca        => $genome{'assembly'}{'accession'},
                        level      => $genome{'assembly'}{'level'},
                        assembly_default => $genome{'assembly'}{'default'},       
                        assembly_ucsc => $genome{'assembly'}{'ucsc'},       
                        dbname     => $genome{'dbname'},
                        version    => $genome{'assembly'}{'name'},  
                        division   => $genome{'division'},
                       species_id  => $genome{'species_id'},         
                       root_path   => $self->param('output_path'),   
                }, 1 );

	} 
} ## end sub dump

sub genome_info {
	my ( $self, $species, $compara ) = @_;
	my $genome;
	if ( $compara && $compara ne 'multi' ) {
		$genome =
		  Bio::EnsEMBL::Production::Search::GenomeFetcher->new(  -ENS_VERSION => $self->param('ENS_VERSION'), -EG_VERSION => $self->param('EG_VERSION') )
		  ->fetch_genome($species);
	}
	else {
		$genome = Bio::EnsEMBL::Production::Search::GenomeFetcher->new()
		  ->fetch_genome($species);
	}
	return $genome;
}

1;
