=head1 LICENSE

Copyright [1999-2015] EMBL-European Bioinformatics Institute
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

package Bio::EnsEMBL::EGPipeline::ProteinFeatures::MergeResults;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base');

use File::Basename;
use File::Spec::Functions qw(catdir);
use Path::Tiny qw(path);

sub run {
  my ($self) = @_;
  my $results_dir    = $self->param_required('results_dir');
  my $fasta_file     = $self->param_required('fasta_file');
  my $outfile_xml    = $self->param_required('outfile_xml');
  my $outfile_tsv    = $self->param_required('outfile_tsv');
  
  my $basename = fileparse($fasta_file);
  my $xml_file  = catdir($results_dir, "$basename.xml");
  my $tsv_file  = catdir($results_dir, "$basename.tsv");
  
  $self->merge_xml($xml_file, $outfile_xml);
  $self->merge_tsv($tsv_file, $outfile_tsv);
  
  $self->param('xml_file', $xml_file);
  $self->param('tsv_file', $tsv_file);
}

sub write_output {
  my ($self) = @_;
  
  my $output_ids =
  {
    'xml_file' => $self->param('xml_file'),
    'tsv_file' => $self->param('tsv_file'),
  };
  $self->dataflow_output_id($output_ids, 1);
}

sub merge_xml {
  my ($self, $file, $files) = @_;
  
  my $file_obj = path($file);
  
  my $first_file = $$files[0];
  my $first_file_obj = path($first_file);
  my $data = $first_file_obj->slurp;
  my ($header, $footer) = $data =~ /\A([^\n]+\n[^\n]+\n).*\n([^\n]+\n*)\Z/ms;
  
  $file_obj->spew($header);
  foreach my $subfile (sort @$files) {
    my $subfile_obj = path($subfile);
    my $data = $subfile_obj->slurp;
    $data =~ s/\A[^\n]+\n[^\n]+\n(.*\n)[^\n]+\n*\Z/$1/ms;
    
    $file_obj->append($data);
  }
  $file_obj->append($footer);
}

sub merge_tsv {
  my ($self, $file, $files) = @_;
  
  my $file_obj = path($file);
  $file_obj->remove;
  
  foreach my $subfile (sort @$files) {
    my $subfile_obj = path($subfile);
    my $data = $subfile_obj->slurp;
    
    my @data = split(/\n/, $data);
    $data = $self->filter(\@data);
    
    $file_obj->append($data);
  }
}

sub filter {
  my ($self, $data) = @_;
  
  my %stats = $self->statistics($data);
  my %keep;
  
  foreach my $parent_id (keys %stats) {
    my @id_list = keys %{$stats{$parent_id}};
    my @most_coverage = $self->metric($stats{$parent_id}, \@id_list, 'coverage');
    
    if (scalar(@most_coverage) == 1) {
      $keep{$most_coverage[0]} = 1;
      
    } elsif (scalar(@most_coverage) > 1) {      
      my @longest = $self->metric($stats{$parent_id}, \@most_coverage, 'length');
      
      if (scalar(@longest) == 1) {
        $keep{$longest[0]} = 1;
        
      } elsif (scalar(@longest) > 1) {
        my @most_domains = $self->metric($stats{$parent_id}, \@longest, 'domains');
        
        if (scalar(@most_domains) > 1) {
          $self->warning(
            "Two or more ORFs have identical coverage, length, and domain count; ".
            "only one will be (arbitrarily) chosen.\n".
            join(", ", @longest)
          );
        }
        $keep{$most_domains[0]} = 1;
        
      }
    }
  }
  
  my @filtered;
  foreach my $row (@$data) {
    my ($id) = $row =~ /^([^\t]+)/;
    $row =~ s/^([^\t]+)_\d+/$1/;
    
    if (exists $keep{$id}) {
      push @filtered, $row;
    }
  }
  
  my $filtered = join("\n", @filtered)."\n";
  
  return $filtered;
}

sub statistics {
  my ($self, $data) = @_;
  
  my %stats;
  
  foreach my $row (@$data) {
    my @row = split(/\t/, $row);
    my $id = $row[0];
    (my $parent_id = $id) =~ s/_\d+$//;
    
    $stats{$parent_id}{$id}{'domains'}++;
    
    if (!exists $stats{$parent_id}{$id}{'length'}) {
      $stats{$parent_id}{$id}{'length'} = $row[2];
    }
    
    if (!exists $stats{$parent_id}{$id}{'cov'}) {
      $stats{$parent_id}{$id}{'cov'} = ' ' x $row[2];
    }
    
    my $offset = $row[6] - 1;
    my $length = $row[7] - $offset;
    substr($stats{$parent_id}{$id}{'cov'}, $offset, $length) = 'x' x $length;
  }
  
  my %coverage;
  foreach my $parent_id (keys %stats) {
    foreach my $id (keys %{$stats{$parent_id}}) {
      $stats{$parent_id}{$id}{'coverage'} = () = $stats{$parent_id}{$id}{'cov'} =~ /x/g;
    }
  }
  
  return %stats;
}

sub metric {
  my ($self, $parent_id_stats, $id_list, $stat) = @_;
  
  my @best;
  my $best = 0;
  
  foreach my $id (sort @$id_list) {
    my $metric = $$parent_id_stats{$id}{$stat};
    if ($metric > $best) {
      @best = ($id);
      $best = $metric;
    } elsif ($metric == $best) {
      push @best, $id;
    }
  }
  
  return @best;
}

1;
