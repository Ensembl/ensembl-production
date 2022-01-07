=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::Webdatafile::Contigs;

=head1 DESCRIPTION
  Compute Contigs for webdatafile dumps

=cut

package Bio::EnsEMBL::Production::Pipeline::Webdatafile::Contigs;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use Path::Tiny qw(path);
use Carp qw/croak/;
use JSON qw/decode_json/;
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeLookup;
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::IndexBed;

sub run {

  my ($self) = @_;
  my $species = $self->param('species');
  my $current_step = $self->param('current_step') ;
  my $output = $self->param('output_path');
  my $app_path = $self->param('app_path'); 
  my $genome_data = {
    dbname     => $self->param('dbname'),
    gca        => $self->param('gca'),
    genome_id  => $self->param('genome_id'),
    species    => $self->param('species'),
    version    => $self->param('version'),
    type       => $self->param('type'),  
    root_path  => path($self->param('root_path'))
  };
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $self->param('species'), $self->param('group') );
  my $lookup = Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeLookup->new("genome_data" => $genome_data); 
   my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor( $self->param('species'), $self->param('group'), 'Slice' );
  my $genome = $lookup->get_genome('1');
  my $genome_report = $genome->get_genome_report();
  my $version = $genome->version();
  my $flip_strands = 1;
  my @chrs = sort {$a->name() cmp $b->name() } grep { $_->is_assembled } @{$genome_report};
  my $base = $genome->contigs_path();
  $base->mkpath();
  my $fh = $base->child('contigs.bed')->openw; 
  while(my $chr = shift @chrs) {
     $self->process_chromosome($chr, $slice_adaptor, $genome, $fh);
  }

  close $fh;
}

sub process_chromosome {

  my ($self, $chr, $slice_adaptor, $genome, $fh) = @_;
  my $chr_name = $chr->name();
  my $chr_length = $chr->length();
  my $mappings = $self->map_data($chr, $slice_adaptor, $genome);
  my $count = 0;

  foreach my $mapping (@{$mappings}) {
      my $start = $mapping->{original}->{start};
      $start--; # get into BED coords
      my $end = $mapping->{original}->{end};
      next if $start > $chr_length || $end > $chr_length; # a temporary way to solve mappings of PAR regions on human Y-chromosome reporting coordinates from X-chromosome

      my $score = 0;
      my $name = $mapping->{mapped}->{seq_region_name};
      my $strand = (($count % 2) == 0) ? '+' : '-'; # we are abusing the strand field to mark adjacent contigs (so that they are colour-coded differently)
      my $new_line = join("\t", ($chr_name, $start, $end, $name, $score, $strand));
      print $fh "${new_line}\n" or die "Cannot print to contigs.bed";
      $count++;
    }


}


sub map_data {

  my ($self, $chr, $slice_adaptor, $genome) = @_;

  my $slice = $slice_adaptor->fetch_by_region($self->param('level'), $chr->name(), undef, undef, undef, $self->param('assembly_default'));

  my $old_cs_name = $slice->coord_system_name();
  my $old_sr_name = $slice->seq_region_name();
  my $old_start   = $slice->start();
  my $old_end     = $slice->end();
  my $old_strand  = $slice->strand()*1;
  my $old_version = $slice->coord_system()->version();

  my @decoded_segments;
  my $projection;
  
  eval { $projection = $slice->project('contig') };

  return \@decoded_segments if $@;

    foreach my $segment ( @{$projection} ) {
      my $mapped_slice = $segment->to_Slice;
      my $mapped_data = {
        original => {
          coord_system => $old_cs_name,
          assembly => $old_version,
          seq_region_name => $old_sr_name,
          start => ($old_start + $segment->from_start() - 1) * 1,
          end => ($old_start + $segment->from_end() - 1) * 1,
          strand => $old_strand,
        },
        mapped => {
          coord_system => $mapped_slice->coord_system->name,
          assembly => $mapped_slice->coord_system->version,
          seq_region_name => $mapped_slice->seq_region_name(),
          start => $mapped_slice->start() * 1,
          end => $mapped_slice->end() * 1,
          strand => $mapped_slice->strand(),
        },
      };
      push(@decoded_segments, $mapped_data);
    }

    return \@decoded_segments;
}

1;
