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

package Bio::EnsEMBL::Production::Pipeline::Search::ReformatRegulationSolr;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use Bio::EnsEMBL::Production::Search::RegulationSolrFormatter;

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

	my $dump_files = $self->param('dump_file');
	if ( defined $dump_files ) {
		my $genome_file = $self->param_required('genome_file');
		my $type        = $self->param_required('type');
		my $genome      = decode_json( read_file($genome_file) );
		my $species = $self->param_required('species');
		my $sub_dir = $self->create_dir('solr');
		my $reformatter =
		  Bio::EnsEMBL::Production::Search::RegulationSolrFormatter->new();
		foreach my $reg (keys %$dump_files) {
			my $file = $dump_files->{$reg};
			my $json_file_path = $sub_dir . '/' . $species . '_' . $reg . '.json';
			$self->{logger}->info("Reformatting $file into $json_file_path");
		  $reformatter->reformat_regulation(
							   $file, $json_file_path, $genome,
							   $type );
    }
  }
	return;
} ## end sub run

1;
