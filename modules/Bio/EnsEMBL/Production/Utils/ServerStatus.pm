#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package Bio::EnsEMBL::Production::Utils::ServerStatus;

use strict;
use warnings;

use Carp;
use Log::Log4perl qw/get_logger/;
use LWP::UserAgent;
use JSON qw/decode_json/;

use Bio::EnsEMBL::Utils::Argument qw/rearrange/;

my $logger = get_logger();

sub new {

	my ( $class, @args ) = @_;
	my $self = bless( {}, ref($class) || $class );

	( $self->{url}, $self->{retry_wait}, $self->{timeout} ) =
	  rearrange( [ 'URL', 'RETRY_WAIT', 'RETRY_COUNT' ], @args );

	croak "-URL required" unless defined $self->{url};

	if($self->{url} !~ m/\/$/) {
	  $self->{url} .= '/';
	}

	$self->{ua} = LWP::UserAgent->new();
	$self->{retry_wait}  ||= 60;
	$self->{retry_count} ||= 1000;
	return $self;
}

sub get_load {
	my ( $self, $server ) = @_;
	my $url = $self->{url} . 'load/' . $server;
	$logger->debug("Invoking $url");
	my $response = $self->{ua}->get( $url );
	if ( $response->is_success ) {
	  $logger->debug($response->decoded_content);
		return decode_json($response->decoded_content);   
	}
	else {
	  $logger->error("Failed to invoke $url: ".$response->status_line);
	  croak $response->status_line;
	}
}

sub wait_for_load {
	my ($self, $server, $threshold) = @_;
	my $n = 0;
	while($n++<$self->{retry_count}) {
		my $load = $self->get_load($server);
		if($load->{load_1m} <= $threshold) {
			return;
		}
		$logger->debug("Waiting for load on $server");
		sleep $self->{retry_wait};
	}
	croak "Timed out waiting for $server";
}

1;
