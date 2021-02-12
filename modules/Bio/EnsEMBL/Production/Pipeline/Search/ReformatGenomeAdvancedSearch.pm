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

package Bio::EnsEMBL::Production::Pipeline::Search::ReformatGenomeAdvancedSearch;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use Bio::EnsEMBL::Production::Search::AdvancedSearchFormatter;

use Log::Log4perl qw/:easy/;

sub run {
	my ($self) = @_;
	if ( $self->debug() ) {
		Log::Log4perl->easy_init($DEBUG);
	}
	else {
		Log::Log4perl->easy_init($INFO);
	}
	$self->{logger} = get_logger();

	my $genes_file      = $self->param('genes_file');
	return unless defined $genes_file;

	my $species         = $self->param_required('species');
	my $sub_dir         = $self->create_dir('adv_search');
	my $genes_file_out  = $sub_dir . '/' . $species . '_genes.json';
	my $genome_file_out = $sub_dir . '/' . $species . '_genome.json';
	my $genome_file     = $self->param_required('genome_file');
	my $reformatter =
	  Bio::EnsEMBL::Production::Search::AdvancedSearchFormatter->new(
										 -taxonomy_dba => $self->taxonomy_dba(),
										 -metadata_dba => $self->metadata_dba(),
										 -ontology_dba => $self->ontology_dba()
	  );
	$reformatter->remodel_genome( $genes_file,     $genome_file,
								  $genes_file_out, $genome_file_out
	);
	return;
} ## end sub run

1;
