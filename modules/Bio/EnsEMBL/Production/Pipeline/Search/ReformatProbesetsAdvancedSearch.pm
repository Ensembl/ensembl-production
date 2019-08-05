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

package Bio::EnsEMBL::Production::Pipeline::Search::ReformatProbesetsAdvancedSearch;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use Bio::EnsEMBL::Production::Search::RegulationAdvancedSearchFormatter;

use JSON;
use File::Slurp qw/read_file/;
use Carp qw(croak);

use Log::Log4perl qw/:easy/;
use Data::Dumper;

sub run {
  my ($self) = @_;
  if ($self->debug()) {
    Log::Log4perl->easy_init($DEBUG);
  }
  else {
    Log::Log4perl->easy_init($INFO);
  }
  $self->{logger} = get_logger();

  my $probesets_file = $self->param('dump_file');
  return unless defined $probesets_file;

  my $species = $self->param_required('species');
  my $sub_dir = $self->get_dir('adv_search');
  my $probesets_file_out = $sub_dir . '/' . $species . '_probesets.json';
  my $genome_file = $self->param_required('genome_file');
  my $reformatter =
      Bio::EnsEMBL::Production::Search::RegulationAdvancedSearchFormatter->new(
          -taxonomy_dba => $self->taxonomy_dba(),
          -metadata_dba => $self->metadata_dba(),
          -ontology_dba => $self->ontology_dba()
      );
  $reformatter->remodel_probes($probesets_file, $genome_file,
      $probesets_file_out
  );
  return;
} ## end sub run
1;
