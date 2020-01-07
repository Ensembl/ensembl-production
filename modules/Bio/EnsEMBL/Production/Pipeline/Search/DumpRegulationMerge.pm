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

package Bio::EnsEMBL::Production::Pipeline::Search::DumpRegulationMerge;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Search::DumpMerge/;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use JSON;

use Log::Log4perl qw/:easy/;

sub run {
	my ($self) = @_;
	if ( $self->debug() ) {
		Log::Log4perl->easy_init($DEBUG);
	}
	else {
		Log::Log4perl->easy_init($INFO);
	}
	my $logger  = get_logger();
	my $species = $self->param_required('species');
	my $sub_dir = $self->get_dir('json');
	my $type    = $self->param_required('type');
	my $outfile_motifs = $sub_dir . '/' . $species . '_motifs.json';
	my $outfile_regulatory_features = $sub_dir . '/' . $species . '_regulatory_features.json';
	my $outfile_mirna = $sub_dir . '/' . $species . '_mirna.json';
	my $outfile_external_features = $sub_dir . '/' . $species . '_external_features.json';
	my $outfile_peaks = $sub_dir . '/' . $species . '_peaks.json';
	my $outfile_transcription_factors = $sub_dir . '/' . $species . '_transcription_factors.json';
	my $regulation_files;
	my $nbr_items;
	{
		my $file_names = $self->param('motifs_dump_file');
		if ( defined $file_names && scalar(@$file_names) > 0) {
			$logger->info("Merging motifs files for $species into $outfile_motifs");
			$nbr_items = $self->merge_files( $outfile_motifs, $file_names );
			$regulation_files->{motifs} = $outfile_motifs if $nbr_items > 0;
		}
	}
	{
		my $file_names = $self->param('regulatory_features_dump_file');
		if ( defined $file_names && scalar(@$file_names) > 0) {
			$logger->info("Merging Regulatory features files for $species into $outfile_regulatory_features");
			$nbr_items = $self->merge_files( $outfile_regulatory_features, $file_names );
			$regulation_files->{regulatory_features} = $outfile_regulatory_features if $nbr_items > 0;
		}
	}
	{
		my $file_names = $self->param('mirna_dump_file');
		if ( defined $file_names && scalar(@$file_names) > 0) {
			$logger->info("Merging miRNA files for $species into $outfile_mirna");
			$nbr_items = $self->merge_files( $outfile_mirna, $file_names );
			$regulation_files->{mirna} = $outfile_mirna if $nbr_items > 0;
		}
	}
	{
		my $file_names = $self->param('external_features_dump_file');
		if ( defined $file_names && scalar(@$file_names) > 0) {
			$logger->info("Merging external features files for $species into $outfile_external_features");
			$nbr_items = $self->merge_files( $outfile_external_features, $file_names );
			$regulation_files->{external_features} = $outfile_external_features if $nbr_items > 0;
		}
	}
	{
		my $file_names = $self->param('peaks_dump_file');
		if ( defined $file_names && scalar(@$file_names) > 0) {
			$logger->info("Merging Peaks files for $species into $outfile_peaks");
			$nbr_items = $self->merge_files( $outfile_peaks, $file_names );
			$regulation_files->{peaks} = $outfile_peaks if $nbr_items > 0;
		}
	}
	{
		my $file_names = $self->param('transcription_factors_dump_file');
		if ( defined $file_names && scalar(@$file_names) > 0) {
			$logger->info("Merging transcription factors files for $species into $outfile_transcription_factors");
			$nbr_items = $self->merge_files( $outfile_transcription_factors, $file_names );
			$regulation_files->{transcription_factors} = $outfile_transcription_factors if $nbr_items > 0;
		}
	}
	# write output
	$self->dataflow_output_id( {  species   => $species,
									type      => $type,
									dump_file => $regulation_files,
									genome_file =>
									$self->param_required('genome_file')
									},
									2 );
	return;
} ## end sub run

1;
