
=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Search::DumpProbesMerge;

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
	my $sub_dir = $self->get_data_path('json');
	my $type    = $self->param_required('type');
	{
		my $file_names = $self->param_required('probes_dump_file');
		if ( scalar(@$file_names) > 0 ) {
			my $outfile = $sub_dir . '/' . $species . '_probes.json';
			$logger->info("Merging probes files for $species into $outfile");
			$self->merge_files( $outfile, $file_names );
			# write output
			$self->dataflow_output_id( {  species   => $species,
										  type      => $type,
										  dump_file => $outfile,
										  genome_file =>
											$self->param_required('genome_file')
									   },
									   2 );
		}
	}
	{
		my $file_names = $self->param_required('probesets_dump_file');
		if ( scalar(@$file_names) > 0 )
		{
			my $outfile = $sub_dir . '/' . $species . '_probesets.json';
			$logger->info("Merging probesets files for $species into $outfile");
			$self->merge_files( $outfile, $file_names );
			# write output
			$self->dataflow_output_id( {  species   => $species,
										  type      => $type,
										  dump_file => $outfile,
										  genome_file =>
											$self->param_required('genome_file')
									   },
									   3 );
		}
	}
	return;
} ## end sub run

1;
