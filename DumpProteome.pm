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

package Bio::EnsEMBL::EGPipeline::Common::DumpProteome;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::Base');

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::IO::FASTASerializer;

sub param_defaults {
  my ($self) = @_;
  
  return {
    'allow_stop_codons' => 0,       # Include non-translating proteins
    'header_function'   => undef,  # Custom header function for fasta file
    'chunk_factor'      => 1000,    # Rows of sequence data that are buffered
    'line_width'        => 80,      # Width of sequence data in fasta file
    'use_dbID'          => 0,       # Use dbID rather than default stable_id
  };
  
}

sub fetch_input {
  my ($self) = @_;
  my $proteome_dir = $self->param_required('proteome_dir');
  
  if (!-e $proteome_dir) {
    warning "Output directory '$proteome_dir' does not exist. I shall create it.";
    make_path($proteome_dir) or throw "Failed to create output directory '$proteome_dir'";
  }
  
}

sub run {
  my ($self) = @_;
  my $species = $self->param_required('species');
  my $proteome_file = $self->param('proteome_dir') . "/$species.fa";
  $self->param('proteome_file', $proteome_file);
  
  my $hf = undef;
  if ($self->param_is_defined('header_function')) {
    $hf = eval $self->param('header_function');
  }
  
  my $dba = $self->core_dba();
  my $tra = $dba->get_adaptor("Transcript");
  my $transcripts = $tra->fetch_all_by_biotype('protein_coding');
  
	open my $fh, '>', $proteome_file or throw "Could not open $proteome_file for writing";
  my $serializer =
    Bio::EnsEMBL::Utils::IO::FASTASerializer->new(
      $fh,
      $hf,
      $self->param('chunk_factor'),
      $self->param('line_width')
  );
  
  foreach my $transcript (sort { $a->stable_id cmp $b->stable_id } @{$transcripts}) {
    my $seq_obj = $transcript->translate();
    
    if ($self->param('use_dbID')) {
      $seq_obj->display_id($transcript->translation->dbID);
    }
    
    if ($seq_obj->seq() =~ /\*/ && !$self->param('allow_stop_codons')) {
      warning "Translation for transcript ".$transcript->stable_id." contains stop codons. Skipping.";
    } else {
      if ($seq_obj->seq() =~ /\*/) {
        warning "Translation for transcript ".$transcript->stable_id." contains stop codons.";
      }
      $serializer->print_Seq($seq_obj);
    }
	}
  
	$fh->close();
  
}

sub write_output {
  my ($self) = @_;
  
  $self->dataflow_output_id({'proteome_file' => $self->param('proteome_file')}, 1);
  
}

1;
