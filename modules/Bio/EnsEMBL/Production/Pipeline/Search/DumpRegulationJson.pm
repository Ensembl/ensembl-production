
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

package Bio::EnsEMBL::Production::Pipeline::Search::DumpRegulationJson;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Search::BaseDumpJson/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher;
use JSON;
use File::Path qw(make_path);
use Carp qw(croak);

use Log::Log4perl qw/:easy/;
use Data::Dumper;

sub dump {
	my ( $self, $species ) = @_;
	$self->{logger}->info("Dumping regulatory features for $species");
	my $elems =
	  Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher->new()
	  ->fetch_regulatory_elements($species);
	if ( defined $elems && scalar(@$elems) > 0 ) {
		$self->{logger}->info(
			"Dumped " . scalar(@$elems) . " regulatory features for $species" );
		my $file = $self->write_json( $species, 'regulatory_elements', $elems )
		  ;
		$self->dataflow_output_id( { dump_file => $file, species => $species },
								   1 );
	}
	return;
}

1;
