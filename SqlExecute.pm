=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
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

Bio::EnsEMBL::EGPipeline::Common::SqlExecute


=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::SqlExecute;

use strict;
use warnings;

use base 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base';

sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults},
    'out_file' => '/dev/null',
  };
}

sub run {
  my ($self) = @_;
  my $sql_file = $self->param_required('sql_file');
  my $out_file = $self->param_required('out_file');
  
  my $cmd = $self->mysql_command_line_connect_core_db();
  $cmd .= ' -N ';  # Suppress header row
  $cmd .= " < $sql_file > $out_file ";
  
  system($cmd) == 0 or $self->throw("Failed to run ".$cmd)
}

1;
