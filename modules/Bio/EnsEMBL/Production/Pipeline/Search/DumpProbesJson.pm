
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

package Bio::EnsEMBL::Production::Pipeline::Search::DumpProbesJson;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Search::BaseDumpJson/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher;
use Bio::EnsEMBL::Production::Search::ProbeFetcher;

use JSON;
use File::Path qw(make_path);
use Carp qw(croak);

use Log::Log4perl qw/:easy/;
use Data::Dumper;

sub dump {
	my ( $self, $species ) = @_;

	my $offset = $self->param('offset');
	my $length = $self->param('length');

	my $sub_dir = $self->get_data_path('json');
	my $probes_json_file_path;
	my $probesets_json_file_path;
	if ( defined $offset ) {
		$probes_json_file_path =
		  $sub_dir . '/' . $species . '_' . $offset . '_probes.json';
		$probesets_json_file_path =
		  $sub_dir . '/' . $species . '_' . $offset . '_probesets.json';
	}
	else {
		$probes_json_file_path = $sub_dir . '/' . $species . '_probes.json';
		$probesets_json_file_path =
		  $sub_dir . '/' . $species . '_probesets.json';
	}

	$self->{logger}->info("Dumping probes for $species");
	my $all_probes = Bio::EnsEMBL::Production::Search::ProbeFetcher->new()
	  ->fetch_probes( $species, $offset, $length );
	my $probes = $all_probes->{probes};
	$self->{logger}
	  ->info( "Dumped " . scalar( @{$probes} ) . " probes for $species" );
	$self->write_json_to_file( $probes_json_file_path, $probes );
	my $probe_sets = $all_probes->{probe_sets};
	$self->{logger}->info(
			"Dumped " . scalar( @{$probe_sets} ) . " probe sets for $species" );
	$self->write_json_to_file( $probesets_json_file_path, $probe_sets );

	$self->dataflow_output_id( {
							   probes_dump_file   => $probes_json_file_path,
							   probeset_dump_file => $probesets_json_file_path,
							   species            => $species },
							 1 );

	  return;
} ## end sub dump

1;
