=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::ProcessTranscriptome;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use File::Basename;
use File::Spec::Functions qw(catdir);
use Path::Tiny;

sub write_output {
  my ($self) = @_;
  my $transcriptome_dir  = $self->param('transcriptome_dir');
  my $transcriptome_file = $self->param('transcriptome_file');
  my $pipeline_dir       = $self->param_required('pipeline_dir');
  
  my @files;
  
  if (defined $transcriptome_dir) {
    my $dir = path($transcriptome_dir);
    foreach my $child ($dir->children) {
      push @files, $child->canonpath if $child->is_file;
    }
  }
  
  if (defined $transcriptome_file) {
    push @files, @$transcriptome_file;
  }
  
  foreach my $file (@files) {
    if (-e $file) {
      my ($basename) = fileparse($file, qr/\.[^.]*/);
      my $output_ids =
      {
        'fasta_file' => $file,
        'out_dir'    => catdir($pipeline_dir, $basename),
      };
      $self->dataflow_output_id($output_ids, 2);
    } else {
      $self->throw("Transcriptome file '$file' does not exist");
    }
  }
}

1;
