
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

package Bio::EnsEMBL::Production::Pipeline::Search::BaseDumpJson;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);

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
	$self->dbc()->reconnect_when_lost(1) if defined $self->dbc();
	my $species = $self->param_required('species');
	my $type = $self->param('type') || 'core';
	$self->dump( $species, $type );

	return;
}

sub dump {
	my ( $self, $species, $type ) = @_;
	throw "dump() must be implemented";
	return;
}

sub write_json {
	my ( $self, $species, $type, $data, $db_type ) = @_;
	$self->build_base_directory();
	my $sub_dir = $self->get_data_path('json');
	if ( defined $db_type && $db_type ne '' && $db_type ne 'core' ) {
		$type = "${db_type}_${type}";
	}
	my $json_file_path = $sub_dir . '/' . $species . '_' . $type . '.json';
	$self->write_json_to_file( $json_file_path, $data );
	return $json_file_path;
}

sub write_json_to_file {
	my ( $self, $json_file_path, $data, $no_brackets ) = @_;
	croak "No data supplied for $json_file_path" unless defined $data;
	$self->info("Writing to $json_file_path");
	open my $json_file, '>', $json_file_path or
	  throw "Could not open $json_file_path for writing";
	if ($no_brackets) {
	        croak "Data supplied for $json_file_path is not an array" unless ref($data) eq 'ARRAY';
	        my $n = 0;
		for my $elem (@$data) {
			if ( $n++ > 0 ) {
				print $json_file ',';
			}
			print $json_file encode_json($elem) || croak "Could not write data element $n to $json_file_path: $!";;
		}
	}
	else {
		print $json_file encode_json($data) || croak "Could not write data to $json_file_path: $!";
	}
	close $json_file;
	$self->info("Write complete");
	return;
}
1;
