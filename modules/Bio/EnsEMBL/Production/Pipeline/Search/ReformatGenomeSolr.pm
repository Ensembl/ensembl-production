
=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language govern ing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::Production::Pipeline::Search::ReformatGenomeSolr;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use Bio::EnsEMBL::Production::Search::GenomeSolrFormatter;

use JSON;
use File::Slurp qw/read_file/;
use Carp qw(croak);

use Log::Log4perl qw/:easy/;
use Data::Dumper;

sub run {
	my ($self) = @_;
	if ( $self->debug() ) {
		Log::Log4perl->easy_init($DEBUG);
	}
	else {
		Log::Log4perl->easy_init($INFO);
	}
	$self->{logger} = get_logger();

	my $genome_file = $self->param_required('genome_file');
	my $type        = $self->param_required('type');
	my $genome      = decode_json( read_file($genome_file) );

	my $species = $self->param_required('species');
	my $sub_dir = $self->get_data_path('solr');

	my $reformatter =
	  Bio::EnsEMBL::Production::Search::GenomeSolrFormatter->new();

	my $genes_file = $self->param('genes_file');
	if ( defined $genes_file ) {
		my $genes_file_out = $sub_dir . '/' . $species . '_genes' .
		  ( $type ne 'core' ? "_${type}" : '' ) . '.json';
		$self->{logger}->info("Reformatting $genes_file into $genes_file_out");
		$reformatter->reformat_genes( $genes_file, $genes_file_out, $genome,
									  $type );

		my $transcripts_file_out = $sub_dir . '/' . $species . '_transcripts' .
		  ( $type ne 'core' ? "_${type}" : '' ) . '.json';
		$self->{logger}
		  ->info("Reformatting $genes_file into $transcripts_file_out");
		$reformatter->reformat_transcripts( $genes_file, $transcripts_file_out,
											$genome, $type );

		my $gene_families_file_out =
		  $sub_dir . '/' . $species . '_gene_families' .
		  ( $type ne 'core' ? "_${type}" : '' ) . '.json';
		$self->{logger}
		  ->info("Reformatting $genes_file into $gene_families_file_out");
		$reformatter->reformat_gene_families( $genes_file,
									  $gene_families_file_out, $genome, $type );
		my $gene_trees_file_out = $sub_dir . '/' . $species . '_gene_trees' .
		  ( $type ne 'core' ? "_${type}" : '' ) . '.json';
		$self->{logger}
		  ->info("Reformatting $genes_file into $gene_trees_file_out");
		$reformatter->reformat_gene_trees( $genes_file, $gene_trees_file_out,
										   $genome, $type );

		my $domains_file_out = $sub_dir . '/' . $species . '_domains' .
		  ( $type ne 'core' ? "_${type}" : '' ) . '.json';
		$self->{logger}
		  ->info("Reformatting $genes_file into $domains_file_out");
		$reformatter->reformat_domains( $genes_file, $domains_file_out, $genome,
										$type );

	} ## end if ( defined $genes_file)

	my $ids_file = $self->param('ids_file');
	if ( defined $ids_file ) {
		my $ids_file_out = $sub_dir . '/' . $species . '_ids' .
		  ( $type ne 'core' ? "_${type}" : '' ) . '.json';
		$self->{logger}->info("Reformatting $ids_file into $ids_file_out");
		$reformatter->reformat_ids( $ids_file, $ids_file_out, $genome, $type );
	}

	my $sequences_file = $self->param('sequences_file');
	if ( defined $sequences_file ) {
		my $sequences_file_out = $sub_dir . '/' . $species . '_sequences' .
		  ( $type ne 'core' ? "_${type}" : '' ) . '.json';
		$self->{logger}
		  ->info("Reformatting $sequences_file into $sequences_file_out");
		$reformatter->reformat_sequences( $sequences_file, $sequences_file_out,
										  $genome, $type );
	}

	my $lrgs_file = $self->param('lrgs_file');
	if ( defined $lrgs_file ) {
		my $lrgs_file_out = $sub_dir . '/' . $species . '_lrgs' .
		  ( $type ne 'core' ? "_${type}" : '' ) . '.json';
		$self->{logger}->info("Reformatting $lrgs_file into $lrgs_file_out");
		$reformatter->reformat_lrgs( $lrgs_file, $lrgs_file_out, $genome,
									 $type );
	}

	my $markers_file = $self->param('markers_file');
	if ( defined $markers_file ) {
		my $markers_file_out = $sub_dir . '/' . $species . '_markers' .
		  ( $type ne 'core' ? "_${type}" : '' ) . '.json';
		$self->{logger}
		  ->info("Reformatting $markers_file into $markers_file_out");
		$reformatter->reformat_markers( $markers_file, $markers_file_out,
										$genome, $type );
	}

	return;
} ## end sub run

1;
