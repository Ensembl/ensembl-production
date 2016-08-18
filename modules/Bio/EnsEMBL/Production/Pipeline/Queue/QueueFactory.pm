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

Bio::EnsEMBL::Production::Pipeline::Queue::QueueFactory;

=head1 DESCRIPTION

=head1 AUTHOR

ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::Queue::QueueFactory;

use strict;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::Hive::Process');

sub run {
    my ($self)  = @_;

    my $queue_config = $self->param_required('queue_config');

    # Making sure config hash is not empty
    if (keys $queue_config){
       foreach my $pair (sort (keys $queue_config)){
         my $queue = $queue_config->{$pair}->{'queue'};
         my $id    = $queue_config->{$pair}->{'id'};

         $self->dataflow_output_id( {'queue' => $queue, 'id' => $id, },2);      
       }
   }

return 0;
}

1;


