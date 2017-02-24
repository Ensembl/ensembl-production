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

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::IndexGenome;

use strict;
use warnings;
use base qw(Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base);

sub param_defaults {
  my ($self) = @_;
  
  return {
    'samtools_dir' => '/nfs/panda/ensemblgenomes/external/samtools',
    'threads'      => 4,
    'index_mode'   => 'default',
    'memory_mode'  => 'default',
    'gtf_file'     => undef,
    'overwrite'    => 1,
  };
}

sub fetch_input {
  my ($self) = @_;
  
  if (defined $self->param('escape_branch') and $self->input_job->retry_count >= $self->input_job->analysis->max_retry_count) {
    $self->dataflow_output_id($self->input_id, $self->param('escape_branch'));
    $self->input_job->autoflow(0);
    $self->complete_early("Failure probably due to memory limit, retrying with a higher limit.");
  }
  
  my $aligner_class = $self->param_required('aligner_class');
  my $aligner_dir   = $self->param_required('aligner_dir');
  my $samtools_dir  = $self->param_required('samtools_dir');
  my $threads       = $self->param_required('threads');
  my $index_mode    = $self->param('index_mode');
  my $gtf_file      = $self->param('gtf_file');
  
  eval "require $aligner_class";
  
  my $aligner_object = $aligner_class->new(
    -aligner_dir  => $aligner_dir,
    -samtools_dir => $samtools_dir,
    -threads      => $threads,
    -index_mode   => $index_mode,
    -gtf_file     => $gtf_file,
  );
  $self->param('aligner_object', $aligner_object);
}

sub run {
  my ($self) = @_;
  my $genome_file = $self->param_required('genome_file');
  my $memory_mode = $self->param_required('memory_mode');
  my $overwrite   = $self->param_required('overwrite');
  
  my $index_exists = $self->param('aligner_object')->index_exists($genome_file);
  
  if ($overwrite || ! $index_exists) {
    if ($memory_mode eq 'default' && defined $self->param('escape_branch')) {
      my $sequence_count = qx/cat $genome_file | grep -c ">"/;
      chomp($sequence_count);
      
      if ($sequence_count > 50000) {
        $self->dataflow_output_id($self->input_id, $self->param('escape_branch'));
        $self->input_job->autoflow(0);
        $self->complete_early("Too many sequences ($sequence_count) for default memory settings, retrying with a higher limit.");
      }
    }
    
    $self->param('aligner_object')->index_file($genome_file);
    
  } else {
    $self->warning("Index for file '$genome_file' already exists, and won't be overwritten.");
  }
}

sub write_output {
  my ($self) = @_;
  
  my $index_cmds = $self->param('aligner_object')->index_cmds;
  $self->dataflow_output_id({ 'index_cmds' => $index_cmds }, 1);
}

1;
