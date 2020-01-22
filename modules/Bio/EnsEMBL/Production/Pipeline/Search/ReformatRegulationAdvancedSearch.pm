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

package Bio::EnsEMBL::Production::Pipeline::Search::ReformatRegulationAdvancedSearch;
use strict;
use warnings FATAL => 'all';

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use Bio::EnsEMBL::Production::Search::RegulationAdvancedSearchFormatter;

use Log::Log4perl qw/:easy/;

sub run {
  my ($self) = @_;
  if ($self->debug()) {
    Log::Log4perl->easy_init($DEBUG);
  }
  else {
    Log::Log4perl->easy_init($INFO);
  }
  $self->{logger} = get_logger();

  my $regulation_files = $self->param('dump_file');
  return unless defined $regulation_files;

  my $species = $self->param_required('species');
  my $sub_dir = $self->create_dir('adv_search');
  my $genome_file = $self->param_required('genome_file');
  my $reformatter =
      Bio::EnsEMBL::Production::Search::RegulationAdvancedSearchFormatter->new(
          -taxonomy_dba => $self->taxonomy_dba(),
          -metadata_dba => $self->metadata_dba(),
          -ontology_dba => $self->ontology_dba()
      );
  foreach my $reg (keys %$regulation_files) {
    my $file = $regulation_files->{$reg};
    my $regulation_file_out = $sub_dir . '/' . $species . '_' . $reg . '.json';
    $self->{logger}->info("Reformatting $file into $regulation_file_out");
    $reformatter->remodel_regulation(
                $file, $genome_file, $regulation_file_out );
  }
  return;
} ## end sub run

1;