
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

package Bio::EnsEMBL::Production::Pipeline::Search::VariantDumpMerge;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

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
	my $logger         = get_logger();
	my $file_names     = $self->param_required('variant_dump_file');
	my $species        = $self->param_required('species');
	my $sub_dir        = $self->get_data_path('json');
	my $outfile = $sub_dir . '/' . $species . '_variants.json';
	$logger->info(
		 "Merging variant files for $species into $outfile" );
	my $cmd = "echo '['>$outfile";
	$logger->debug($cmd);
	system($cmd) == 0 || throw "Could not write to $outfile";
	my $n = 0;
	for my $file (@$file_names) {
		$logger->debug("Concatenating $file to $outfile");
		if($n++>0) {
			system("echo ','>>$outfile") == 0 || throw "Could not write to $outfile";			
		}
		system("cat $file >>$outfile") == 0 || throw "Could not concatenate $file to $outfile";
		unlink $file || throw "Could not remove $file";
	}
	system("echo ']'>>$outfile") == 0 || throw "Could not write to $outfile";
	$logger->info("Completed writing $n files to $outfile");
	return;
}

1;
