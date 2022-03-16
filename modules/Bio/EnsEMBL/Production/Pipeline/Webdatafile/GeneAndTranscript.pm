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

 Bio::EnsEMBL::Production::Pipeline::Webdatafile::GeneAndTranscript;

=head1 DESCRIPTION
  Compute Gene and Transcript  step for webdatafile dumps

=cut

package Bio::EnsEMBL::Production::Pipeline::Webdatafile::GeneAndTranscript;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use Path::Tiny qw(path);
use Array::Utils qw(intersect);
use Path::Tiny qw(path);
use Carp qw/croak/;
use JSON qw/decode_json/;
require  Bio::EnsEMBL::Feature;
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeLookup;
use MIME::Base64 qw/encode_base64/;
use Encode qw/encode/;
use List::MoreUtils qw(uniq);
use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::CoordinateConverter qw(to_zero_based);
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
  my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor( $self->param('species'), $self->param('group'), 'Slice' );

  my $lookup = Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeLookup->new("genome_data" => $genome_data); 
  my $genome = $lookup->get_genome('1');
  my $genome_report = $genome->get_genome_report();
  my @chrs = sort {$a cmp $b } map { $_->name() } grep { $_->is_assembled } @{$genome_report};
  $self->{transcripts_fh} = $genome->genes_transcripts_path()->child('transcripts.bed')->openw;
  $self->{canonicals} = $self->get_canonicals($genome, $dba);
  $self->{mane_selects} = $self->get_mane_selects($genome, $dba);
 
  # In-memory storage for genes, transcripts and exons during processing of a single chromosome
  $self->{gene_record} = {};
  $self->{transcript_record} = {};
  $self->{exon_record} = {};

  while(my $chr = shift @chrs) {
     $self->process_chromosome($chr, $slice_adaptor, $genome);
  }

  close $self->{transcripts_fh};

  my $transcripts_bed = $genome->genes_transcripts_path()->child('transcripts.bed');
  my $indexer = Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::IndexBed->transcript($genome);
  $indexer->index($transcripts_bed);

}

sub process_chromosome {
  my ($self, $chr, $slice_adaptor, $genome) = @_;
  my $data = $self->get_overlaps($chr, $slice_adaptor);
  $self->update_temporary_storage($data);
  $self->write_transcripts($chr, $self->{transcripts_fh}, $slice_adaptor);
  $self->clear_temporary_storage();
}


sub process_chromosome_by_chunck {

  my ($self, $chr, $slice_adaptor, $genome) = @_;
  my $slice = $slice_adaptor->fetch_by_region( $self->param('level'), $chr );
  my $start = 1;
  my $end = $slice->length; #replaced get_length function which was using restapi
  my $chunk = $genome->chunk_size();
  my $finished = 0; 
  while($finished == 0) {
    my $new_end = ($start + $chunk)-1;
    $self->warning("Processing $chr : $start -> $new_end\n");

    if($new_end >= $end) {
      $new_end = $end;
      $finished = 1;
    }

    my $data = $self->get_overlaps($chr, $start, $end, $slice_adaptor);
    $self->update_temporary_storage($data);
    $start = $new_end+1;
    $self->write_transcripts($chr,$self->{transcripts_fh});
  }

}


sub clear_temporary_storage {
  my $self = shift;
  $self->{gene_record} = {};
  $self->{transcript_record} = {};
  $self->{exon_record} = {};
}

sub update_temporary_storage {
  my ($self, $features) = @_;
  my @exons = grep { $_->{feature_type} eq 'exon' } @$features;
  my @cdss = grep { $_->{feature_type} eq 'cds' } @$features;
  
  foreach my $feature (@{$features}) {
    my $feature_id = $feature->{id};
    if ($feature->{feature_type} eq 'gene' && !defined($self->{gene_record}->{$feature_id})) {
       $self->{gene_record}->{$feature_id} = $feature;
    } elsif ($feature->{feature_type} eq 'transcript' && !defined($self->{transcript_record}->{$feature_id})) {
       $feature->{exon_ids} = [];
      # add default positions for CDS, which will be used if the transcript is non-coding
       $feature->{cds_start} = $feature->{start};
       $feature->{cds_end} = $feature->{start};
       $self->add_transcript_designation($feature);
       $self->{transcript_record}->{$feature_id} = $feature;
    } elsif ($feature->{feature_type} eq 'exon' && !defined($self->{exon_record}->{$feature_id})) {
          $self->{exon_record}->{$feature_id} = $feature;
    }

  }

  foreach my $exon (@exons) {
    my $transcript_id = $exon->{Parent};
    my $transcript = $self->{transcript_record}->{$transcript_id};
    my $transcript_exons = $transcript->{exon_ids};
    push @$transcript_exons, $exon->{id};
    $transcript_exons = [uniq(@$transcript_exons)];
    $transcript->{exons} = $transcript_exons;
    $self->{transcript_record}->{$transcript_id} = $transcript;
  }

  foreach my $cds (@cdss) {
    my $transcript_id = $cds->{Parent};
    my $transcript = $self->{transcript_record}->{$transcript_id};
    if ($transcript->{cds_start} == $transcript->{cds_end}) {
      $transcript->{cds_start} = $cds->{start};
      $transcript->{cds_end} = $cds->{end};
    } elsif ($cds->{start} < $transcript->{cds_start}) {
      $transcript->{cds_start} = $cds->{start};
    } elsif ($cds->{end} > $transcript->{cds_end}) {
      $transcript->{cds_end} = $cds->{end};
    }
  }


}# update end


sub add_transcript_designation {
  my ($self, $transcript) = @_;
  if($self->{mane_selects}->{$transcript->{id}}) {
    $transcript->{designation} = 'mane_select';
  } elsif ($self->{canonicals}->{$transcript->{id}}) {
    $transcript->{designation} = 'canonical';
  } else {
    $transcript->{designation} = '-';
  }
}

sub get_overlaps {

  #replaced rest api with perl api function "https://${rest}/overlap/region/${species}/${chr}:${start}-${end}?content-type=application/json;feature=gene;feature=transcript;feature=exon;feature=cds";
  my ($self, $chr, $slice_adaptor) = @_; 
  my $slice = $slice_adaptor->fetch_by_region( $self->param('level'), $chr );

  my @final_features;
  my @features = ('gene', 'transcript', 'cds', 'exon');
  # record when we've processed a feature type already
  my %processed_feature_types;

  foreach my $feature_type (@features) {
    next if exists $processed_feature_types{$feature_type};
    next if $feature_type eq 'none';
    my $objects = $self->$feature_type($slice);
    push(@final_features, @{$self->to_hash($objects, $feature_type)});
    $processed_feature_types{$feature_type} = 1;   
  }

  return \@final_features;

}

sub gene {
  my ($self, $slice) = @_;
  return $slice->get_all_Genes();
}

sub transcript {
  my ($self, $slice, $load_exons) = @_;
  
  my $transcripts = $slice->get_all_Transcripts();
  return $transcripts;
}

sub cds {
  my ($self, $slice, $load_exons) = @_;
  my $transcripts = $self->transcript($slice, 0);
  my @cds;
  foreach my $transcript (@$transcripts) {
    push (@cds, @{ $transcript->get_all_CDS });
  }
  return \@cds;
}

sub exon {
  my ($self, $slice) = @_;
  my $transcripts = $self->transcript($slice, 0);
  my @exons;
  foreach my $transcript (@$transcripts) {
    foreach my $exon (@{ $transcript->get_all_ExonTranscripts}) {
      if (($slice->start < $exon->seq_region_start && $exon->seq_region_start < $slice->end) || ($slice->start < $exon->seq_region_end && $exon->seq_region_end < $slice->end) ||($slice->start >= $exon->seq_region_start && $slice->end <= $exon->seq_region_end) ) {
        push (@exons, $exon);
      }
    }
  }
  return \@exons;
}

sub to_hash {
  my ($self, $features, $feature_type) = @_;
  my @hashed;
  my @KNOWN_NUMERICS = qw( start end strand version );
  foreach my $feature (@{$features}) {
    my $hash = $feature->summary_as_hash();
    foreach my $key (@KNOWN_NUMERICS) {
      my $v = $hash->{$key};
      $hash->{$key} = ($v*1) if defined $v;
    }
    if ($hash->{Name}) {
      $hash->{external_name} = $hash->{Name};
      delete $hash->{Name};
    }
    $hash->{feature_type} = $feature_type;
    push(@hashed, $hash);
  }
  return \@hashed;
}

sub Bio::EnsEMBL::Feature::summary_as_hash {
  my $self = shift;
  my %summary;
  $summary{'id'} = $self->display_id;
  $summary{'version'} = $self->version() if $self->version();
  $summary{'start'} = $self->seq_region_start;
  $summary{'end'} = $self->seq_region_end;
  $summary{'strand'} = $self->strand;
  $summary{'seq_region_name'} = $self->seq_region_name;
  $summary{'assembly_name'} = $self->slice->coord_system->version() if $self->slice();
  return \%summary;
}

sub get_canonicals {

  my ($self, $genome, $dba) = @_;
  my $canonicals_hash = {};
  my $result = $dba->dbc->sql_helper()->execute( -SQL =>
    'select t.stable_id as transcript_stable_id, t.stable_id from gene g join transcript t on (g.canonical_transcript_id = t.transcript_id) join seq_region sr on (t.seq_region_id = sr.seq_region_id) join coord_system cs on (sr.coord_system_id = cs.coord_system_id) where cs.species_id = '.$genome->species_id()
  );
  
  foreach my $row (@$result) {
    $canonicals_hash->{$row->[0]} = $row->[1];
  }

  return $canonicals_hash; 
  
}

sub get_mane_selects {

  my ($self, $genome, $dba) = @_;
  my $mane_hash = {};
  my $result = $dba->dbc->sql_helper()->execute( -SQL =>
    'select t.stable_id as transcript_stable_id, 1 from transcript t join transcript_attrib ta on (t.transcript_id = ta.transcript_id) join attrib_type at on (ta.attrib_type_id = at.attrib_type_id) join seq_region sr on (t.seq_region_id = sr.seq_region_id) join coord_system cs on (sr.coord_system_id = cs.coord_system_id) where cs.species_id =' . $genome->species_id()  .' and at.code = "MANE_Select"'  );

  foreach my $row (@$result) {
    $mane_hash->{$row->[0]} = $row->[1];
  }
  return $mane_hash;
}


sub write_transcripts {
  my ($self, $chr, $transcripts_fh, $slice_adaptor) = @_;
  foreach my $transcript_id (keys %{$self->{transcript_record}}) {
    my $transcript_line = $self->prepare_transcript_line($chr, $transcript_id, $slice_adaptor);
    print $transcripts_fh "$transcript_line\n" or die "Cannot print to transcripts.bed";
  }
}

sub prepare_transcript_line {

  my ($self, $chr, $transcript_id, $slice_adaptor) = @_;
  my $transcript = $self->{transcript_record}->{$transcript_id};
  my @exons =
    sort { $a->{start} <=> $b->{start} }
    map { $self->{exon_record}->{$_} } @{$transcript->{exons}};
  my $gene = $self->{gene_record}->{$transcript->{Parent}};

  if (!defined($gene)) {
     my $slice = $slice_adaptor->fetch_by_gene_stable_id( $transcript->{Parent} ); 
     my @gene_array = grep { $_->stable_id() eq $transcript->{Parent} } @{ $slice->get_all_Genes() };

     @gene_array =  @{$self->to_hash(\@gene_array, 'gene')};   
     if (scalar @gene_array){
        $gene = $gene_array[0]; 
     } else{
       $self->warning('gene not found......');
     }
  }

  my $transcript_start = $transcript->{start};
  my $transcript_end = $transcript->{end};
  my $versioned_transcript_id = $self->get_versioned_feature_id($transcript);
  my $strand = $transcript->{strand} > 0 ? '+' : '-';
  my $cds_start = $transcript->{cds_start};
  my $cds_end = $transcript->{cds_end};
  my $exons_count = scalar @exons;
  my @exon_lengths = map { $_->{end} - $_->{start} } @exons;
  my $exon_lengths = join(',', @exon_lengths) . ',';
  my @exon_starts = map { $_->{start} - $transcript_start } @exons;
  my $exon_starts = join(',', @exon_starts) . ',';
  my $versioned_gene_id = $self->get_versioned_feature_id($gene);
  my $gene_name = $self->get_gene_name($gene);
  my $gene_start = $gene->{start};
  my $gene_end = $gene->{end};
  my $gene_biotype = $gene->{biotype};
  my $transcript_biotype = $transcript->{biotype};
  my $transcript_designation = $transcript->{designation};
  my $gene_description = $self->get_gene_description($gene);

  my $line = join "\t", (
    $chr,
    to_zero_based($gene_start),
    $gene_end, # end position is not adjusted for beds
    $versioned_transcript_id,
    $strand,
    to_zero_based($cds_start),
    $cds_end == $cds_start ? to_zero_based($cds_start) : $cds_end, # lack of coding sequence in a transcript is indicated by setting the end position as equal to start position (which is equal to transcript start)
    $exons_count, # required during indexing with bedToBigBed (tells bedToBigBed how long exon_lengths and exon_starts arrays are)
    $exon_lengths,
    $exon_starts, # relative to transcript start position
    to_zero_based($transcript_start),
    $transcript_end, # end position is not adjusted for beds
    $transcript_biotype,
    $transcript_designation,
    $versioned_gene_id,
    $gene_name,
    $gene_description,
    $gene_biotype
  );

  return $line;


} #prepare end

sub get_gene_description {
  my ($self, $gene) = @_;
  my $description = $gene->{description} || '-';

  if($description =~ /\s+\[.+\]$/) {
    $description =~ s/\s+\[.+\]$//;
  }
  return encode_base64(encode('UTF-8', $description), q{});
}

sub get_versioned_feature_id {
  my ($self, $feature) = @_;
  return defined($feature->{version})
    ? "$feature->{id}" . "$feature->{version}"
    : $feature->{id};
}


sub get_gene_name {
  my ($sel, $gene) = @_;
  my $gene_name = $gene->{external_name} || $gene->{display_name} || $gene->{id};
  $gene_name =~ s/\s+//g; # remove potential whitespace from gene name to avoid confusing bigbed parser
  return $gene_name;
}

1;
