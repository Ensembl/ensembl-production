=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::FlowControl;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

sub write_output {
  my ($self) = @_;
  
  my $control_value = $self->param_required('control_value');
  my $control_flow = $self->param_required('control_flow');
  my $output_ids = $self->param('output_ids') || {};
  my $flow = $self->param('default_flow') || 1;
  
  if (exists $$control_flow{$control_value}) {
    $flow = $$control_flow{$control_value};
  }
  
  $self->dataflow_output_id($output_ids, $flow);
}

1;
