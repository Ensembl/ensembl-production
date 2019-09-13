=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Search::DumpProbesJson;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Search::BaseDumpJson/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher;
use Bio::EnsEMBL::Production::Search::ProbeFetcher;

use JSON;
use File::Path qw(make_path);
use Carp qw(croak);

use Log::Log4perl qw/:easy/;
use Data::Dumper;

sub dump {
  my ($self, $species) = @_;
  $self->{logger} = get_logger();
  my $offset = $self->param('offset');
  my $length = $self->param('length');

  my $sub_dir = $self->get_dir('json');
  my $probes_json_file_path;
  my $probesets_json_file_path;
  if (defined $offset) {
    $probes_json_file_path = $sub_dir . '/' . $species . '_' . $offset . '_probes.json';
    $probesets_json_file_path = $sub_dir . '/' . $species . '_' . $offset . '_probesets.json';
  }
  else {
    $probes_json_file_path = $sub_dir . '/' . $species . '_probes.json';
    $probesets_json_file_path = $sub_dir . '/' . $species . '_probesets.json';
  }

  $self->{logger}->info("Dumping probes for $species");
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'funcgen');
  my $core_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
  my $all_probes = Bio::EnsEMBL::Production::Search::ProbeFetcher->new()->fetch_probes_for_dba($dba, $core_dba, $offset, $length);
  $dba->dbc()->disconnect_if_idle();
  $core_dba->dbc()->disconnect_if_idle();
  my $probes = $all_probes->{probes};
  my $output = { species => $species };
  $self->{logger}->info("Dumped " . scalar(@{$probes}) . " probes for $species");
  if (scalar @$probes > 0) {
    $self->write_json_to_file($probes_json_file_path, $probes, 1);
    $output->{probes_dump_file} = $probes_json_file_path;
  }
  my $probe_sets = $all_probes->{probe_sets};
  $self->{logger}->info("Dumped " . scalar(@{$probe_sets}) . " probe sets for $species");
  if (scalar @$probe_sets > 0) {
    $self->write_json_to_file($probesets_json_file_path, $probe_sets, 1);
    $output->{probesets_dump_file} = $probesets_json_file_path;
  }
  if (scalar @$probe_sets > 0 || scalar @$probes > 0) {
    $self->dataflow_output_id($output, 2);
  }
  return;
} ## end sub dump

1;
