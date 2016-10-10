=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::GVF::StartMergeJobFactory;

=head1 DESCRIPTION

=head1 MAINTAINER 

 ckong@ebi.ac.uk 

=cut

package Bio::EnsEMBL::Production::Pipeline::GVF::StartMergeJobFactory;
#package EGVar::FTP::RunnableDB::GVF::StartMergeJobFactory;

use strict;
use Data::Dumper;
#use base ('EGVar::FTP::RunnableDB::GVF::Base');
use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;
use Carp;

sub run {

    my $self = shift;

    $self->dataflow_output_id({
	worker_id => $self->worker->dbID
    }, 2);
}

1;
