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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::Cleanup;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::Cleanup;

use strict;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::Base');

sub run {
    my $self = shift @_;
    my $pipeline_dir                   = $self->param('pipeline_dir');
    my $delete_pipeline_dir_at_cleanup = $self->param('delete_pipeline_dir_at_cleanup');
    
    if ($delete_pipeline_dir_at_cleanup) {
		use File::Path qw( remove_tree );
		remove_tree($pipeline_dir);
    }
}


1;

