
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

use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher;
use Bio::EnsEMBL::Production::Search::ProbeFetcher;

use JSON;
use File::Path qw(make_path);
use Carp qw(croak);

use Log::Log4perl qw/:easy/;
use Data::Dumper;

sub run {
	my ($self) = @_;
	if ( $self->debug() ) {
		Log::Log4perl->easy_init($DEBUG);
	}
	else {
		Log::Log4perl->easy_init($INFO);
	}
	$self->{logger} = get_logger();
	$self->build_base_directory();
	my $sub_dir = $self->get_data_path('json');

	my $species = $self->param_required('species');

	#$self->dump_features($species);
	$self->dump_probes($species);

	return;
}

sub dump_features {
	my ( $self, $species ) = @_;
	$self->{logger}->info("Dumping regulatory features for $species");
	my $elems =
	  Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher->new()
	  ->fetch_regulatory_elements($species);
	$self->{logger}->info(
			"Dumped " . scalar(@$elems) . " regulatory features for $species" );
	$self->write_json( $species, 'regulatory_elements', $elems )
	  if scalar(@$elems) > 0;
	return;
}

sub dump_probes {
	my ( $self, $species ) = @_;
	$self->{logger}->info("Dumping probes for $species");
	my $all_probes = Bio::EnsEMBL::Production::Search::ProbeFetcher->new()
	  ->fetch_probes($species);
	my $probes = $all_probes->{probes};
	$self->{logger}
	  ->info( "Dumped " . scalar( @{$probes} ) . " probes for $species" );
	$self->write_json( $species, 'probes', $probes ) if scalar(@$probes) > 0;
	my $probe_sets = $all_probes->{probe_sets};
	$self->{logger}->info(
			"Dumped " . scalar( @{$probe_sets} ) . " probe sets for $species" );
	$self->write_json( $species, 'probe_sets', $probe_sets )
	  if scalar(@$probe_sets) > 0;
	return;
}

sub write_json {
	my ( $self, $species, $type, $data ) = @_;
	$self->build_base_directory();
	my $sub_dir        = $self->get_data_path('json');
	my $json_file_path = $sub_dir . '/' . $species . '_' . $type . '.json';
	$self->info("Writing to $json_file_path");
	open my $json_file, '>', $json_file_path or
	  throw "Could not open $json_file_path for writing";
	print $json_file encode_json($data);
	close $json_file;
	$self->info("Write complete");
	return;
}

1;
