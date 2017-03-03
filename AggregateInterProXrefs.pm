=head1 LICENSE

Copyright [1999-2015] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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


=pod

=head1 NAME

Bio::EnsEMBL::EGPipeline::InterProPan::Aggregate

=head1 DESCRIPTION

Aggregate InterPro xrefs from a set of core dbs.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::InterProPan::Aggregate;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

sub run {
  my ($self) = @_;
  
  my $filenames   = $self->param_required('filenames');
  my $merged_file = $self->param_required('merged_file');
  my $unique_file = $self->param_required('unique_file');
  
  my $merge_cmd   = "cat ".join(' ', @$filenames)." > $merged_file";
  my $uniqify_cmd = "sort -u $merged_file > $unique_file";
  
  system($merge_cmd)   == 0 or $self->throw("Failed to run ".$merge_cmd);
  system($uniqify_cmd) == 0 or $self->throw("Failed to run ".$uniqify_cmd);
}

1;
