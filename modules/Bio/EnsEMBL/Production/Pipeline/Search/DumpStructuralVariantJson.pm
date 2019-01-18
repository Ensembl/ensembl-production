=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Search::DumpStructuralVariantJson;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Search::BaseDumpJson/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Production::Search::VariationFetcher;

use JSON;
use File::Path qw(make_path);
use Carp qw(croak);

use Log::Log4perl qw/:easy/;

sub dump {
  my ($self, $species) = @_;
  $self->{logger} = get_logger();

  $self->{logger}->debug("Fetching DBA for $species");
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'variation');

  throw "No variation database found for $species" unless defined $dba;

  my $file = $self->write_structural_variants($dba,
      $self->param("offset"),
      $self->param("length"));
  $dba->dbc()->disconnect_if_idle();
  if (defined $file) {
    $self->{logger}->info("Structural variations for $species written to $file");
    $self->dataflow_output_id({ dump_file => $file, species => $species }, 2);
  }

  return;
} ## end sub run

sub write_structural_variants {
  my ($self, $dba, $offset, $length) = @_;

  my $sub_dir = $self->get_data_path('json');
  my $json_file_path;
  if (defined $offset) {
    $json_file_path = $sub_dir . '/' . $dba->species() . '_' . $offset . '_structuralvariants.json';
  }
  else {
    $json_file_path = $sub_dir . '/' . $dba->species() . '_structuralvariants.json';
  }
  $self->{logger}->info("Writing to $json_file_path");
  open my $json_file, '>', $json_file_path or throw "Could not open $json_file_path for writing";
  $self->hive_dbc()->disconnect_if_idle();
  my $n = 0;
  print $json_file '[' unless defined $offset;
  Bio::EnsEMBL::Production::Search::VariationFetcher->new()->fetch_structural_variations_callback(
      $dba, $offset, $length,
      sub {
        my $var = shift;
        if ($n++ > 0) {
          print $json_file ',';
        }
        my $j = encode_json($var);
        print $json_file $j;
        return;
      });
  print $json_file ']' unless defined $offset;
  close $json_file || throw "Could not close $json_file_path";
  $self->{logger}->info("Wrote $n structural variants to $json_file_path");
  if ($n == 0) {
    unlink $json_file_path;
    return undef;
  }
  else {
    return $json_file_path;
  }
} ## end sub write_variants

1;
