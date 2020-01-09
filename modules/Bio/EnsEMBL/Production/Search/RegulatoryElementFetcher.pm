=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

  Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher 

=head1 SYNOPSIS

my $fetcher = Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher->new();
my $genome = $fetcher->fetch_regulatory_elements($dba);

=head1 DESCRIPTION

Module for fetching Regulatory Elements and rendering as hashes

=cut

package Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher;

use base qw/Bio::EnsEMBL::Production::Search::BaseFetcher/;

use strict;
use warnings;

use Log::Log4perl qw/get_logger/;
use Carp qw/croak/;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use List::Util qw(first);

my $logger = get_logger();

sub new {
  my ($class, @args) = @_;
  my $self = bless({}, ref($class) || $class);
  return $self;
}

sub fetch_regulatory_elements {
  my ($self, $name, $offset, $length) = @_;
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($name, 'funcgen');
  my $core_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($name, 'core');
  croak "Could not find database adaptor for $name" unless defined $dba;
  return $self->fetch_regulatory_elements_for_dba($dba, $core_dba, $offset, $length);
}

sub fetch_regulatory_elements_for_dba {
  my ($self, $dba, $core_dba, $offset, $length) = @_;
  my $regulatory_elements = [];
  my $h = $dba->dbc()->sql_helper();
  my $core = $core_dba->dbc()->dbname;
  my $motifs = $self->fetch_motifs($h,$offset, $length, $core);
  my $regulatory_features = $self->fetch_regulatory_features($h, $offset, $length, $core);
  my $mirna = $self->fetch_mirna($h, $offset, $length, $core);
  my $external_features = $self->fetch_external_features($h, $offset, $length, $core);
  my $peaks = $self->fetch_peaks($h, $offset, $length, $core);
  my $transcription_factors = $self->fetch_transcription_factors($h, $offset, $length);
  #return [ @$regulatory_elements, values %$mirna, values %$features ];
  return { motifs => $motifs, regulatory_features => $regulatory_features, mirna => [ values %$mirna], external_features => [values %$external_features], peaks => [values %$peaks], transcription_factors => [values %$transcription_factors] };
  #return $regulatory_elements;
} ## end sub fetch_regulatory_elements_for_dba


sub fetch_motifs {
  my ($self,$h, $offset, $length, $core) = @_;
  my ($min, $max) =
      $self->calculate_min_max($h, $offset, $length, 'motif_feature',
          'motif_feature_id');
  $logger->info("Fetching motifs");
  # Getting motifs
  my $motifs = [];
  $h->execute_no_return(
    -SQL          => qq/
       SELECT
    mf.score,
    mf.stable_id as id,
    sr.name as seq_region_name,
    mf.seq_region_start,
    mf.seq_region_end,
    mf.seq_region_strand,
    bm.stable_id,
    'Binding Motifs' as type
    FROM motif_feature mf
    JOIN $core.seq_region sr USING (seq_region_id)
    JOIN binding_matrix bm USING (binding_matrix_id)
    WHERE motif_feature_id between ? and ?/,
    -PARAMS   => [ $min, $max ],
    -USE_HASHREFS => 1,
    -CALLBACK     => sub {
      my $motif = shift @_;
      push @{$motifs}, $motif;
      return;
    });
  return $motifs;
}

sub fetch_regulatory_features {
  my ($self,$h, $offset, $length, $core) = @_;
  my ($min, $max) =
      $self->calculate_min_max($h, $offset, $length, 'regulatory_feature',
          'regulatory_feature_id');
  # Getting regulatory features
  $logger->info("Fetching Regulatory features");
  my $regulatory_features = [];
  $h->execute_no_return(
      -SQL          => qq/
      SELECT
          rf.stable_id as id,
          sr.name as seq_region_name,
          (rf.seq_region_start - rf.bound_start_length) as start,
          (rf.seq_region_end + rf.bound_end_length) as end,
          ft.name as feature_name,
          ft.description as description,
          ft.so_accession as so_accession,
          ft.so_term as so_name,
          e.name as epigenome_name,
          e.description as epigenome_description,
          'Regulatory Features' as type
      FROM regulatory_feature rf
      JOIN $core.seq_region sr USING (seq_region_id)
      JOIN feature_type ft USING (feature_type_id)
      JOIN regulatory_activity ra USING (regulatory_feature_id)
      JOIN epigenome e USING (epigenome_id)
      WHERE regulatory_feature_id between ? and ?/,
      -PARAMS   => [ $min, $max ],
      -USE_HASHREFS => 1,
      -CALLBACK     => sub {
        my $feature = shift @_;
        push @$regulatory_features,$feature;
        return;
      });
  return $regulatory_features;
}

sub fetch_mirna {
  my ($self,$h, $offset, $length, $core) = @_;
  my ($min, $max) =
      $self->calculate_min_max($h, $offset, $length, 'mirna_target_feature',
          'mirna_target_feature_id');
  my $mirna = {};
  $logger->info("Fetching miRNA");
  $h->execute_no_return(
      -SQL          => qq/
      SELECT
        mrf.display_label as name,
        mrf.accession as accession,
        mrf.method as method,
        mrf.evidence as evidence,
        mrf.supporting_information as supporting_information,
        mrf.gene_stable_id,
        sr.name as seq_region_name,
        mrf.seq_region_start as start,
        mrf.seq_region_end as end,
        mrf.seq_region_strand as strand,
        mrf.display_label as display_label,
        ft.name as feature_name,
        ft.description as description,
        ft.class as class,
        fs.name as set_name,
        'TarBase miRNA' as type
      FROM mirna_target_feature mrf
      JOIN feature_type ft USING (feature_type_id)
      JOIN feature_set fs
      JOIN $core.seq_region sr USING (seq_region_id)
      WHERE mrf.analysis_id = fs.analysis_id
      AND  mirna_target_feature_id between ? and ?/,
      -PARAMS   => [ $min, $max ],
      -USE_HASHREFS => 1,
      -CALLBACK     => sub {
        my $f = shift @_;
        my $m = $mirna->{ $f->{accession} };
        my $location = {
            start                  => $f->{start},
            end                    => $f->{end},
            strand                 => $f->{strand},
            seq_region_name        => $f->{seq_region_name},
            supporting_information => $f->{supporting_information},
            gene_stable_id         => $f->{gene_stable_id}
        };
        if (!defined $mirna->{ $f->{accession} }) {
          $m = $f;
          $f->{id} = $m->{name};
          $mirna->{ $f->{accession} } = $m;
          delete $m->{seq_region_name};
          delete $m->{start};
          delete $m->{end};
          delete $m->{strand};
          delete $m->{supporting_information};
          delete $m->{gene_stable_id};
        }
        push @{$m->{locations}}, $location;
        return;
      });
  return $mirna;
}

sub fetch_external_features {
  my ($self,$h, $offset, $length, $core) = @_;
  my ($min, $max) =
      $self->calculate_min_max($h, $offset, $length, 'external_feature',
          'external_feature_id');
  my $features = {};
  $logger->info("Fetching External features");
  $h->execute_no_return(
      -SQL          => qq/
      SELECT
        sr.name as seq_region_name,
        ef.seq_region_start as start,
        ef.seq_region_end as end,
        ef.seq_region_strand as strand,
        ef.display_label as name,
        ft.name as feature_type,
        ft.description as description,
        ft.class as class,
        fs.name as set_name,
        'Other Regulatory Regions'  as type
      FROM external_feature ef
      JOIN feature_type ft USING (feature_type_id)
      JOIN feature_set fs USING (feature_set_id)
      JOIN $core.seq_region sr USING (seq_region_id)
      WHERE external_feature_id between ? and ?/,
      -PARAMS   => [ $min, $max ],
      -USE_HASHREFS => 1,
      -CALLBACK     => sub {
        my $f = shift @_;
        my $m = $features->{ $f->{name} };
        my $location = {
            start           => $f->{start},
            end             => $f->{end},
            strand          => $f->{strand},
            seq_region_name => $f->{seq_region_name}
        };
        if (!defined $features->{ $f->{name} }) {
          $m = $f;
          $f->{id} = $m->{name};
          $features->{ $f->{name} } = $m;
          delete $m->{seq_region_name};
          delete $m->{start};
          delete $m->{end};
          delete $m->{strand};
        }
        push @{$m->{locations}}, $location;
        return;
      });
return $features;
}

sub fetch_peaks {
  my ($self,$h, $offset, $length, $core) = @_;
  my ($min, $max) =
      $self->calculate_min_max($h, $offset, $length, 'peak',
          'peak_id');
  my $peaks = {};
  $logger->info("Fetching Peaks");
  $h->execute_no_return(
      -SQL          => qq/
      SELECT
          sr.name as seq_region_name,
          p.seq_region_start as start,
          p.seq_region_end as end,
          ft.name as feature_name,
          ft.description as description,
          ft.so_accession as so_accession,
          ft.so_term as so_name,
          ft.class as class,
          e.name as epigenome_name,
          e.description as epigenome_description,
          'Regulatory Evidence' as type
      FROM peak p
      JOIN $core.seq_region sr USING (seq_region_id)
      JOIN peak_calling USING (peak_calling_id)
      JOIN feature_type ft USING (feature_type_id)
      JOIN epigenome e USING (epigenome_id)
      WHERE peak_id between ? and ?/,
      -PARAMS   => [ $min, $max ],
      -USE_HASHREFS => 1,
      -CALLBACK     => sub {
        my $peak = shift @_;
        my $m = $peaks->{ $peak->{feature_name} };
        my $location = {
            start           => $peak->{start},
            end             => $peak->{end},
            seq_region_name => $peak->{seq_region_name}
        };
        if (!defined $peaks->{ $peak->{feature_name} }) {
          $peak->{id} = $peak->{feature_name};
          $peaks->{ $peak->{feature_name} } = $peak;
          delete $peak->{seq_region_name};
          delete $peak->{start};
          delete $peak->{end};
        }
        push @{$m->{locations}}, $location;
        return;
      });
  return $peaks;
}

sub fetch_transcription_factors {
  my ($self,$h, $offset, $length) = @_;
  my ($min, $max) =
      $self->calculate_min_max($h, $offset, $length, 'transcription_factor',
          'transcription_factor_id');
  my $transcription_factors = {};
  $logger->info("Fetching Transcription factors");
  $h->execute_no_return(
      -SQL          => qq/
      SELECT
          tf.name as name,
          tf.gene_stable_id as gene_stable_id,
          ft.name as feature_name,
          ft.description as description,
          bm.stable_id as stable_id,
          'Transcription Factor' as type
      FROM transcription_factor tf
      JOIN feature_type ft USING (feature_type_id)
      JOIN transcription_factor_complex_composition tfcc USING (transcription_factor_id)
      JOIN transcription_factor_complex tfc USING (transcription_factor_complex_id)
      JOIN binding_matrix_transcription_factor_complex bmtf USING (transcription_factor_complex_id)
      JOIN binding_matrix bm USING (binding_matrix_id)
      WHERE transcription_factor_id between ? and ?/,
      -PARAMS   => [ $min, $max ],
      -USE_HASHREFS => 1,
      -CALLBACK     => sub {
        my $tf = shift @_;
        my $m = $transcription_factors->{ $tf->{name} };
        my $binding_matrix = $tf->{stable_id};
        if (!defined $transcription_factors->{ $tf->{name} }) {
          $tf->{id} = $tf->{name};
          $transcription_factors->{ $tf->{name} } = $tf;
          delete $tf->{stable_id};
        }
        if (!first { $binding_matrix eq $_ } @{$m->{binding_matrix}}) {
          push @{$m->{binding_matrix}}, $binding_matrix;
        }
        return;
      });
  return $transcription_factors;
}
1;
