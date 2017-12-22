=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Xrefs::AlignmentFactory

=head1 DESCRIPTION

Examines FASTA files to be compared and generates alignment jobs to process the results in reasonable parallelism

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::AlignmentFactory;

use strict;
use warnings;
use File::stat;
use File::Path qw/make_path/;
use File::Spec;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my $self = shift;
  my $species       = $self->param_required('species');
  my $target_file   = $self->param_required('xref_fasta');
  my $source_file   = $self->param_required('ensembl_fasta');
  my $seq_type      = $self->param_required('seq_type');
  my $xref_url      = $self->param_required('xref_url');
  my $base_path     = $self->param_required('base_path');
  my $method        = $self->param_required('method');
  my $query_cutoff  = $self->param_required('query_cutoff');
  my $target_cutoff = $self->param_required('target_cutoff');
  my $job_index     = $self->param_required('job_index');
  
  # inspect file size to decide on chunking
  my $size = stat($target_file)->size;
  my $chunks = int ($size / 1000000) + 1;
  $self->warning(sprintf('Spawning %d alignment jobs for %s',$chunks,$target_file),'INFO');

  my $output_path = File::Spec->catfile($species, 'alignment');
  make_path($output_path);

  for (my $chunklet = 1; $chunklet <= $chunks; $chunklet++) {
    my $output_path_chunk = $output_path . sprintf "/%s_alignment_%s_of_%s.map", $seq_type, $chunklet, $chunks;
    $self->dataflow_output_id({
      align_method  => $method, 
      query_cutoff  => $query_cutoff,
      target_cutoff => $target_cutoff,
      max_chunks    => $chunks, 
      chunk         => $chunklet, 
      job_index     => $job_index,
      source_file   => $source_file, 
      target_file   => $target_file, 
      xref_url      => $xref_url,
      target_source => $self->param('source'),
      map_file      => $output_path_chunk,
      seq_type      => $seq_type
    },2);
  }
}





1;
