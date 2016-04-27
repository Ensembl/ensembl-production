#!/usr/bin/env perl
use warnings;
use strict;

use Net::STOMP::Client;
use Log::Log4perl qw/:easy/;
use Getopt::Long;
use Carp;
use Pod::Usage;
use Data::Dumper;

my $opts = {};
GetOptions ($opts, 'verbose', 'host:s', 'port:s', 'queue|q:s', 'id:s');

if ( $opts->{verbose} ) {
  Log::Log4perl->easy_init($DEBUG);
}
else {
  Log::Log4perl->easy_init($INFO);
}
my $logger = get_logger();

$opts->{host} ||= 'ebi-007.ebi.ac.uk';
$opts->{port} ||= '61613';
$opts->{id}   ||= "test1";

croak "Specify -queue" unless $opts->{queue};

$logger->info("Connecting to $opts->{host}:$opts->{port}");
my $stomp = Net::STOMP::Client->new( host => $opts->{host}, port => $opts->{port} );
$stomp->connect();

$logger->info("Writing message to $opts->{queue}");
$stomp->send(destination => '/queue/'.$opts->{queue}, body => "hello world test!" );

$logger->info("Subscribing to $opts->{queue}");
$stomp->subscribe(
    id => $opts->{id},
    destination             => '/queue/'.$opts->{queue},
    'ack'                   => 'client',
    'activemq.prefetchSize' => 1
    );

#while (my $frame = $stomp->wait_for_frames()) {
#    $logger->info("Ack:".$frame->body());
#    $stomp->ack(id=>$opts->{id}, frame=>$frame);
#    $logger->info("Processing ".$frame->body());
#}
