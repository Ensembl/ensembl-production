#!/usr/bin/env perl
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


=head1 NAME

Bio::EnsEMBL::Production::Utils::ServerStatus - find server status using production infrastructure REST services

=head1 SYNOPSIS

    use Bio::EnsEMBL::Production::Utils::ServerStatus;
    my $stat = Bio::EnsEMBL::Production::Utils::ServerStatus->new(-URL=>'http://myrestsrv:5001/hosts/%s/load');
    my $srv = "mysql-mine-all-mine";
    # print the current load
    print $stat->get_load($srv)."\n";
    $stat->wait_for_load(10);
    print $stat->get_load($srv)."\n";

=head1 DESCRIPTION

This module 

=head2 Methods

=over 12

=item C<new>

Returns a new object. Arguments:

=over 4

=item C<-URL> - URL for server load endpoint. Use %s as placeholder for server

=item C<-RETRY_WAIT> - number of seconds to wait between calls to load (default 60)

=item C<-RETRY_COUNT> - number of times to try for desired load before giving up (default 1000)

=back


=item C<get_load>

Return the current 1m, 5m and 15m loads for the specified server as a hashref.

=item C<wait_for_load>

Wait until the 1m load for the specified server drops to below the specified threshold.

Arguments:

=over 4

=item name of server

=item 1m load threshold

=back

=back

=head1 AUTHOR

Dan Staines <dstaines@ebi.ac.uk>

=cut

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

	$self->{ua} = LWP::UserAgent->new();
	$self->{retry_wait}  ||= 60;
	$self->{retry_count} ||= 1000;
	return $self;
}

sub get_load {
	my ( $self, $server ) = @_;
	my $url = sprintf($self->{url}, $server);
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
