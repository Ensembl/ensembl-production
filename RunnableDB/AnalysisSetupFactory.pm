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

=head1 NAME

Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::AnalysisSetupFactory;

=head1 DESCRIPTION

=head1 AUTHOR

ckong

=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::AnalysisSetupFactory;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::Base');

sub fetch_input {
    my ($self) 	= @_;

    my $required_analysis = $self->param_required('required_analysis') || die "'required_analysis' is an obligatory parameter";
    $self->param('required_analysis', $required_analysis);

return 0;
}

sub write_output {
    my ($self)  = @_;

    $self->dataflow_output_id($self->param('required_analysis'), 2 );

return 0;
}

sub run {
    my ($self)  = @_;

return 0;
}


1;


