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

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::CheckOFDatabase;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

sub param_defaults {
  return {};
}

sub run {
  my ($self) = @_;
  my $species = $self->param_required('species');
  
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'otherfeatures');
  if (defined $dba) {
    eval {
      $dba->dbc->connect();
    };
    if ($@) {
      if ($@ =~ /Unknown database/) {
        $self->param('db_exists', 0);
      } else {
        $self->throw($@);
      }
    } else {
      $self->param('db_exists', 1);
    }
  } else {
    $self->param('db_exists', 0);
  }
}

sub write_output {
  my ($self) = @_;
  
  if ($self->param('db_exists')) {
    $self->dataflow_output_id({'db_exists' => 1}, 2);
  } else {
    $self->dataflow_output_id({'db_exists' => 0}, 3);
  }
}

1;

