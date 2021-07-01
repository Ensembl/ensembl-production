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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3_ENA;

use strict;
use warnings;
no  warnings 'redefine';
use base qw(Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3);

# Using Ensembl code to add a GFF3 header causes problems because it
# defaults to using the seq_region names, not INSDC synonyms, and it's
# hard to override this. Instead, don't write a header, and rely on
# the gt tidying to add in the appropriate details.

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    data_type => 'genes_ena',
    header    => 0,
  };
}

# The serializer will put everything from 'summary_as_hash' into
# the GFF3 attributes. But we want a highly customised set of
# attributes for ENA, so explicitly specify them for all features.

sub Bio::EnsEMBL::Slice::summary_as_hash {
  my $self = shift;
  my %summary;

  my $seq_region_name =
    Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3_ENA::insdc_name($self);

  $summary{'seq_region_name'} = $seq_region_name;
  $summary{'source'}          = $self->source || $self->coord_system->version;
  $summary{'start'}           = $self->start;
  $summary{'end'}             = $self->end;
  $summary{'strand'}          = 0;
  $summary{'id'}              = $seq_region_name;
  $summary{'Is_circular'}     = $self->is_circular ? "true" : undef;

  if ($self->is_chromosome) {
    # Rely on the Ensembl convention which uses chromosome as seq_region name.
    $summary{'chromosome'} = $self->seq_region_name;
  }

  my $codon_table = $self->get_all_Attributes("codon_table");
  if (@{$codon_table}) {
    # Could set this to 1 by default, but seems sensible to have the
    # assumption that it is standard unless defined otherwise.
    $summary{'transl_table'} = $codon_table->[0]->value;
  }

  return \%summary;
}

sub Bio::EnsEMBL::Gene::summary_as_hash {
  my $self = shift;
  my %summary;

  my $seq_region_name =
    Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3_ENA::insdc_name($self);

  $summary{'seq_region_name'} = $seq_region_name;
  $summary{'source'}          = $self->source;
  $summary{'start'}           = $self->seq_region_start;
  $summary{'end'}             = $self->seq_region_end;
  $summary{'strand'}          = $self->strand;
  $summary{'id'}              = $self->stable_id;
  $summary{'Name'}            = $self->stable_id_version;
  $summary{'gene_id'}         = $self->stable_id_version;
  $summary{'gene_biotype'}    = $self->biotype;
  
  return \%summary;
}

sub Bio::EnsEMBL::Transcript::summary_as_hash {
  my $self = shift;
  my %summary;

  my $parent_gene = $self->get_Gene();
  my $seq_region_name =
    Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3_ENA::insdc_name($self);

  $summary{'seq_region_name'} = $seq_region_name;
  $summary{'source'}          = $self->source;
  $summary{'start'}           = $self->seq_region_start;
  $summary{'end'}             = $self->seq_region_end;
  $summary{'strand'}          = $self->strand;
  $summary{'id'}              = $self->stable_id;
  $summary{'Name'}            = $self->stable_id_version;
  $summary{'Parent'}          = $parent_gene->stable_id;
  $summary{'transcript_id'}   = $self->stable_id_version;
  $summary{'biotype'}         = $self->biotype;

  my $seq_edits = 
    Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3_ENA::transcript_seq_edits($self);

  if (defined $seq_edits) {
    # Terminology for 'exception' taken from NCBI:
    # https://www.ncbi.nlm.nih.gov/datasets/docs/reference-docs/file-formats/about-ncbi-gff3/
    $summary{'exception'} = "unclassified transcription discrepancy";
    $summary{'Note'} = "transcript-level exceptions: ".join(',', @$seq_edits);
  }

  return \%summary;
}

sub Bio::EnsEMBL::ExonTranscript::summary_as_hash {
  my $self = shift;
  my %summary;

  my $seq_region_name =
    Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3_ENA::insdc_name($self);

  $summary{'seq_region_name'} = $seq_region_name;
  $summary{'source'}          = $self->transcript->source;
  $summary{'start'}           = $self->seq_region_start;
  $summary{'end'}             = $self->seq_region_end;
  $summary{'strand'}          = $self->strand;
  $summary{'id'}              = $self->stable_id_version;
  $summary{'Name'}            = $self->stable_id_version;
  $summary{'Parent'}          = $self->transcript->stable_id;
  $summary{'exon_id'}         = $self->stable_id_version;
  # Instead of 'rank' use 'exon_number', to match NCBI spec.
  $summary{'exon_number'}     = $self->rank;

  return \%summary;
}

sub Bio::EnsEMBL::CDS::summary_as_hash {
  my $self = shift;
  my %summary;

  my $seq_region_name =
    Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3_ENA::insdc_name($self);

  $summary{'seq_region_name'} = $seq_region_name;
  $summary{'source'}          = $self->transcript->source;
  $summary{'start'}           = $self->seq_region_start;
  $summary{'end'}             = $self->seq_region_end;
  $summary{'strand'}          = $self->strand;
  $summary{'phase'}           = $self->phase;
  $summary{'id'}              = $self->translation_id;
  $summary{'Name'}            = $self->transcript->translation->stable_id_version;
  $summary{'Parent'}          = $self->transcript->stable_id;
  $summary{'protein_id'}      = $self->transcript->translation->stable_id_version;

  my ($ena_seq_edits, $ncbi_seq_edits) = 
    Bio::EnsEMBL::Production::Pipeline::FileDump::Geneset_GFF3_ENA::translation_seq_edits($self->transcript->translation);

  if (defined $ena_seq_edits) {
    # Terminology for 'exception' taken from NCBI:
    # https://www.ncbi.nlm.nih.gov/datasets/docs/reference-docs/file-formats/about-ncbi-gff3/
    $summary{'exception'} = "unclassified translation discrepancy";
    $summary{'transl_except'} = join(',', @$ena_seq_edits);
    $summary{'Note'} = "NCBI-format exceptions: ".join(',', @$ncbi_seq_edits);
  }

  return \%summary;
}

sub insdc_name {
  my $obj = shift;

  my $seq_region_name;
  my $synonyms = $obj->slice->get_all_synonyms('INSDC');
  if (@$synonyms) {
    foreach (@$synonyms) {
      if ($_->name =~ /^[A-Z0-9]+\.\d+$/) {
        $seq_region_name = $_->name;
        last;
      }
    }
    if (! defined $seq_region_name) {
      die 'No INSDC accession for '.$obj->seq_region_name;
    }
  } else {
    $seq_region_name = $obj->seq_region_name;
    if ($seq_region_name !~ /^[A-Z0-9]+\.\d+$/) {
      die 'No INSDC accession for '.$obj->seq_region_name;
    }
  }

  return $seq_region_name;
}

sub transcript_seq_edits {
  my $transcript = shift;

  # ENA have not requested transcript-level sequence edits,
  # and these should probably not occur with new genesets.
  # But doesn't hurt to put the details in.
  my $seq_edits = $transcript->get_all_SeqEdits();
  return unless scalar @$seq_edits;

  my $mrna = $transcript->spliced_seq();

  my @seq_edits;

  foreach (sort { $a->start <=> $b->start } @$seq_edits) {
    my ($start, $end, $in) = ($_->start, $_->end, $_->alt_seq);
    my $del = '';
    if ($in eq '' || $end < $start) {
      $del = substr($mrna, $start - 1, $end - $start + 1);
    }

    my @genomic_coords = $transcript->cdna2genomic($start, $end);

    my ($seq_edit);

    if (scalar(@genomic_coords) == 0) {
      die "Could not map seq_edit for ".$transcript->stable_id;
    } elsif (scalar(@genomic_coords) == 1) {
      my $coord_start = $genomic_coords[0]->start;
      my $coord_end = $genomic_coords[0]->end;
      if ($coord_start == $coord_end) {
        $seq_edit = "${coord_start}|$del>$in";
      } elsif ($transcript->strand == 1) {
        $seq_edit = "${coord_start}-${coord_end}|$del>$in";
      } else {
        $seq_edit = "${coord_end}-${coord_start}|$del>$in";
      }
    } else {
      my @coords;
      foreach my $coord (@genomic_coords) {
        my $coord_start = $coord->start;
        my $coord_end = $coord->end;
        if ($coord_start == $coord_end) {
          push @coords, $coord_start;
        } else {
          if ($transcript->strand == 1) {
            push @coords, "${coord_start}-${coord_end}";
          } else {
            push @coords, "${coord_end}-${coord_start}";
          }
        }
      }
      $seq_edit = join(',', @coords)."|$del>$in";
    }

    push @seq_edits, $seq_edit;
  }

  return \@seq_edits;
}

sub translation_seq_edits {
  my $translation = shift;

  my $seq_edits = $translation->get_all_SeqEdits();
  return unless scalar @$seq_edits;

  $translation->transcript->edits_enabled(0);
  my $aa = $translation->seq();

  # ENA have requested a format that deviates from the NCBI spec;
  # but it seems like having the latter format might be useful
  # too, and it's virtually no extra effort to do so.
  my @ena_seq_edits;
  my @ncbi_seq_edits;

  foreach (sort { $a->start <=> $b->start } @$seq_edits) {
    my ($start, $end, $in) = ($_->start, $_->end, $_->alt_seq);
    my $del = '';
    if ($in eq '' || $end <= $start) {
      $del = substr($aa, $start - 1, $end - $start + 1);
    }

    my @genomic_coords = $translation->transcript->pep2genomic($start, $end);

    my ($ena_seq_edit, $ncbi_seq_edit);

    if (scalar(@genomic_coords) == 0) {
      die "Could not map seq_edit for ".$translation->stable_id;
    } elsif (scalar(@genomic_coords) == 1) {
      my $coord_start = $genomic_coords[0]->start;
      my $coord_end = $genomic_coords[0]->end;
      if ($translation->transcript->strand == 1) {
        $ena_seq_edit = "${coord_start}-${coord_end}|$del>$in";
        $ncbi_seq_edit = "pos:${coord_start}..${coord_end},aa:$in";
      } else {
        $ena_seq_edit = "${coord_end}-${coord_start}|$del>$in";
        $ncbi_seq_edit = "pos:${coord_end}..${coord_start},aa:$in";
      }
    } else {
      my @ena_coords;
      my @ncbi_coords;
      foreach my $coord (@genomic_coords) {
        my $coord_start = $coord->start;
        my $coord_end = $coord->end;
        if ($coord_start == $coord_end) {
          push @ena_coords, $coord_start;
          push @ncbi_coords, $coord_start;
        } else {
          if ($translation->transcript->strand == 1) {
            push @ena_coords, "${coord_start}-${coord_end}";
            push @ncbi_coords, "${coord_start}..${coord_end}";
          } else {
            push @ena_coords, "${coord_end}-${coord_start}";
            push @ncbi_coords, "${coord_end}..${coord_start}";
          }
        }
      }
      $ena_seq_edit = join(',', @ena_coords)."|$del>$in";
      $ncbi_seq_edit = "pos:join(".join(',', @ncbi_coords)."),aa:$in";
    }

    push @ena_seq_edits, $ena_seq_edit;
    push @ncbi_seq_edits, $ncbi_seq_edit;
  }

  return(\@ena_seq_edits, \@ncbi_seq_edits);
}

1;
