
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

use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

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
	$self->hive_dbc()->reconnect_when_lost();
	my $species = $self->param_required('species');
	$self->dump( $species );
	
	
	return;
}

sub dump {
	my ( $self, $species ) = @_;
	throw "dump() must be implemented";
	return;
}

sub write_json {
	my ( $self, $species, $type, $data ) = @_;
	$self->build_base_directory();
	my $sub_dir        = $self->get_data_path('json');
	my $json_file_path = $sub_dir . '/' . $species . '_' . $type . '.json';
	$self->write_json_to_file( $json_file_path, $data );
	return;
}

sub write_json_to_file {
	my ( $self, $json_file_path, $data ) = @_;
	$self->info("Writing to $json_file_path");
	open my $json_file, '>', $json_file_path or
	  throw "Could not open $json_file_path for writing";
	print $json_file encode_json($data);
	close $json_file;
	$self->info("Write complete");
	return;
}
1;
