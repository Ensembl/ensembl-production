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

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::DumpTranscriptome;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

use Bio::EnsEMBL::Utils::IO::FASTASerializer;

use File::Path qw(make_path);
use File::Spec::Functions qw(catdir);

sub param_defaults {
  my ($self) = @_;
  
  return {
    'overwrite'         => 0,
    'header_style'      => 'default',
    'chunk_factor'      => 1000,
    'line_width'        => 80,
    'file_varname'      => 'transcriptome_file',
  };
  
}

sub fetch_input {
  my ($self) = @_;
  
  my $transcriptome_file = $self->param('transcriptome_file');
  my $transcriptome_dir  = $self->param('transcriptome_dir');
  my $species            = $self->param('species');
  
  if (!defined $transcriptome_file) {
    if (!defined $transcriptome_dir) {
      $self->throw("A path or filename is required");
    } else {
      if (!-e $transcriptome_dir) {
        $self->warning("Output directory '$transcriptome_dir' does not exist. I shall create it.");
        make_path($transcriptome_dir) or $self->throw("Failed to create output directory '$transcriptome_dir'");
      }
      $transcriptome_file = catdir($transcriptome_dir, "$species.fa");
      $self->param('transcriptome_file', $transcriptome_file);
    }
  }
  
  if (-e $transcriptome_file) {
    if ($self->param('overwrite')) {
      $self->warning("Transcriptome file '$transcriptome_file' already exists, and will be overwritten.");
    } else {
      $self->warning("Transcriptome file '$transcriptome_file' already exists, and won't be overwritten.");
      $self->param('skip_dump', 1);
    }
  }
}

sub run {
  my ($self) = @_;
  
  return if $self->param('skip_dump');
  
  my $transcriptome_file = $self->param('transcriptome_file');
  my $header_style       = $self->param('header_style');
  my $use_dbID           = $self->param('use_dbID');
  my $chunk_factor       = $self->param('chunk_factor');
  my $line_width         = $self->param('line_width');
  
  open(my $fh, '>', $transcriptome_file) or $self->throw("Cannot open file $transcriptome_file: $!");
  my $serializer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new(
    $fh,
    undef,
    $chunk_factor,
    $line_width,
  );
  
  my $dba = $self->core_dba();
  my $tra = $dba->get_adaptor('Transcript');
  my $transcripts = $tra->fetch_all();
  
  foreach my $transcript (sort { $a->stable_id cmp $b->stable_id } @{$transcripts}) {
    my $seq_obj = $transcript->seq();
    
    if ($header_style ne 'default') {
      $seq_obj->display_id($self->header($header_style, $transcript));
    }
    
    $serializer->print_Seq($seq_obj);
	}
  
  close($fh);
}

sub write_output {
  my ($self) = @_;
  my $file_varname = $self->param_required('file_varname');
  
  $self->dataflow_output_id({$file_varname => $self->param('transcriptome_file')}, 1);
}

sub header {
  my ($self, $header_style, $transcript) = @_;
  
  my $header = $transcript->stable_id;
  
  if ($header_style eq 'dbID') {
    $header = $transcript->dbID;
    
  } elsif ($header_style eq 'extended') {
    my $gene = $transcript->get_Gene;
    my $id = $transcript->stable_id;
    my $desc = $gene->description ? $gene->description : ' ';
    $desc =~ s/\s*\[Source.+$//;
    
    my $xref = $gene->display_xref;
    if (defined $xref) {
      my $name = $xref->display_id;
      $desc = "$name: $desc";
    }
    
    my $location = join(':',
      $transcript->seq_region_name,
      $transcript->seq_region_start,
      $transcript->seq_region_end,
      $transcript->strand,
    );
    
    $header = join('|',
      "$id $desc",
      $transcript->biotype,
      $location,
      'gene:'.$gene->stable_id,
    );
    
  }
  
  return $header;
}

1;
