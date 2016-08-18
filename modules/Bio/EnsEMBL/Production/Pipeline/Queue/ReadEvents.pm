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

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Queue::ReadEvents;

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::Queue::ReadEvents;

use strict;
use warnings;

use Carp;
use JSON;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use Net::STOMP::Client;
use Log::Log4perl qw/:easy/;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use base ('Bio::EnsEMBL::Hive::Process');

sub param_defaults {
    #return {     delete_existing => 1,
    #};
}

sub fetch_input {
    my ($self)= @_;

    my $queue_host  = $self->param_required('queue_host');
    my $queue_port  = $self->param_required('queue_port');
    my $queue       = $self->param_required('queue');
    my $id          = $self->param_required('id');

    my $pipeline = $ENV{USER}."_InterProScan_86_Seed"; 
    my $IPS_hive = "mysql://ensrw:scr1b3d1\@mysql-eg-devel-1.ebi.ac.uk:4126/$pipeline";

my $logger = get_logger();
    $logger->info("Connecting to $queue_host:$queue_port\n");
    my $stomp = Net::STOMP::Client->new(host => $queue_host, port => $queue_port);
    my $peer  = $stomp->peer();

    $logger->info("connected to broker %s (IP %s), port %d\n", $peer->host(), $peer->addr(), $peer->port());
    $stomp->connect();
    $logger->info("speaking STOMP %s with server %s\n",$stomp->version(), $stomp->server() || "UNKNOWN");
    $logger->info("session %s started\n", $stomp->session());
 
    $self->param('pipeline', $pipeline);
    $self->param('IPS_hive', $IPS_hive);
    $self->param('queue', $queue);    
    $self->param('id', $id);    
    $self->param('stomp', $stomp);

return 0;
}

sub run {
    my ($self) = @_;

    my $pipeline = $self->param_required('pipeline');
    my $IPS_hive = $self->param_required('IPS_hive');
    my $queue    = $self->param_required('queue');
    my $id       = $self->param_required('id');
    my $stomp    = $self->param_required('stomp');

my $logger = get_logger();
    $logger->info("Subscribing to $queue");

    $stomp->subscribe(
	    id => $id,
	    destination             => '/queue/'.$queue,
    	    'ack'                   => 'client',
    	    'activemq.prefetchSize' => 1
    ); 

    while (my $frame = $stomp->wait_for_frames()) {
	  $logger->info("Ack:".$frame->body());
    	  $stomp->ack(id=>$id, frame=>$frame);
    	  $logger->info("Processing ".$frame->body());

	  my $json        = JSON->new->utf8;
    	  my $json_text   = $frame->body();
    	  my $perl_scalar = $json->decode($json_text);

          # Parse JSON message
	  for my $item( @{$perl_scalar->{items}} ){
       	      my $db_name   = $item->{db_name};
       	      my $db_type   = $item->{db_type}; 
       	      my $prod_name = $item->{production_name};
       	      my $division  = $item->{division};
      	      my $event     = $item->{event};

              # Seed jobs for InterProScan pipeline if genebuild change
              if($queue=~/q_InterProScan/){
  	  	  my $cmd = "seed_pipeline.pl -url $IPS_hive -logic_name job_factory -input_id \'{\"species\" => [\"$prod_name\"]}\'";
          	  `$cmd`;
       	      }
          };

         if($frame->body() eq 'quit') {
            $self->info("Couldn't process ".$frame->body());
        	$stomp->nack(id=>$id, frame=>$frame);
            last;
         } 

         $logger->info("All done");
         $logger->info("Waiting for messages");       

    }
   
    # Unsubscribe from queue 
#    $logger->info("Disconnecting from $host:$port");
    $stomp->unsubscribe( id => $id );
    $stomp->disconnect();


return 0;
}

sub write_output {
    my ($self)  = @_;

return 0;
}

1;
