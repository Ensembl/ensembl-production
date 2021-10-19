=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3;

use strict;
use warnings;
no  warnings 'redefine';
use base qw(Bio::EnsEMBL::Production::Pipeline::FileDump::Base_Filetype);

use Bio::EnsEMBL::Exon;
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Transcript;
use Bio::EnsEMBL::CDS;
use Bio::EnsEMBL::Utils::IO::GFFSerializer;
use Path::Tiny;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    data_type            => 'genes',
    file_type            => 'gff3',
    per_chromosome       => 0,
    feature_types        => ['Gene', 'Transcript'],
    include_utr          => 1,
    header               => 1,
    gt_gff3_exe          => 'gt gff3',
    gt_gff3validator_exe => 'gt gff3validator',
  };
}

sub run {
  my ($self) = @_;

  my $data_type      = $self->param_required('data_type');
  my $per_chromosome = $self->param_required('per_chromosome');
  my $feature_types  = $self->param_required('feature_types');
  my $header         = $self->param_required('header');
  my $filenames      = $self->param_required('filenames');

  my $dba = $self->dba;

  my %adaptors;
  foreach my $feature_type (@$feature_types) {
    $adaptors{$feature_type} = $dba->get_adaptor($feature_type);
  }

  my $mca = $dba->get_adaptor('MetaContainer');
  my $providers = $mca->list_value_by_key('assembly_provider.name') || ();
  my $provider = join("; ", @$providers);

  my ($chr, $non_chr, $non_ref) = $self->get_slices($dba);

  my $filename = $$filenames{$data_type};

  if ($per_chromosome && scalar(@$chr)) {
    $self->print_to_file($chr, 'chr', $filename, '>', $header, $dba, \%adaptors, $provider);
    if (scalar(@$non_chr)) {
      $self->print_to_file($non_chr, 'non_chr', $filename, '>>', $header, $dba, \%adaptors, $provider);
    }
  } else {
    $self->print_to_file([@$chr, @$non_chr], undef, $filename, '>', $header, $dba, \%adaptors, $provider);
  }

  if (scalar(@$non_ref)) {
    my $non_ref_filename = $self->generate_non_ref_filename($filename);
    path($filename)->copy($non_ref_filename);
    $self->print_to_file($non_ref, undef, $non_ref_filename, '>>', $header, $dba, \%adaptors, $provider);
  }

  my $output_filenames = $self->param('output_filenames');
  foreach (@$output_filenames) {
    $self->tidy($_);
    $self->validate($_);
  }
}

sub print_to_file {
  my ($self, $slices, $region, $filename, $mode, $header, $dba, $adaptors, $provider) = @_;

  $header = $mode eq '>' ? 1 : 0 unless defined $header;
  my $serializer = $self->gff3_serializer($filename, $mode, $header, $slices, $dba);

  my $non_chr_serializer;
  if ($region && $region eq 'non_chr') {
    my $non_chr_filename = $self->generate_non_chr_filename($filename);
    $non_chr_serializer = $self->gff3_serializer($non_chr_filename, $mode, 1, $slices, $dba);
  }

  while (my $slice = shift @{$slices}) {
    my $chr_serializer;
    if ($region && $region eq 'chr') {
      my $chr_filename = $self->generate_chr_filename($filename, $slice);
      $chr_serializer = $self->gff3_serializer($chr_filename, $mode, 1, $slices, $dba);
    }

    $slice->source($provider) if defined $provider;
    $serializer->print_feature($slice);
    if ($region && $region eq 'chr') {
      $chr_serializer->print_feature($slice);
    } elsif ($region && $region eq 'non_chr') {
      $non_chr_serializer->print_feature($slice);
    }

    foreach my $feature_type (keys %$adaptors) {
      my $features = $self->fetch_features($feature_type, $$adaptors{$feature_type}, $slice);
      $serializer->print_feature_list($features);
      if ($region && $region eq 'chr') {
        $chr_serializer->print_feature_list($features);
      } elsif ($region && $region eq 'non_chr') {
        $non_chr_serializer->print_feature_list($features);
      }
    }
  }
}

sub gff3_serializer {
  my ($self, $filename, $mode, $header, $slices, $dba) = @_;

  my $fh = path($filename)->filehandle($mode);
  my $serializer = Bio::EnsEMBL::Utils::IO::GFFSerializer->new($fh);
  if ($header) {
    $serializer->print_main_header($slices, $dba);
  }

  return $serializer;
}

sub fetch_features {
  my ($self, $feature_type, $adaptor, $slice) = @_;

  my @features = @{$adaptor->fetch_all_by_Slice($slice)};
  $adaptor->clear_cache();
  if ($feature_type eq 'Transcript') {
    my $exon_features = $self->exon_features(\@features);
    push @features, @$exon_features;
  }

  return \@features;
}

sub exon_features {
  my ($self, $transcripts) = @_;
  my $include_utr = $self->param_required('include_utr');

  my @cds_features;
  my @exon_features;
  my @utr_features;

  foreach my $transcript (@$transcripts) {
    push @cds_features, @{ $transcript->get_all_CDS(); };
    push @exon_features, @{ $transcript->get_all_ExonTranscripts() };
    if ($include_utr) {
      push @utr_features, @{ $transcript->get_all_five_prime_UTRs()};
      push @utr_features, @{ $transcript->get_all_three_prime_UTRs()};
    }
  }

  return [@exon_features, @cds_features, @utr_features];
}

sub tidy {
  my ($self, $filename) = @_;
  my $gt_gff3_exe = $self->param_required('gt_gff3_exe');

  $self->assert_executable($gt_gff3_exe);

  my $temp_filename = "$filename.sorted";

  my $cmd = "$gt_gff3_exe -tidy -sort -retainids -fixregionboundaries -force -o $temp_filename $filename";
  my ($rc, $output) = $self->run_cmd($cmd);

  if ($rc) {
    my $msg =
      "GFF3 tidying failed for '$filename'\n".
      "Output: $output";
    unlink $temp_filename;
    $self->throw($msg);
  } else {
    path($temp_filename)->move($filename);
  }
}

sub validate {
  my ($self, $filename) = @_;
  my $gt_gff3validator_exe = $self->param_required('gt_gff3validator_exe');

  $self->assert_executable($gt_gff3validator_exe);

  my $cmd = "$gt_gff3validator_exe $filename";
  my ($rc, $output) = $self->run_cmd($cmd);

  if ($rc) {
    my $msg =
      "GFF3 file '$filename' failed validation with $gt_gff3validator_exe\n".
      "Output: $output";
    $self->throw($msg);
  }
}

# The serializer will put everything from 'summary_as_hash' into
# the GFF3 attributes. But we don't want everything, so redefine
# here, to explicitly specify our attributes.

sub Bio::EnsEMBL::Gene::summary_as_hash {
  my $self = shift;
  my %summary;

  $summary{'seq_region_name'} = $self->seq_region_name;
  $summary{'source'}          = $self->source;
  $summary{'start'}           = $self->seq_region_start;
  $summary{'end'}             = $self->seq_region_end;
  $summary{'strand'}          = $self->strand;
  $summary{'id'}              = $self->display_id;
  $summary{'gene_id'}         = $self->display_id;
  $summary{'version'}         = $self->version;
  $summary{'Name'}            = $self->external_name;
  $summary{'biotype'}         = $self->biotype;
  $summary{'description'}     = $self->description;
  
  return \%summary;
}

sub Bio::EnsEMBL::Transcript::summary_as_hash {
  my $self = shift;
  my %summary;

  my $parent_gene = $self->get_Gene();

  $summary{'seq_region_name'}          = $self->seq_region_name;
  $summary{'source'}                   = $self->source;
  $summary{'start'}                    = $self->seq_region_start;
  $summary{'end'}                      = $self->seq_region_end;
  $summary{'strand'}                   = $self->strand;
  $summary{'id'}                       = $self->display_id;
  $summary{'Parent'}                   = $parent_gene->stable_id;
  $summary{'transcript_id'}            = $self->display_id;
  $summary{'version'}                  = $self->version;
  $summary{'Name'}                     = $self->external_name;
  $summary{'biotype'}                  = $self->biotype;
  my $havana_transcript = $self->havana_transcript();
  $summary{'havana_transcript'}        = $havana_transcript->display_id() if $havana_transcript;
  $summary{'havana_version'}           = $havana_transcript->version() if $havana_transcript;
  $summary{'ccdsid'}                   = $self->ccds->display_id if $self->ccds;
  $summary{'transcript_support_level'} = $self->tsl if $self->tsl;
  $summary{'tag'}                      = 'basic' if $self->gencode_basic();

  # Check for seq-edits
  my $seq_edits = $self->get_all_SeqEdits();
  my @seq_edits;
  foreach my $seq_edit (@$seq_edits) {
    my ($start, $end, $alt_seq) =
      ($seq_edit->start, $seq_edit->end, $seq_edit->alt_seq);

    my $note = "This transcript's sequence has been ";
    if ($alt_seq eq '') {
      $note .= "annotated with a deletion between positions $start and $end";
    } elsif ($end < $start) {
      $note .= "annotated with an insertion before position $start: $alt_seq";
    } else {
      $note .= "replaced between positions $start and $end: $alt_seq";
    }

    push @seq_edits, $note;
  }
  $summary{'Note'} = \@seq_edits if scalar(@seq_edits);

  return \%summary;
}

sub Bio::EnsEMBL::Exon::summary_as_hash {
  my $self = shift;
  my %summary;

  $summary{'seq_region_name'} = $self->seq_region_name;
  $summary{'start'}           = $self->seq_region_start;
  $summary{'end'}             = $self->seq_region_end;
  $summary{'strand'}          = $self->strand;
  $summary{'exon_id'}         = $self->display_id;
  $summary{'version'}         = $self->version;
  $summary{'constitutive'}    = $self->is_constitutive;

  return \%summary;
}

sub Bio::EnsEMBL::CDS::summary_as_hash {
  my $self = shift;
  my %summary;

  $summary{'seq_region_name'} = $self->seq_region_name;
  $summary{'source'}          = $self->transcript->source;
  $summary{'start'}           = $self->seq_region_start;
  $summary{'end'}             = $self->seq_region_end;
  $summary{'strand'}          = $self->strand;
  $summary{'phase'}           = $self->phase;
  $summary{'id'}              = $self->translation_id;
  $summary{'Parent'}          = $self->transcript->display_id;
  $summary{'protein_id'}      = $self->translation_id;
  $summary{'version'}         = $self->transcript->translation->version;

  return \%summary;
}

1;
