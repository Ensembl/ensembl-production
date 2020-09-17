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

package Bio::EnsEMBL::Production::Pipeline::Search::DumpGenesJson;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Search::BaseDumpJson/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Registry;

use JSON;
use File::Path qw(make_path);
use Bio::EnsEMBL::Production::Search::GenomeFetcher;
use Bio::EnsEMBL::Production::Search::GeneFetcher;
use Bio::EnsEMBL::Production::Search::SequenceFetcher;
use Bio::EnsEMBL::Production::Search::MarkerFetcher;
use Bio::EnsEMBL::Production::Search::LRGFetcher;
use Bio::EnsEMBL::Production::Search::IdFetcher;
use Log::Log4perl qw/:easy/;

sub dump {
  my ($self, $species, $type) = @_;
  $self->{logger} = get_logger();
  if ($species !~ /Ancestral sequences/) {

    my $compara = $self->param('compara');
    if (!defined $compara) {
      $compara = $self->division();
      if (!defined $compara || $compara eq '' || lc($compara) eq 'vertebrates') {
        $compara = 'multi';
      }
    }
    if (defined $compara) {
      $self->{logger}->info("Using compara $compara");
      $self->{logger}->info("Also using pan taxonomic compara") if $self->param('use_pan_compara');
    }

    $type ||= 'core';
    my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, $type);
    my $output = {
        species     => $species,
        type        => $type,
        genome_file => $self->param('genome_file')
    };
    $self->hive_dbc()->disconnect_if_idle() if defined $self->hive_dbc();
    $self->{logger}->info("Dumping data for $species $type");
    $self->{logger}->info("Dumping genes");
    $output->{genes_file} = $self->dump_genes($dba,  $compara, $type, $self->param('use_pan_compara'));

    $self->{logger}->info("Dumping sequences");
    $output->{sequences_file} = $self->dump_sequences($dba, $type);
    $self->{logger}->info("Dumping LRGs");
    $output->{lrgs_file} = $self->dump_lrgs($dba, $type);
    $self->{logger}->info("Dumping markers");
    $output->{markers_file} = $self->dump_markers($dba, $type);
    $self->{logger}->info("Dumping IDs");
    $output->{ids_file} = $self->dump_ids($dba, $type);

    $self->{logger}->info("Completed dumping $species $type");
    $dba->dbc()->disconnect_if_idle(1);
    $self->dataflow_output_id($output, 1);
  } ## end if ( $species !~ /Ancestral sequences/)
  return;
} ## end sub dump

sub dump_genes {
  my ($self, $dba, $compara, $type, $use_pan_compara) = @_;
  $self->{logger} = get_logger();
  my $funcgen_dba;
  my $compara_dba;
  my $pan_compara_dba;
  $self->warning($dba->species()) ;

  if ($type eq 'core') {
    $funcgen_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($dba->species(), 'funcgen');
    my $compara_dba = eval {
      Bio::EnsEMBL::Registry->get_DBAdaptor($compara, 'compara') if defined $compara;
    };
    $pan_compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor('pan_homology', 'compara') if $use_pan_compara;
  }
  my $genes = Bio::EnsEMBL::Production::Search::GeneFetcher->new()->fetch_genes_for_dba($dba, $compara_dba, $funcgen_dba, $pan_compara_dba);
  if (defined $genes && scalar(@$genes) > 0) {
    $self->{logger}->info("Writing " . scalar(@$genes) . " genes to JSON");
    my $f = $self->write_json($dba->species, 'genes', $genes, $type);
    $self->{logger}->info("Wrote " . scalar(@$genes) . " genes to $f");
    return $f;
  }
  else {
    return undef;
  }
}

sub dump_sequences {
  my ($self, $dba, $type) = @_;
  $self->{logger} = get_logger();
  my $sequences = Bio::EnsEMBL::Production::Search::SequenceFetcher->new()->fetch_sequences_for_dba($dba);
  if (scalar(@$sequences) > 0) {
    $self->{logger}->info("Writing " . scalar(@$sequences) . " sequences to JSON");
    my $f = $self->write_json($dba->species, 'sequences', $sequences, $type);
    $self->{logger}->info("Wrote " . scalar(@$sequences) . " sequences to $f");
    return $f;
  }
  else {
    return undef;
  }
}

sub dump_markers {
  my ($self, $dba, $type) = @_;
  $self->{logger} = get_logger();
  my $markers = Bio::EnsEMBL::Production::Search::MarkerFetcher->new()->fetch_markers_for_dba($dba);
  if (scalar(@$markers) > 0) {
    $self->{logger}->info("Writing " . scalar(@$markers) . " markers to JSON");
    my $f = $self->write_json($dba->species, 'markers', $markers, $type);
    $self->{logger}->info("Wrote " . scalar(@$markers) . " markers to $f");
    return $f;
  }
  else {
    return undef;
  }
}

sub dump_lrgs {
  my ($self, $dba, $type) = @_;
  $self->{logger} = get_logger();
  my $lrgs = Bio::EnsEMBL::Production::Search::LRGFetcher->new()->fetch_lrgs_for_dba($dba);
  if (scalar(@$lrgs) > 0) {
    $self->{logger}->info("Writing " . scalar(@$lrgs) . " LRGs to JSON");
    my $f = $self->write_json($dba->species, 'lrgs', $lrgs, $type);
    $self->{logger}->info("Wrote " . scalar(@$lrgs) . " LRGs to $f");
    return $f;
  }
  else {
    return undef;
  }
}

sub dump_ids {
  my ($self, $dba, $type) = @_;
  $self->{logger} = get_logger();
  my $ids = Bio::EnsEMBL::Production::Search::IdFetcher->new()->fetch_ids_for_dba($dba);
  if (scalar(@$ids) > 0) {
    $self->{logger}->info("Writing " . scalar(@$ids) . " IDs to JSON");
    my $f = $self->write_json($dba->species, 'ids', $ids, $type);
    $self->{logger}->info("Wrote " . scalar(@$ids) . " IDs to $f");
    return $f;
  }
  else {
    return undef;
  }
}


1;
