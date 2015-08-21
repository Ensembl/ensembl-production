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

use Bio::EnsEMBL::Utils::IO::FASTASerializer;

use File::Path qw(make_path);
use File::Spec::Functions qw(catdir);

sub param_defaults {
  my ($self) = @_;
  
  return {
    'overwrite'        => 0,
    'header_style'     => 'default',
    'chunk_factor'     => 1000,
    'line_width'       => 80,
    'dump_level'       => 'toplevel',
    'min_slice_length' => 0,
    'repeat_masking'   => 'soft',
    'repeat_libs'      => [],
  };
}

sub fetch_input {
  my ($self) = @_;
  
  my $genome_file = $self->param('genome_file');
  my $genome_dir  = $self->param('genome_dir');
  my $species     = $self->param('species');
  
  if (!defined $genome_file) {
    if (!defined $genome_dir) {
      $self->throw("A path or filename is required");
    } else {
      if (!-e $genome_dir) {
        $self->warning("Output directory '$genome_dir' does not exist. I shall create it.");
        make_path($genome_dir) or $self->throw("Failed to create output directory '$genome_dir'");
      }
      $genome_file = catdir($genome_dir, "$species.fa");
      $self->param('genome_file', $genome_file);
    }
  }
  
  if (-e $genome_file) {
    if ($self->param('overwrite')) {
      $self->warning("Genome file '$genome_file' already exists, and will be overwritten.");
    } else {
      $self->warning("Genome file '$genome_file' already exists, and won't be overwritten.");
      $self->param('skip_dump', 1);
    }
  }
}

sub run {
  my ($self) = @_;
  
  return if $self->param('skip_dump');
  
  my $genome_file      = $self->param('genome_file');
  my $header_style     = $self->param('header_style');
  my $chunk_factor     = $self->param('chunk_factor');
  my $line_width       = $self->param('line_width');
  my $dump_level       = $self->param('dump_level');
  my $min_slice_length = $self->param('min_slice_length');
  my $repeat_masking   = $self->param('repeat_masking');
  my $repeat_libs      = $self->param('repeat_libs');
  
  if ($repeat_masking =~ /soft|hard/i) {
    if (! defined $repeat_libs || scalar(@$repeat_libs) == 0) {
      $repeat_libs = $self->core_dba->get_MetaContainer->list_value_by_key('repeat.analysis');
      $self->param('repeat_libs', $repeat_libs);
    }
  }
  
  my $header_function = $self->header_function($header_style);
      
  open(my $fh, '>', $genome_file) or $self->throw("Cannot open file $genome_file: $!");
  my $serializer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new(
    $fh,
    $header_function,
    $chunk_factor,
    $line_width,
  );
  
  my $dba = $self->core_dba();
  my $sa = $dba->get_adaptor('Slice');
  my $slices = $sa->fetch_all($dump_level);
  
	foreach my $slice (sort { $b->length <=> $a->length } @$slices) {
    if ($slice->length() < $min_slice_length) {
      last;
    }
    
    if ($repeat_masking =~ /soft|hard/i) {
      my $soft_mask = ($repeat_masking =~ /soft/i);
      $slice = $slice->get_repeatmasked_seq($repeat_libs, $soft_mask);
    }
    
    $serializer->print_Seq($slice);
	}
  
  close($fh);
}

sub write_output {
  my ($self) = @_;
  
  $self->dataflow_output_id({'genome_file' => $self->param('genome_file')}, 1);
}

sub header_function {
  my ($self, $header_style, $slice) = @_;
  
  my $header_function;
  
  if ($header_style eq 'name') {
    $header_function = 
      sub {
        my $slice = shift;
        return $slice->seq_region_name;
      };
    
  } elsif ($header_style eq 'name_and_location') {
    $header_function = 
      sub {
        my $slice = shift;
        return $slice->seq_region_name.' '.$slice->name;
      };
    
  } elsif ($header_style eq 'name_and_type_and_location') {
    $header_function = 
      sub {
        my $slice = shift;
        return $slice->seq_region_name.' dna:'.$slice->coord_system_name.' '.$slice->name;
      };
    
  }
  
  return $header_function;
}

1;
