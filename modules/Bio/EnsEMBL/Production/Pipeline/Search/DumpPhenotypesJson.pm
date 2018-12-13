
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

package Bio::EnsEMBL::Production::Pipeline::Search::DumpPhenotypesJson;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Search::BaseDumpJson/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Production::Search::VariationFetcher;

use JSON;
use File::Path qw(make_path);
use Carp qw(croak);

use Log::Log4perl qw/:easy/;

sub dump {
	my ( $self, $species ) = @_;

	$self->{logger}->debug("Fetching DBA for $species");
	my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $species, 'variation' );

	throw "No variation database found for $species" unless defined $dba;
	my $phenotypes = Bio::EnsEMBL::Production::Search::VariationFetcher->new()
	  ->fetch_phenotypes($species);
	if ( defined $phenotypes && scalar(@$phenotypes) > 0 ) {
		my $file =
		  $self->write_json( $species, 'phenotypes', $phenotypes );
		$self->dataflow_output_id( { dump_file => $file, species => $species, genome_file=>$self->param('genome_file'), type=>'variation' },
								   2 );
	}
	return;
}

1;
