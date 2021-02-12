=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

  Bio::EnsEMBL::Production::Utils::QueueAppender

=head1 SYNOPSIS

my $log = Log::Log4perl->get_logger("Foo::Bar");

# set contextual properties that will be added to the messages generated
Log::Log4perl::MDC->put('host',hostname);
Log::Log4perl::MDC->put('resource','myres');
Log::Log4perl::MDC->put('process','pid');
Log::Log4perl::MDC->put('params',{param1=>'val1'});

# create an appender with a connection to RabbitMQ
my $q_appender =  Log::Log4perl::Appender->new(
                                                    "Bio::EnsEMBL::Utils::QueueAppender",
                                                    host=>'localhost',
                                                    user=>'myuser',
                                                    password=>'mypass',
                                                    exchange=>'report_exchange');

$log->add_appender($q_appender);

# use the log
$log->info("Hello, world!");

=head1 DESCRIPTION

Custom appender for Log4Perl that writes messages as JSON to a specified RabbitMQ instance.
Intended for use with the ensembl-prodinf-report infrastructure.

=cut


package Bio::EnsEMBL::Production::Utils::QueueAppender;

use warnings;
use strict;

use base qw/Log::Log4perl::Appender/;

use Carp;
use JSON qw/encode_json/;
use Net::AMQP::RabbitMQ;
use POSIX 'strftime';

my $binding_keys = {
                    FATAL=>'report.fatal',
                    ERROR=>'report.error',
                    INFO=>'report.info',
                    DEBUG=>'report.debug',
                    WARN=>'report.warn'
                   };

my @keys = qw/host process resource params/;

sub new {
    my($class, @options) = @_;
    my $self = {
        @options,
    };
    $self->{channel} ||= 1;
    $self->{exchange} ||= 'report_exchange';
    $self->{mq} = Net::AMQP::RabbitMQ->new();
    $self->{mq}->connect($self->{host}, { user => $self->{user}, password => $self->{password} });
    $self->{mq}->channel_open($self->{channel});
    bless $self, $class;
    return $self;
}

sub log {
  my($self, %params) = @_;
  my $key = $binding_keys->{$params{log4p_level}};
  croak "Could not find binding key for ".$params{log4p_level} unless defined $key;
  my $msg = {message=>$params{message}};
  for my $key (@keys) {
    my $value = Log::Log4perl::MDC->get($key);
    $msg->{$key} = $value if defined $value;
  }
  $msg->{level} = $params{log4p_level};
  $msg->{message} =~ s/^[A-Z]+ - (.*)\n?$/$1/;
  # yyyy-MM-ddTHH:mm:ss
  $msg->{report_time} = strftime '%Y-%m-%dT%H:%M:%S', localtime;;
  $self->{mq}->publish($self->{channel}, $key, encode_json($msg), { exchange => $self->{exchange} });
  return;
}

1;
