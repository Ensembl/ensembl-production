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

=cut

package Bio::EnsEMBL::Production::Search::RegulationSolrFormatter;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Log::Log4perl qw/get_logger/;
use List::MoreUtils qw/natatime/;

use Bio::EnsEMBL::Production::Search::JSONReformatter;
use Bio::EnsEMBL::Production::Search::SolrFormatter;

use JSON;
use Carp;
use File::Slurp;

use base qw/Bio::EnsEMBL::Production::Search::SolrFormatter/;
sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  return $self;
}

sub reformat_regulation {
  my ($self, $infile, $outfile, $genome, $type) = @_;
  $type ||= 'funcgen';
  reformat_json(
      $infile, $outfile,
      sub {
        my ($f) = @_;
        my $desc;
        my $url;
        my $id;
        if ($f->{type} eq 'TarBase miRNA') {
          $id = $f->{id};
          $desc = sprintf("%s is a %s from %s which hits the genome in %d locations",
              $f->{name},
              $f->{class},
              $f->{set_name},
              scalar(@{$f->{locations}}));
          $url = sprintf("%s/Location/Genome?ftype=RegulatoryFactor;id=%s;fset=TarBase miRNA",
              $genome->{organism}->{url_name},
              $f->{id},
              $f->{set_name});
        }
        elsif ($f->{type} eq 'Regulatory Features') {
          $id = $f->{id};
          $desc = sprintf("%s regulatory feature", $f->{feature_name});
          $url = sprintf("%s/Regulation/Summary?rf=%s",
              $genome->{organism}->{url_name},
              $f->{id});
        }
        elsif ($f->{type} eq 'Binding Motifs') {
          $id = $f->{id};
          $desc = sprintf("Binding motif with stable id %s and a score of %d which hits the genome in %d:%d-%d:%d locations", $f->{stable_id},
              $f->{score},
              $f->{seq_region_name},
              $f->{seq_region_start},
              $f->{seq_region_end},
              $f->{seq_region_strand});
        }
        elsif ($f->{type} eq 'Other Regulatory Regions') {
          $id = $f->{name};
          $desc = sprintf("Other regulatory region with name %s is a %s from %s which hits the genome in %d locations", $f->{name},
              $f->{class},
              $f->{description},
              scalar(@{$f->{locations}}));
        }
        elsif ($f->{type} eq 'Regulatory Evidence') {
          $id = $f->{feature_name};
          $desc = sprintf("Regulatory Evidence with name %s is a %s from %s with epigenome %s which hits the genome in %d locations", $f->{feature_name},
              $f->{class},
              $f->{description},
              $f->{epigenome_name},
              scalar(@{$f->{locations}}));
        }
        elsif ($f->{type} eq 'Transcription Factor') {
          $id = $f->{name};
          $desc = sprintf("Transcription factor with name %s is a %s which hits Ensembl gene id %s", $f->{name},
              $f->{description},
              $f->{gene_stable_id});
          $desc = $desc . sprintf(" with %d Binding matrix", scalar(@{$f->{binding_matrix}})) if defined $f->{binding_matrix};
        }
        return {
            %{_base($genome, $type, $f->{type})},
            id          => $id,
            description => $desc,
            domain_url  => $url };
      }
  );
  return;
}
sub reformat_probes {
  my ($self, $infile, $outfile, $genome, $type) = @_;
  $type ||= 'funcgen';
  reformat_json(
      $infile, $outfile,
      sub {
        my ($probe) = @_;
        my $desc = sprintf("%s probe %s (%s array)",
            $probe->{array_vendor},
            $probe->{name}, $probe->{array_chip});
        if (!_array_nonempty($probe->{locations})) {
          $desc .= " does not hit the genome";
        }
        else {
          $desc .= " hits the genome in " .
              scalar(@{$probe->{locations}}) . " location(s).";
          if (_array_nonempty($probe->{transcripts})) {
            my $gene;
            my @transcripts = map {
              $gene = $_->{gene_name} || $_->{gene_id} unless defined $gene;
              $_->{id}
            } @{$probe->{transcripts}};
            $desc .= " It hits transcripts in the following gene: $gene (" . join(", ", @transcripts) . ")";
          }
        }
        return {
            %{_base($genome, $type, 'OligoProbe')},
            id          => $probe->{id},
            description => $desc,
            domain_url  =>
                sprintf("%s/Location/Genome?fdb=funcgen;ftype=ProbeFeature;id=%s",
                    $genome->{organism}->{url_name},
                    $probe->{id}) };
      });

  return;
} ## end sub reformat_probes

sub reformat_probesets {
  my ($self, $infile, $outfile, $genome, $type) = @_;
  $type ||= 'funcgen';
  reformat_json(
      $infile, $outfile,
      sub {
        my ($probeset) = @_;
        my $transcripts = {};
        my $locations = [];
        for my $probe (@{$probeset->{probes}}) {
          $locations = [ @$locations, @{$probe->{locations}} ];
          if (defined $probe->{transcripts}) {
            for my $transcript (@{$probe->{transcripts}}) {
              $transcripts->{ $transcript->{id} } = $transcript;
            }
          }
        }
        my $desc = sprintf("%s probeset %s (%s array)",
            $probeset->{array_vendor},
            $probeset->{name}, $probeset->{array_chip});
        if (!_array_nonempty($locations)) {
          $desc .= " has no probes that hit the genome";
        }
        else {
          $desc .= " hits the genome in " . scalar(@{$locations}) . " location(s).";
          if (scalar(keys %$transcripts) > 0) {
            my $gene;
            my @transcript_names = map {
              $gene = $_->{gene_name} || $_->{gene_id}
                  unless defined $gene;
              $_->{id}
            } values %{$transcripts};
            $desc .= " They hit transcripts in the following gene: $gene (" . join(", ", sort @transcript_names) . ")";
          }
        }
        return {
            %{_base($genome, $type, 'OligoProbe')},
            id          => $probeset->{id},
            description => $desc,
            domain_url  =>
                sprintf("%s/Location/Genome?fdb=funcgen;ftype=ProbeFeature;id=%s;ptype=pset",
                    $genome->{organism}->{url_name},
                    $probeset->{id}) };
      });

  return;
} ## end sub reformat_probesets

1;
