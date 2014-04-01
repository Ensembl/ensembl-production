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

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DumpGenome;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::Base');

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::EGPipeline::Common::Dumper;

sub param_defaults {
  my ($self) = @_;
  return {};
}

sub fetch_input {
  my ($self) = @_;
  return;
}

sub run {
  my ($self) = @_;

  # Instanciate a Bio::EnsEMBL::EGPipeline::Common::Dumper, and delegate to it the charge of dumping the reference genome

  my $dumper = Bio::EnsEMBL::EGPipeline::Common::Dumper->new(
        -REPEAT_LIBS => $self->param('repeat_libs'),
        -SOFT_MASK   => $self->param('soft_mask'),
        -CUTOFF      => $self->param('genomic_slice_cutoff'),
      );

  my $ref = $self->param('genome_dir') . '/' . $self->param('species') . '.fa';

  warn("Dumping reference genome to $ref\n");
  
  $dumper->dump_toplevel($self->core_dba(), $ref);

  $self->dataflow_output_id({'genome_file' => $ref}, 1);

  return;
} ## end sub run

sub write_output {
  my ($self) = @_;
  return;
}

1;
