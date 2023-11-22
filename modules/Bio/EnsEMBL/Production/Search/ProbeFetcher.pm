=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

  Bio::EnsEMBL::Production::Search::GenomeFetcher 

=head1 SYNOPSIS

my $fetcher = Bio::EnsEMBL::Production::Search::GenomeFetcher->new();
my $genome = $fetcher->fetch_genome("homo_sapiens");

=head1 DESCRIPTION

Module for fetching probes and rendering as hashes

=cut

package Bio::EnsEMBL::Production::Search::ProbeFetcher;

use base qw/Bio::EnsEMBL::Production::Search::BaseFetcher/;

use strict;
use warnings;

use Log::Log4perl qw/get_logger/;
use Carp qw/croak/;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use List::Util qw(first);

my $logger = get_logger();

sub new {
  my ($class, @args) = @_;
  my $self = bless({}, ref($class) || $class);
  return $self;
}

sub fetch_probes {
  my ($self, $name, $offset, $length) = @_;
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($name, 'funcgen');
  croak "Could not find database adaptor for $name" unless defined $dba;
  my $core_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($name, 'core');
  return $self->fetch_probes_for_dba($dba, $core_dba, $offset, $length);
}

sub fetch_probes_for_dba {
  my ($self, $dba, $core_dba, $offset, $length) = @_;

  my $core = $core_dba->dbc()->dbname();

  my $h = $dba->dbc()->sql_helper();

  my ($min, $max) =
      $self->calculate_min_max($h, $offset, $length, 'probe',
          'probe_id');

  $logger->info("Dumping probe.probe_id from $min-$max");

  my $all_probes = {};

  my $species = $dba->species();
  $logger->info("Fetching transcripts");
  my $transcripts = {};
  $core_dba->dbc()->sql_helper()->execute_no_return(
      -SQL      => q/
        SELECT t.stable_id, g.stable_id, x.display_label
	    FROM transcript t
	    JOIN gene g using (gene_id)
	    LEFT JOIN xref x ON (g.display_xref_id=x.xref_id)/,
      -CALLBACK => sub {
        my $row = shift @_;
        my $t = { id => $row->[0], gene_id => $row->[1] };
        $t->{gene_name} = $row->[2] if defined $row->[2];
        $transcripts->{ $row->[0] } = $t;
        return;
      });
  $logger->info("Fetched details for " .
      scalar(keys %$transcripts) . " transcripts");

  $logger->info("Fetching probe transcripts");
  my $probe_transcripts = {};
  $h->execute_no_return(
      -SQL      => q/
          SELECT probe_id, stable_id, description
          FROM probe_transcript
          WHERE probe_id between ? and ?/,
      -PARAMS   => [ $min, $max ],
      -CALLBACK => sub {
        my $row = shift @_;
        my $t = $transcripts->{ $row->[1] };
        push @{$probe_transcripts->{ $row->[0] }}, { %{$t}, description => $row->[2] } if defined $t;
        return;
      });
  $logger->info("Fetched details for " . scalar(keys %$probe_transcripts) . " probe_transcripts");
  $logger->info("Fetching probeset transcripts");
  my $probesets_transcripts = {};
  $h->execute_no_return(
      -SQL      => q/
          SELECT ps.probe_set_id, ps.stable_id, ps.description
          FROM probe_set_transcript ps
          join probe p using (probe_set_id)
          WHERE p.probe_id between ? AND ?/,
      -PARAMS   => [ $min, $max ],
      -CALLBACK => sub {
        my $row = shift @_;
        my $t = $transcripts->{ $row->[1] };
        push @{$probesets_transcripts->{ $row->[0] }}, { %{$t}, description => $row->[2] } if defined $t;
        return;
      });
  $logger->info("Fetched details for " . scalar(keys %$probesets_transcripts) . " probeset_transcripts");
  # load probes
  $logger->info("Fetching probes");
  my $probes = {};
  my $probes_by_set = {};
  $h->execute_no_return(
      -SQL          => qq/
      SELECT  p.probe_id as id,
          p.name as name,
          p.probe_set_id as probe_set_id,
          p.length as length,
          p.class as class,
          p.description as description,
          array_chip.name as array_chip,
          array_chip.design_id as design_id,
          array.name as array,
          array.vendor as array_vendor,
          array.format as array_format,
          array.class as array_class,
          array.type as array_type,
          sr.name as seq_region_name,
          pf.seq_region_start as start,
          pf.seq_region_end as end,
          pf.seq_region_strand as strand,
          ps.sequence_upper as sequence
        FROM
          probe p
          JOIN probe_feature pf USING (probe_id)
          JOIN $core.seq_region sr USING (seq_region_id)
          JOIN array_chip ON (p.array_chip_id=array_chip.array_chip_id)
          JOIN array USING (array_id)
          JOIN probe_seq ps USING (probe_seq_id)
        WHERE
            p.probe_id BETWEEN ? AND ?/,
          -PARAMS       => [ $min, $max ],
      -USE_HASHREFS => 1,
      -CALLBACK     => sub {
        my $row = shift @_;
        my $id = $species . '_probe_' . $row->{id};
        my $p = $probes->{$id};
        if (!defined $p) {
          $p = { %$row };
          delete $p->{seq_region_name};
          delete $p->{start};
          delete $p->{end};
          delete $p->{strand};
          delete $p->{array_chip};
          delete $p->{design_id};
          delete $p->{array};
          delete $p->{array_vendor};
          delete $p->{array_format};
          delete $p->{array_class};
          delete $p->{array_type};
          delete $p->{probe_set_id};
          delete $p->{class} unless defined $p->{class};
          delete $p->{description} unless defined $p->{description};
          my $transcripts = $probe_transcripts->{ $row->{id} };
          $p->{transcripts} = $transcripts if defined $transcripts;
          if (defined $row->{probe_set_id}){
            push @{$probes_by_set->{ $row->{probe_set_id} }}, $p;
          }
          else{
            $probes->{$id} = $p;
          }
        }
        if (!first { $row->{seq_region_name} == $_->{seq_region_name} } @{$p->{locations}} and !first { $row->{start} == $_->{start} } @{$p->{locations}} and !first { $row->{end} == $_->{end} } @{$p->{locations}} and !first { $row->{strand} == $_->{strand} } @{$p->{locations}}){
          push @{$p->{locations}}, {
              seq_region_name => $row->{seq_region_name},
              start           => $row->{start},
              end             => $row->{end},
              strand          => $row->{strand} };
        }
        if (!first { $row->{array_chip} == $_->{array_chip} } @{$p->{arrays}}){
          push @{$p->{arrays}},{
                array_chip => $row->{array_chip},
                design_id  => $row->{design_id},
                array      => $row->{array},
                array_vendor => $row->{array_vendor},
                array_format => $row->{array_format},
                array_class  => $row->{array_class},
                array_type   => $row->{array_type}};
        }
        return;
      });
  # probe sets
  $logger->info(
      "Fetched details for " . scalar(keys %$probes) . " probes");
  my $probe_sets = {};
  $h->execute_no_return(
      -SQL          => q/
      SELECT
        distinct ps.probe_set_id as id,
        ps.name as name,
        ps.family as family,
        ps.size as size,
        array_chip.name as array_chip,
        array.name as array,
        array.vendor as array_vendor
      FROM
        probe_set ps
        join probe p using (probe_set_id)
        join array_chip on (ps.array_chip_id=array_chip.array_chip_id)
        join array using (array_id)
        WHERE p.probe_id between ? AND ?/,
      -PARAMS       => [ $min, $max ],
      -USE_HASHREFS => 1,
      -CALLBACK     => sub {
        my $row = shift @_;
        my $id = $species . '_probeset_' . $row->{id};
        my $ps = $probe_sets->{$id};
        if (!defined $ps) {
          $ps = { %$row };
          $ps->{probes} = $probes_by_set->{ $row->{id} };
          $ps->{id} = $id;
          my $transcripts = $probesets_transcripts->{ $row->{id} };
          $ps->{transcripts} = $transcripts if defined $transcripts;
          delete $ps->{family} unless defined $ps->{family};
          delete $ps->{array_chip};
          delete $ps->{array};
          delete $ps->{array_vendor};
          $probe_sets->{$id}=$ps;
        }
        if (!first { $row->{array_chip} == $_->{array_chip} } @{$ps->{arrays}}){
          push @{$ps->{arrays}},{
                array_chip => $row->{array_chip},
                array      => $row->{array},
                array_vendor => $row->{array_vendor}};
        }
        return;
      });
  $logger->info("Fetched details for " . scalar(keys %$probe_sets) . " probe sets");
  return { probes => [ values %{$probes} ], probe_sets => [ values %{$probe_sets} ] };
} ## end sub fetch_probes_for_dba

1;
