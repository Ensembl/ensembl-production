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
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

use Bio::EnsEMBL::EGPipeline::Common::Dumper;
use File::Path qw(make_path);

sub param_defaults {
  my ($self) = @_;
  
  return {
    'header_function'      => undef,  # Custom header function for fasta file (string, will be 'eval'ed)
    'chunk_factor'         => 1000,   # Rows of sequence data that are buffered
    'line_width'           => 80,     # Width of sequence data in fasta file
    'repeat_mask'          => 0,      # 0 or 1, to disable or enable repeat masking
    'repeat_libs'          => [],     # arrayref of logic_names, e.g. ['repeatmask']
    'soft_mask'            => 1,      # 0 or 1, to disable or enable softmasking
    'genomic_slice_cutoff' => 0,      # threshold for the minimum slice length
    'overwrite'            => 0,
  };
  
}

sub fetch_input {
  my ($self) = @_;
  my $genome_dir = $self->param_required('genome_dir');
  
  if (!-e $genome_dir) {
    $self->warning("Output directory '$genome_dir' does not exist. I shall create it.");
    make_path($genome_dir) or $self->throw("Failed to create output directory '$genome_dir'");
  }
  
}

sub run {
  my ($self) = @_;
  my $species = $self->param_required('species');
  my $genome_file = $self->param('genome_dir') . "/$species.fa";
  $self->param('genome_file', $genome_file);
  
  if (-e $genome_file) {
    if ($self->param('overwrite')) {
      $self->warning("Genome file '$genome_file' already exists, and will be overwritten.");
    } else {
      $self->warning("Genome file '$genome_file' already exists, and won't be overwritten.");
      return;
    }
  }
  
  my $hf = undef;
  if ($self->param_is_defined('header_function')) {
    $hf = eval $self->param('header_function');
  }
  
  if ($self->param('repeat_mask')) {
    if (! defined $self->param('repeat_libs') || scalar(@{$self->param('repeat_libs')}) == 0) {
      my $repeat_libs = $self->core_dba->get_MetaContainer->list_value_by_key('repeat.analysis');
      $self->param('repeat_libs', $repeat_libs);
    }
  }
  
  # Instantiate a Bio::EnsEMBL::EGPipeline::Common::Dumper,
  # and delegate to it the charge of dumping the genome
  my $dumper = Bio::EnsEMBL::EGPipeline::Common::Dumper->new(
    -HEADER      => $hf,
    -WIDTH       => $self->param('line_width'),
    -CHUNK       => $self->param('chunk_factor'),
    -REPEAT_LIBS => $self->param('repeat_libs'),
    -SOFT_MASK   => $self->param('soft_mask'),
    -CUTOFF      => $self->param('genomic_slice_cutoff'),
  );
  
  $dumper->dump_toplevel($self->core_dba(), $genome_file);
  
}

sub write_output {
  my ($self) = @_;
  
  $self->dataflow_output_id({'genome_file' => $self->param('genome_file')}, 1);
  
}

1;
