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

=cut

package Bio::EnsEMBL::Production::Pipeline::Search::DumpRegulationJson;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Search::BaseDumpJson/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher;
use JSON;
use File::Path qw(make_path);
use Carp qw(croak);

use Log::Log4perl qw/:easy/;
use Data::Dumper;

sub dump {
  my ($self, $species) = @_;
  $self->{logger} = get_logger();
  $self->{logger}->info("Dumping regulatory features for $species");
  my $offset = $self->param('offset');
  my $length = $self->param('length');
  my $sub_dir = $self->get_dir('json');
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'funcgen');
  my $core_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
  my $reg_elems = Bio::EnsEMBL::Production::Search::RegulatoryElementFetcher->new()->fetch_regulatory_elements_for_dba($dba,$core_dba,$offset,$length);
  $dba->dbc()->disconnect_if_idle();
  $core_dba->dbc()->disconnect_if_idle();
  $self->hive_dbc()->disconnect_if_idle() if defined $self->hive_dbc();
  foreach my $reg (keys %$reg_elems) {
    my $reg_elem = $reg_elems->{$reg};
    my $json_file_path;
    if (defined $offset) {
      $json_file_path = $sub_dir . '/' . $species . '_' . $offset . '_' . $reg .'.json';
    }
    else{
      $json_file_path = $sub_dir . '/' . $species . '_' . $reg . '.json';
    }
    if (defined $reg_elem && scalar(@$reg_elem) > 0) {
    $self->{logger}->info("Dumped " . scalar(@$reg_elem) . " $reg for $species");
    $self->write_json_to_file($json_file_path, $reg_elem, 1);
    $self->dataflow_output_id({
        $reg.'_dump_file'   => $json_file_path,
        species     => $species },
        2);
    }
  }
  return;
}

1;
